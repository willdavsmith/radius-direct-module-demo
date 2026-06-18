extension radius
extension deployments

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'direct-module-demo'
  properties: {
    environment: environment
  }
}

// A standard Radius resource. The platform engineer wired its recipe to a plain
// Terraform Registry module (see platform.bicep), so this developer-facing
// definition only sets the image. `deploymentName` and `namespace` are
// populated by Radius from the module's outputs.
resource deployment 'Demo.Kubernetes/deployments@2023-10-01-preview' = {
  name: 'demo-redis'
  properties: {
    environment: environment
    application: app.id
    image: 'redis:7-alpine'
  }
}

@description('Name of the Kubernetes Deployment, mapped from the module `name` output by the recipe.')
output deploymentName string = deployment.properties.deploymentName

@description('Namespace the Deployment runs in, mapped from the module `namespace` output by the recipe.')
output namespace string = deployment.properties.namespace
