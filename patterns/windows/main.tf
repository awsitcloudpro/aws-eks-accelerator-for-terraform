################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  source = "github.com/gitops-bridge-dev/gitops-bridge-argocd-bootstrap-terraform?ref=v2.0.0"

  cluster = {
    metadata = local.addons_metadata
    addons   = local.addons
  }
  argocd = {
    set = [{
      name  = "global.nodeSelector.kubernetes\\.io/os"
      value = "linux"
    }]
  }
  apps = local.argocd_apps

  depends_on = [
    module.eks_blueprints_addons,
  ]
}

################################################################################
# EKS Blueprints Addons
################################################################################
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Using GitOps Bridge
  create_kubernetes_resources = false

  # EKS Blueprints Addons
  enable_cert_manager                 = local.addons.enable_cert_manager
  enable_aws_efs_csi_driver           = local.addons.enable_aws_efs_csi_driver
  enable_aws_fsx_csi_driver           = local.addons.enable_aws_fsx_csi_driver
  enable_aws_cloudwatch_metrics       = local.addons.enable_aws_cloudwatch_metrics
  enable_cluster_autoscaler           = local.addons.enable_cluster_autoscaler
  enable_external_secrets             = local.addons.enable_external_secrets
  enable_aws_load_balancer_controller = local.addons.enable_aws_load_balancer_controller
  enable_fargate_fluentbit            = local.addons.enable_fargate_fluentbit
  enable_aws_for_fluentbit            = local.addons.enable_aws_for_fluentbit
  enable_aws_node_termination_handler = local.addons.enable_aws_node_termination_handler
  enable_karpenter                    = local.addons.enable_karpenter


  tags = local.tags
}

################################################################################
# EKS Cluster
################################################################################
#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  kms_key_owners                  = ["arn:aws:iam::${local.account_id}:root"]
  kms_key_administrators          = [data.aws_iam_role.admin.arn]
  kms_key_description             = "Key used for EKS cluster ${local.name} and related resources"
  kms_key_deletion_window_in_days = var.key_deletion_window_in_days

  cloudwatch_log_group_retention_in_days = var.log_retention_in_days
  cloudwatch_log_group_tags              = local.tags

  # Add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  # Cluster access entries
  # access_entries = {
  #   admin = {
  #     kubernetes_groups = ["administrators"]
  #     principal_arn     = data.aws_iam_role.admin.arn
  #   }
  # }

  eks_managed_node_group_defaults = {
    iam_role_additional_policies = {
      # Not required, but used in the example to access the nodes to inspect mounted volumes
      # And for internal PVRE reports (Running SSM for compliance scanning and patching)
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  eks_managed_node_groups = {
    linux = {
      instance_types = ["m6i.large"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  # Defaults suitable for Windows and SSM connect, will also work for Linux
  self_managed_node_group_defaults = {
    instance_type                          = "m6i.xlarge"
    update_launch_template_default_version = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
  }
  self_managed_node_groups = {
    windows = {
      platform = "windows"
      ami_id   = data.aws_ami.windows2022_core_eks_optimized.id

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      # See README for further details
      before_compute = true
      most_recent    = true # To ensure access to the latest settings provided
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        },
        enableWindowsIpam             = "true"
        enableWindowsPrefixDelegation = "true"
      })
    }
  }
  tags = local.tags

  depends_on = [
    module.vpc_endpoints,
  ]
}

################################################################################
# Supporting Resources
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for i, v in local.azs : cidrsubnet(local.vpc_cidr, 8, i)]
  private_subnets = [for i, v in local.azs : cidrsubnet(local.vpc_cidr, 4, i + 1)]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.1"

  vpc_id = module.vpc.vpc_id

  # Security group
  create_security_group      = true
  security_group_name_prefix = "${local.name}-vpce-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = merge({
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags            = local.tags
    }
    },
    { for service in local.vpc_endpoints :
      replace(service, ".", "_") =>
      {
        service             = service
        subnet_ids          = module.vpc.private_subnets
        private_dns_enabled = true
        tags                = local.tags
      }
  })

  tags = local.tags
}
