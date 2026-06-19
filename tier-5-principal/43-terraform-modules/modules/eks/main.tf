terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

variable "cluster_name"    { type = string }
variable "cluster_version" { type = string; default = "1.30" }
variable "vpc_id"          { type = string }
variable "subnet_ids"      { type = list(string) }
variable "tags"            { type = map(string); default = {} }

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
    capacity_type  = optional(string, "ON_DEMAND")
    labels         = optional(map(string), {})
    taints         = optional(list(object({ key = string, value = string, effect = string })), [])
  }))
  default = {}
}

variable "cluster_addons" {
  type    = map(object({ version = optional(string) }))
  default = {
    vpc-cni            = {}
    coredns            = {}
    kube-proxy         = {}
    aws-ebs-csi-driver = {}
  }
}

locals {
  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    ManagedBy = "terraform-modules/eks"
  })
}

# ── IAM Role for EKS Control Plane ───────────────────────────────────────────

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false    # no public API server
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  tags = local.tags
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption — ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

# ── OIDC Provider (required for IRSA) ────────────────────────────────────────

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = local.tags
}

# ── Managed Node Groups ───────────────────────────────────────────────────────

resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  policy_arn = each.value
  role       = aws_iam_role.node.name
}

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type

  scaling_config {
    min_size     = each.value.min_size
    max_size     = each.value.max_size
    desired_size = each.value.desired_size
  }

  update_config { max_unavailable = 1 }

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  labels = each.value.labels
  tags   = local.tags

  depends_on = [aws_iam_role_policy_attachment.node_policies]
}

# ── EKS Addons ────────────────────────────────────────────────────────────────

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name             = aws_eks_cluster.this.name
  addon_name               = each.key
  addon_version            = each.value.version
  resolve_conflicts_on_update = "OVERWRITE"
  tags                     = local.tags
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "cluster_name"              { value = aws_eks_cluster.this.name }
output "cluster_endpoint"          { value = aws_eks_cluster.this.endpoint }
output "cluster_certificate_authority" { value = aws_eks_cluster.this.certificate_authority[0].data }
output "oidc_provider_arn"         { value = aws_iam_openid_connect_provider.cluster.arn }
output "oidc_provider_url"         { value = aws_iam_openid_connect_provider.cluster.url }
output "node_role_arn"             { value = aws_iam_role.node.arn }
