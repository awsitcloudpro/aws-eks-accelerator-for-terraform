locals {
  # Name must be in DNS-compatible format
  name   = "${var.environment}-example"
  region = var.region
  # Change account_id if terraform apply is run from a different account
  account_id = data.aws_caller_identity.current.account_id

  cluster_version = var.kubernetes_version

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
  vpc_endpoints = toset([
    "aps",
    "aps-workspaces",
    "autoscaling",
    "ec2",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "elasticloadbalancing",
    "kms",
    "logs",
    "ssm",
    "ssmmessages",
    "sts",
  ])

  gitops_addons_url      = "${var.gitops_addons_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath = var.gitops_addons_basepath
  gitops_addons_path     = var.gitops_addons_path
  gitops_addons_revision = var.gitops_addons_revision

  gitops_workload_url      = "${var.gitops_workload_org}/${var.gitops_workload_repo}"
  gitops_workload_basepath = var.gitops_workload_basepath
  gitops_workload_path     = var.gitops_workload_path
  gitops_workload_revision = var.gitops_workload_revision

  addons = merge(
    { kubernetes_version = local.cluster_version },
    { aws_cluster_name = module.eks.cluster_name },
    var.addons,
  )

  addons_metadata = merge(
    module.eks_blueprints_addons.gitops_metadata,
    {
      aws_cluster_name = module.eks.cluster_name
      aws_region       = local.region
      aws_account_id   = local.account_id
      aws_vpc_id       = module.vpc.vpc_id
    },
    {
      addons_repo_url      = local.gitops_addons_url
      addons_repo_basepath = local.gitops_addons_basepath
      addons_repo_path     = local.gitops_addons_path
      addons_repo_revision = local.gitops_addons_revision
    },
    {
      workload_repo_url      = local.gitops_workload_url
      workload_repo_basepath = local.gitops_workload_basepath
      workload_repo_path     = local.gitops_workload_path
      workload_repo_revision = local.gitops_workload_revision
    },
    {
      aws_for_fluentbit_namespace = var.observability_namespace
      observability_namespace     = var.observability_namespace
    }
  )

  argocd_app_of_appsets_addons = var.enable_gitops_auto_addons ? {
    addons = file("${path.module}/argocd-bootstrap/addons.yaml")
  } : {}
  argocd_app_of_appsets_workloads = var.enable_gitops_auto_workloads ? {
    workloads = file("${path.module}/argocd-bootstrap/workloads.yaml")
  } : {}

  argocd_apps = merge(local.argocd_app_of_appsets_addons, local.argocd_app_of_appsets_workloads)

  domain_name         = "${local.name}.${var.domain_root}"
  alb_name            = "alb-${local.name}"
  alb_security_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  cert_issuer_ca      = "cert-manager-ca-issuer"
  # DNS names to be used in ACM cert and ingresses
  # TODO See if there is any way to avoid manual cert re-association with ALB when these names are changed
  subdomains = ["keycloak"]
  ingress_dns_names = toset([
    for subdomain in local.subdomains : "${subdomain}.${local.domain_name}"
    if var.enable_ingress
  ])

  instrument_amp_scraper = true
  amp_scraper_username   = "aps-collector-user"

  tags = merge({
    Blueprint   = local.name
    Environment = var.environment
    GithubRepo  = "github.com/awsitcloudpro/terraform-aws-eks-blueprints"
  }, var.tags)
}
