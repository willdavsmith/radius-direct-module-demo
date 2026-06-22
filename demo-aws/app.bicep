extension radius
extension topics

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
// definition carries no module details at all. `topicName`, `topicArn`, and
// `topicOwner` are populated by Radius from the module's outputs.
resource topic 'Demo.AWS/topics@2023-10-01-preview' = {
  name: 'demo-topic'
  properties: {
    environment: environment
    application: app.id
  }
}

@description('Name of the created SNS topic, mapped from the module `topic_name` output by the recipe.')
output topicName string = topic.properties.topicName

@description('ARN of the created SNS topic, mapped from the module `topic_arn` output by the recipe.')
output topicArn string = topic.properties.topicArn
