# Log groups

resource "aws_kms_key" "amp" {
  description             = "Key used for AMP workspace ${local.name} and related resources"
  deletion_window_in_days = var.key_deletion_window_in_days
  policy = jsonencode({
    Id = local.name
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Resource = "*"
        Sid      = "IAMAccess"
      },
      {
        Action = [
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
        Effect = "Allow"
        Principal = {
          AWS = data.aws_iam_role.admin.arn
        }
        Resource = "*"
        Sid      = "Administration"
      },
      {
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${local.region}:${local.account_id}:log-group:${local.name}"
          }
        }
        Effect = "Allow"
        Principal = {
          Service = "logs.${local.region}.amazonaws.com"
        }
        Resource = "*"
        Sid      = "CloudWatchLogs"
      },
    ]
  })
}

resource "aws_kms_alias" "amp" {
  name          = "alias/amp/${local.name}"
  target_key_id = aws_kms_key.amp.key_id
}

resource "aws_cloudwatch_log_group" "amp" {
  name              = local.name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.amp.arn
  tags              = local.tags
}

resource "aws_prometheus_workspace" "amp" {
  alias       = local.name
  kms_key_arn = aws_kms_key.amp.arn
  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.amp.arn}:*"
  }
  tags = local.tags
}
