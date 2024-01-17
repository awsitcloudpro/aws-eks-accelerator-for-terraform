data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_ami" "windows2022_core_eks_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Core-EKS_Optimized-${var.kubernetes_version}-*"]
  }
}
