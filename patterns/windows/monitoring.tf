# Log groups

resource "aws_cloudwatch_log_group" "amp" {
  name              = local.name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = module.eks.kms_key_arn
  tags              = local.tags
}

resource "aws_prometheus_workspace" "amp" {
  alias       = local.name
  kms_key_arn = module.eks.kms_key_arn
  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.amp.arn}:*"
  }
  tags = local.tags
}
