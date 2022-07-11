param(
  $awsAccountId,
  $awsRegion = 'us-east-2',
  $createRepo = $true,
  $updateFluentDImage = $true,
  $fluentDVersion = 'v1.14-windows-ltsc2019-1'
)

# Create ECR repository if needed
if ($createRepo) {
  New-ECRRepository -RepositoryName fluentd -EncryptionConfiguration_EncryptionType KMS -RegistryId $awsAccountId -ImageScanningConfiguration_ScanOnPush $true -Force
}

# Login to ECR
(Get-ECRLoginCommand).Password | docker login --username AWS --password-stdin "$awsAccountId.dkr.ecr.$awsRegion.amazonaws.com"

# Store FluentD image in ECR to avoid Docker rate limit issues
if ($updateFluentDImage) {
  docker pull "fluent/fluentd:$fluentDVersion"
  docker tag "fluent/fluentd:$fluentDVersion" "$awsAccountId.dkr.ecr.$awsRegion.amazonaws.com/fluentd:$fluentDVersion"
  docker push "$awsAccountId.dkr.ecr.$awsRegion.amazonaws.com/fluentd:$fluentDVersion"
}

docker build -t "$awsAccountId.dkr.ecr.$awsRegion.amazonaws.com/fluentd:$fluentDVersion-with-aws-cw" --build-arg AWS_ACCOUNT_ID=$awsAccountId --build-arg AWS_REGION=$awsRegion --build-arg FLUENTD_VERSION=$fluentDVersion .
docker push "$awsAccountId.dkr.ecr.$awsRegion.amazonaws.com/fluentd:$fluentDVersion-with-aws-cw"
