extension radius
extension redisCaches

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'direct-module-demo'
  properties: {
    environment: environment
  }
}

// A standard Radius resource. The platform engineer wired its recipe to a
// plain Terraform module (see platform.bicep), so this developer-facing
// definition carries no module details at all. `endpoint` and `port` are
// populated by Radius from the module's outputs.
resource cache 'Demo.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'demo-redis'
  properties: {
    environment: environment
    application: app.id
  }
}

@description('In-cluster Redis endpoint, mapped from the module `host` output by the recipe.')
output endpoint string = cache.properties.endpoint

@description('Redis port, mapped from the module `port` output by the recipe.')
output port string = cache.properties.port
