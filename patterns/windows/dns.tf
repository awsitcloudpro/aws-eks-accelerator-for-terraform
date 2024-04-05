# Provision a Route 53 DNS record for the K8s LoadBalancer type service provisioned by this Helm chart

resource "aws_route53_record" "alb" {
  for_each        = local.ingress_dns_names
  zone_id         = data.aws_route53_zone.public.zone_id
  name            = each.key
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}
