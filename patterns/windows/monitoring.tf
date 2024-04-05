################################################################################
# EKS Observability
################################################################################


################################################################################
# Observability resources encryption key
################################################################################
resource "aws_kms_key" "amp" {
  description             = "Key used for AMP workspace ${local.name} and related resources"
  deletion_window_in_days = var.key_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.amp.json
  tags                    = local.tags
}

resource "aws_kms_alias" "amp" {
  name          = "alias/amp/${local.name}"
  target_key_id = aws_kms_key.amp.key_id
}

################################################################################
# AMP CloudWatch log group
################################################################################
resource "aws_cloudwatch_log_group" "amp" {
  name              = local.name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = aws_kms_key.amp.arn
  tags              = local.tags
}

################################################################################
# AMP workspace
################################################################################
resource "aws_prometheus_workspace" "amp" {
  alias = local.name

  ## As of Jan 2024, CMK-encrypted workspace is not supported for AMP agentless collector scraper
  ## Uncomment the following when this limitation is gone
  # kms_key_arn = aws_kms_key.amp.arn

  logging_configuration {
    log_group_arn = "${aws_cloudwatch_log_group.amp.arn}:*"
  }
  tags = merge(local.tags, {
    AMPAgentlessScraper = ""
  })
}

################################################################################
# AMP managed agentless collector scraper
################################################################################
resource "aws_prometheus_scraper" "eks" {
  source {
    eks {
      cluster_arn = module.eks.cluster_arn
      subnet_ids  = module.vpc.private_subnets
    }
  }

  destination {
    amp {
      workspace_arn = aws_prometheus_workspace.amp.arn
    }
  }

  scrape_configuration = <<EOT
global:
  scrape_interval: 30s
scrape_configs:
  # pod metrics
  - job_name: pod_exporter
    kubernetes_sd_configs:
      - role: pod
  # container metrics
  - job_name: cadvisor
    scheme: https
    authorization:
      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - replacement: kubernetes.default.svc:443
        target_label: __address__
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
  # apiserver metrics
  - bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    job_name: kubernetes-apiservers
    kubernetes_sd_configs:
    - role: endpoints
    relabel_configs:
    - action: keep
      regex: default;kubernetes;https
      source_labels:
      - __meta_kubernetes_namespace
      - __meta_kubernetes_service_name
      - __meta_kubernetes_endpoint_port_name
    scheme: https
  # kube proxy metrics
  - job_name: kube-proxy
    honor_labels: true
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - action: keep
      source_labels:
      - __meta_kubernetes_namespace
      - __meta_kubernetes_pod_name
      separator: '/'
      regex: 'kube-system/kube-proxy.+'
    - source_labels:
      - __address__
      action: replace
      target_label: __address__
      regex: (.+?)(\\:\\d+)?
      replacement: $1:10249
EOT
}

resource "null_resource" "amp_scraper_instrumentation" {
  count = local.instrument_amp_scraper ? 1 : 0

  provisioner "local-exec" {
    command = "${path.module}/scripts/instrument-amp-scraper.sh '${data.external.aws_amp_scraper[0].result.role_arn}' '${local.amp_scraper_username}'"
  }
}
