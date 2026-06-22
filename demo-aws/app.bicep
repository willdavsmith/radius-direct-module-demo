extension radius
extension buckets

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'direct-module-aws-demo'
  properties: {
    environment: environment
  }
}

// A standard Radius resource. The platform engineer wired its recipe to a plain
// Terraform Registry module (see platform.bicep), so this developer-facing
// definition carries no module details at all. `bucketName`, `bucketArn`, and
// `bucketRegion` are populated by Radius from the module's outputs.
resource bucket 'Demo.AWS/buckets@2023-10-01-preview' = {
  name: 'demo-bucket'
  properties: {
    environment: environment
    application: app.id
  }
}

@description('Name of the created S3 bucket, mapped from the module `s3_bucket_id` output by the recipe.')
output bucketName string = bucket.properties.bucketName

@description('ARN of the created S3 bucket, mapped from the module `s3_bucket_arn` output by the recipe.')
output bucketArn string = bucket.properties.bucketArn
