data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

# Admin role that is allowed to manage AWS resources
data "aws_iam_role" "admin" {
  name = var.admin_role_name
}

data "aws_ami" "windows2022_core_eks_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Core-EKS_Optimized-${var.kubernetes_version}-*"]
  }
}

data "aws_iam_policy_document" "amp" {
  statement {
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    resources = ["*"]
    sid       = "IAMAccess"
  }
  statement {
    actions = [
      "kms:Update*",
      "kms:UntagResource",
      "kms:TagResource",
      "kms:ScheduleKeyDeletion",
      "kms:Revoke*",
      "kms:ReplicateKey",
      "kms:Put*",
      "kms:List*",
      "kms:ImportKeyMaterial",
      "kms:Get*",
      "kms:Enable*",
      "kms:Disable*",
      "kms:Describe*",
      "kms:Delete*",
      "kms:Create*",
      "kms:CancelKeyDeletion"
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.admin.arn]
    }
    resources = ["*"]
    sid       = "Administration"
  }
  statement {
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }
    resources = ["*"]
    sid       = "CloudWatchLogs"
  }
}

data "external" "aws_amp_scraper" {
  count   = local.instrument_amp_scraper ? 1 : 0
  program = ["bash", "${path.module}/scripts/get-amp-scraper.sh"]

  query = {
    scraper_id = aws_prometheus_scraper.eks.id
  }
}

data "aws_route53_zone" "public" {
  name = "${var.domain_root}."
}

data "aws_lb" "ingress" {
  name = local.alb_name
  depends_on = [
    kubernetes_ingress_v1.default
  ]
}
