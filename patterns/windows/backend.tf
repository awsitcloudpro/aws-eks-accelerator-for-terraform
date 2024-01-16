# Terraform backend

terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "bucket-dev-automation-tf"    # Change this as needed
    key            = "containers/example-windows/dev.tfstate" # Change this for each project
    encrypt        = true
    dynamodb_table = "dev-automation-tf"
  }
}
