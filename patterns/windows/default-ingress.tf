resource "kubernetes_ingress_v1" "default" {
  metadata {
    name = "default"

    annotations = {
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/load-balancer-name" = local.alb_name
      "alb.ingress.kubernetes.io/group.name"         = local.alb_name
      # Use certificate auto-discovery instead of explicit definition
      # Explicit definition will cause TF to not be able to determine input map size for terraform-helm module,
      # as the value of cert arn is dependent on cert resource creation
      # "alb.ingress.kubernetes.io/certificate-arn" = tostring(aws_acm_certificate.default.arn)
      # Default policy is insecure
      "alb.ingress.kubernetes.io/ssl-policy" = local.alb_security_policy
      # Must use tostring() as TF is converting string to number otherwise
      # Just doesn't work :( - have to use type = "string" in helm_release "set"
      # "alb.ingress.kubernetes.io/ssl-redirect" = tostring("443")
      # ssl-redirect results in default value of listen-ports reduced to just 443
      # "alb.ingress.kubernetes.io/listen-ports" = tostring("[{\"HTTP\": 80}\\, {\"HTTPS\": 443}]")
      "alb.ingress.kubernetes.io/listen-ports" = tostring("[{\"HTTPS\": 443}]")
      # Access logs
      # "alb.ingress.kubernetes.io/load-balancer-attributes" = "access_logs.s3.enabled=true,access_logs.s3.bucket=sdbx-logs,access_logs.s3.prefix=alb"

      "cert-manager.io/cluster-issuer" = "cert-manager-ca-issuer"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = local.domain_name

      http {
        path {
          backend {
            service {
              name = "default"
              port {
                number = 8080
              }
            }
          }

          path = "/"
        }
      }
    }

    tls {
      hosts       = [local.domain_name]
      secret_name = "default-tls"
    }
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}

resource "kubernetes_service_v1" "default_ingress" {
  metadata {
    name = "default-ingress"
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.default_ingress.metadata.0.labels.app
    }
    session_affinity = "ClientIP"
    port {
      port        = 8080
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment_v1" "default_ingress" {
  metadata {
    name = "default-ingress"
    labels = {
      app = "default-ingress"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "default-ingress"
      }
    }

    template {
      metadata {
        labels = {
          app = "default-ingress"
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        container {
          image = "public.ecr.aws/nginx/nginx:latest"
          name  = "nginx"

          resources {
            limits = {
              cpu    = "50m"
              memory = "100Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "30Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [
    module.eks_blueprints_addons
  ]
}
