package controllers

import (
	"context"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	autoscalingv2 "k8s.io/api/autoscaling/v2"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	webappv1alpha1 "github.com/joevue123/devops-portfolio/api/v1alpha1"
)

const (
	finalizerName = "webapp.example.com/finalizer"
	appPort       = 8080
)

// WebAppReconciler reconciles a WebApp object
type WebAppReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=webapp.example.com,resources=webapps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=webapp.example.com,resources=webapps/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=webapp.example.com,resources=webapps/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=autoscaling,resources=horizontalpodautoscalers,verbs=get;list;watch;create;update;patch;delete

func (r *WebAppReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx)

	webapp := &webappv1alpha1.WebApp{}
	if err := r.Get(ctx, req.NamespacedName, webapp); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Handle deletion
	if !webapp.DeletionTimestamp.IsZero() {
		if controllerutil.ContainsFinalizer(webapp, finalizerName) {
			log.Info("Running cleanup for WebApp", "name", webapp.Name)
			controllerutil.RemoveFinalizer(webapp, finalizerName)
			if err := r.Update(ctx, webapp); err != nil {
				return ctrl.Result{}, err
			}
		}
		return ctrl.Result{}, nil
	}

	// Add finalizer
	if !controllerutil.ContainsFinalizer(webapp, finalizerName) {
		controllerutil.AddFinalizer(webapp, finalizerName)
		if err := r.Update(ctx, webapp); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Reconcile child resources
	if err := r.reconcileDeployment(ctx, webapp); err != nil {
		r.setCondition(ctx, webapp, "Ready", metav1.ConditionFalse, "DeploymentFailed", err.Error())
		return ctrl.Result{}, err
	}
	if err := r.reconcileService(ctx, webapp); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.reconcileIngress(ctx, webapp); err != nil {
		return ctrl.Result{}, err
	}
	if webapp.Spec.Autoscaling != nil && webapp.Spec.Autoscaling.Enabled {
		if err := r.reconcileHPA(ctx, webapp); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Update status
	deploy := &appsv1.Deployment{}
	if err := r.Get(ctx, req.NamespacedName, deploy); err == nil {
		webapp.Status.ReadyReplicas = deploy.Status.ReadyReplicas
		webapp.Status.Endpoint = fmt.Sprintf("https://%s", webapp.Spec.Hostname)
		webapp.Status.ObservedGeneration = webapp.Generation
	}
	r.setCondition(ctx, webapp, "Ready", metav1.ConditionTrue, "Reconciled", "All resources are in sync")
	if err := r.Status().Update(ctx, webapp); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *WebAppReconciler) reconcileDeployment(ctx context.Context, webapp *webappv1alpha1.WebApp) error {
	deploy := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      webapp.Name,
			Namespace: webapp.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, deploy, func() error {
		deploy.Labels = labelsFor(webapp)
		deploy.Spec = appsv1.DeploymentSpec{
			Replicas: &webapp.Spec.Replicas,
			Selector: &metav1.LabelSelector{MatchLabels: labelsFor(webapp)},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labelsFor(webapp)},
				Spec: corev1.PodSpec{
					SecurityContext: &corev1.PodSecurityContext{
						RunAsNonRoot: boolPtr(true),
						RunAsUser:    int64Ptr(1000),
					},
					Containers: []corev1.Container{{
						Name:            webapp.Name,
						Image:           webapp.Spec.Image,
						ImagePullPolicy: corev1.PullAlways,
						Ports:           []corev1.ContainerPort{{ContainerPort: appPort, Protocol: corev1.ProtocolTCP}},
						Env:             webapp.Spec.Env,
						Resources:       withDefaults(webapp.Spec.Resources),
						ReadinessProbe: &corev1.Probe{
							ProbeHandler: corev1.ProbeHandler{
								HTTPGet: &corev1.HTTPGetAction{Path: "/health", Port: intstr.FromInt(appPort)},
							},
							InitialDelaySeconds: 5,
							PeriodSeconds:       10,
						},
						LivenessProbe: &corev1.Probe{
							ProbeHandler: corev1.ProbeHandler{
								HTTPGet: &corev1.HTTPGetAction{Path: "/health", Port: intstr.FromInt(appPort)},
							},
							InitialDelaySeconds: 15,
							PeriodSeconds:       20,
							FailureThreshold:    3,
						},
						SecurityContext: &corev1.SecurityContext{
							AllowPrivilegeEscalation: boolPtr(false),
							ReadOnlyRootFilesystem:   boolPtr(true),
							Capabilities:             &corev1.Capabilities{Drop: []corev1.Capability{"ALL"}},
						},
					}},
				},
			},
		}
		return controllerutil.SetControllerReference(webapp, deploy, r.Scheme)
	})
	return err
}

func (r *WebAppReconciler) reconcileService(ctx context.Context, webapp *webappv1alpha1.WebApp) error {
	svc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{Name: webapp.Name, Namespace: webapp.Namespace},
	}
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, svc, func() error {
		svc.Labels = labelsFor(webapp)
		svc.Spec = corev1.ServiceSpec{
			Selector: labelsFor(webapp),
			Ports:    []corev1.ServicePort{{Port: 80, TargetPort: intstr.FromInt(appPort), Protocol: corev1.ProtocolTCP}},
			Type:     corev1.ServiceTypeClusterIP,
		}
		return controllerutil.SetControllerReference(webapp, svc, r.Scheme)
	})
	return err
}

func (r *WebAppReconciler) reconcileIngress(ctx context.Context, webapp *webappv1alpha1.WebApp) error {
	pathType := networkingv1.PathTypePrefix
	ing := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{Name: webapp.Name, Namespace: webapp.Namespace},
	}
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, ing, func() error {
		ing.Labels = labelsFor(webapp)
		ing.Annotations = map[string]string{
			"cert-manager.io/cluster-issuer":               "letsencrypt-prod",
			"nginx.ingress.kubernetes.io/ssl-redirect":      "true",
			"nginx.ingress.kubernetes.io/proxy-body-size":   "10m",
		}
		ing.Spec = networkingv1.IngressSpec{
			IngressClassName: strPtr("nginx"),
			TLS: []networkingv1.IngressTLS{{
				Hosts:      []string{webapp.Spec.Hostname},
				SecretName: fmt.Sprintf("%s-tls", webapp.Name),
			}},
			Rules: []networkingv1.IngressRule{{
				Host: webapp.Spec.Hostname,
				IngressRuleValue: networkingv1.IngressRuleValue{
					HTTP: &networkingv1.HTTPIngressRuleValue{
						Paths: []networkingv1.HTTPIngressPath{{
							Path:     "/",
							PathType: &pathType,
							Backend: networkingv1.IngressBackend{
								Service: &networkingv1.IngressServiceBackend{
									Name: webapp.Name,
									Port: networkingv1.ServiceBackendPort{Number: 80},
								},
							},
						}},
					},
				},
			}},
		}
		return controllerutil.SetControllerReference(webapp, ing, r.Scheme)
	})
	return err
}

func (r *WebAppReconciler) reconcileHPA(ctx context.Context, webapp *webappv1alpha1.WebApp) error {
	as := webapp.Spec.Autoscaling
	cpuTarget := as.TargetCPUPercent
	hpa := &autoscalingv2.HorizontalPodAutoscaler{
		ObjectMeta: metav1.ObjectMeta{Name: webapp.Name, Namespace: webapp.Namespace},
	}
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, hpa, func() error {
		hpa.Labels = labelsFor(webapp)
		hpa.Spec = autoscalingv2.HorizontalPodAutoscalerSpec{
			ScaleTargetRef: autoscalingv2.CrossVersionObjectReference{
				APIVersion: "apps/v1",
				Kind:       "Deployment",
				Name:       webapp.Name,
			},
			MinReplicas: &as.MinReplicas,
			MaxReplicas: as.MaxReplicas,
			Metrics: []autoscalingv2.MetricSpec{{
				Type: autoscalingv2.ResourceMetricSourceType,
				Resource: &autoscalingv2.ResourceMetricSource{
					Name: corev1.ResourceCPU,
					Target: autoscalingv2.MetricTarget{
						Type:               autoscalingv2.UtilizationMetricType,
						AverageUtilization: &cpuTarget,
					},
				},
			}},
		}
		return controllerutil.SetControllerReference(webapp, hpa, r.Scheme)
	})
	return err
}

func (r *WebAppReconciler) setCondition(ctx context.Context, webapp *webappv1alpha1.WebApp, condType string, status metav1.ConditionStatus, reason, message string) {
	existing := -1
	for i, c := range webapp.Status.Conditions {
		if c.Type == condType {
			existing = i
			break
		}
	}
	cond := metav1.Condition{
		Type:               condType,
		Status:             status,
		Reason:             reason,
		Message:            message,
		LastTransitionTime: metav1.Now(),
		ObservedGeneration: webapp.Generation,
	}
	if existing >= 0 {
		if webapp.Status.Conditions[existing].Status == status {
			cond.LastTransitionTime = webapp.Status.Conditions[existing].LastTransitionTime
		}
		webapp.Status.Conditions[existing] = cond
	} else {
		webapp.Status.Conditions = append(webapp.Status.Conditions, cond)
	}
}

func (r *WebAppReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&webappv1alpha1.WebApp{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&networkingv1.Ingress{}).
		Owns(&autoscalingv2.HorizontalPodAutoscaler{}).
		Complete(r)
}

// ── helpers ───────────────────────────────────────────────────────────────────

func labelsFor(webapp *webappv1alpha1.WebApp) map[string]string {
	return map[string]string{
		"app.kubernetes.io/name":       webapp.Name,
		"app.kubernetes.io/managed-by": "webapp-operator",
	}
}

func withDefaults(r corev1.ResourceRequirements) corev1.ResourceRequirements {
	if r.Requests == nil {
		r.Requests = corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("100m"),
			corev1.ResourceMemory: resource.MustParse("128Mi"),
		}
	}
	if r.Limits == nil {
		r.Limits = corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse("500m"),
			corev1.ResourceMemory: resource.MustParse("256Mi"),
		}
	}
	return r
}

func boolPtr(b bool) *bool         { return &b }
func int64Ptr(i int64) *int64      { return &i }
func strPtr(s string) *string      { return &s }

var _ = errors.IsNotFound // ensure import used
