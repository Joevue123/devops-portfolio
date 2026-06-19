package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestEKSModule(t *testing.T) {
	t.Parallel()

	awsRegion    := "us-east-1"
	clusterName  := fmt.Sprintf("terratest-eks-%s", random.UniqueId())
	vpcID, subnetIDs := createTestVPC(t, awsRegion, clusterName)

	defer destroyTestVPC(t, awsRegion, clusterName)

	opts := &terraform.Options{
		TerraformDir: "../modules/eks",
		Vars: map[string]interface{}{
			"cluster_name":    clusterName,
			"cluster_version": "1.30",
			"vpc_id":          vpcID,
			"subnet_ids":      subnetIDs,
			"node_groups": map[string]interface{}{
				"general": map[string]interface{}{
					"instance_types": []string{"t3.medium"},
					"min_size":       1,
					"max_size":       3,
					"desired_size":   1,
				},
			},
			"tags": map[string]string{
				"Environment": "test",
				"ManagedBy":   "terratest",
			},
		},
		RetryableTerraformErrors: map[string]string{
			".*throttling.*": "AWS API throttling — retrying",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	// ── Assertions ────────────────────────────────────────────────────────────

	clusterEndpoint := terraform.Output(t, opts, "cluster_endpoint")
	assert.NotEmpty(t, clusterEndpoint, "cluster_endpoint should not be empty")

	oidcArn := terraform.Output(t, opts, "oidc_provider_arn")
	assert.Contains(t, oidcArn, "oidc", "OIDC provider ARN should contain 'oidc'")

	// Verify cluster is Active via AWS API
	cluster := aws.GetEksCluster(t, awsRegion, clusterName)
	require.Equal(t, "ACTIVE", aws.StringValue(cluster.Status), "EKS cluster should be ACTIVE")

	// Verify secret encryption is enabled
	require.NotEmpty(t, cluster.EncryptionConfig, "Secrets encryption should be configured")
	assert.Equal(t, "secrets", cluster.EncryptionConfig[0].Resources[0])

	// Verify private API server (no public endpoint)
	assert.False(t, aws.BoolValue(cluster.ResourcesVpcConfig.EndpointPublicAccess),
		"Public API server endpoint should be disabled")

	// Verify nodes join the cluster
	kubeConfigPath := writeKubeConfig(t, awsRegion, clusterName)
	k8sOpts := k8s.NewKubectlOptions("", kubeConfigPath, "default")

	k8s.WaitUntilAllNodesReady(t, k8sOpts, 40, 30*time.Second)

	nodes := k8s.GetNodes(t, k8sOpts)
	assert.GreaterOrEqual(t, len(nodes), 1, "At least 1 node should be ready")

	// Verify NVIDIA device plugin not loaded on general nodes (GPU NodePool test is separate)
	for _, node := range nodes {
		_, hasGPU := node.Status.Capacity["nvidia.com/gpu"]
		assert.False(t, hasGPU, "General node group should not have GPU capacity")
	}

	// Verify kube-system pods are running
	pods := k8s.ListPods(t, k8sOpts, metav1.ListOptions{
		Namespace: "kube-system",
	})
	runningCount := 0
	for _, pod := range pods {
		if string(pod.Status.Phase) == "Running" {
			runningCount++
		}
	}
	assert.GreaterOrEqual(t, runningCount, 3, "At least 3 kube-system pods should be Running")
}

func writeKubeConfig(t *testing.T, region, clusterName string) string {
	t.Helper()
	// In practice: exec aws eks update-kubeconfig and return path
	return fmt.Sprintf("/tmp/kubeconfig-%s", clusterName)
}

func createTestVPC(t *testing.T, region, name string) (string, []string) {
	t.Helper()
	// Creates a minimal VPC for the test — implementation omitted for brevity
	// In real tests: use the vpc module or aws SDK directly
	return "vpc-test-id", []string{"subnet-a", "subnet-b"}
}

func destroyTestVPC(t *testing.T, region, name string) {
	t.Helper()
}
