# Windows - WIP

This pattern uses the [ArgoCD getting started](../gitops/getting-started-argocd/) pattern for add-on deployment.

## Deployment

1. Configure S3 backend, including DynamoDB state locks

```
terraform init
terraform apply -target="module.vpc" -auto-approve
terraform apply -target="module.vpc_endpoints" -auto-approve
terraform apply -target="module.eks" -auto-approve
terraform apply -auto-approve
```