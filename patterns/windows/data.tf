data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

# Admin role that is allowed to manage AWS resources
data "aws_iam_role" "admin" {
  name = "Admin"
}

data "aws_ami" "windows2022_core_eks_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Core-EKS_Optimized-${var.kubernetes_version}-*"]
  }
}
