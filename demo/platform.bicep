// Platform-engineer baseline for the direct-module demo.
//
// The recipe pack points `recipeLocation` directly at a STANDARD Terraform
// module (../modules/redis) that has no `context` variable and no structured
// `result` output. Radius:
//   1. resolves the {{context.*}} expressions in `parameters` against the
//      resource being deployed,
//   2. runs the module through the existing Terraform driver, and
//   3. maps the module's plain outputs onto the resource's properties via the
//      `outputs` field (module output `host` -> property `endpoint`).
//
// Deploy:
//   rad deploy platform.bicep \
//     -p moduleTemplatePath='git::https://github.com/<org>/<repo>.git//modules/redis?ref=<sha>'

extension radius

@description('git:: source for the standard Terraform Redis module used as a direct recipe.')
param moduleTemplatePath string

@description('Kubernetes namespace the environment provisions resources into by default.')
param envNamespace string = 'default'

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'direct-module-recipes'
  properties: {
    recipes: {
      'Demo.Datastores/redisCaches': {
        // recipeLocation points straight at a plain Terraform module — no
        // wrapping, no `context` variable, no `result` output required.
        recipeKind: 'terraform'
        recipeLocation: moduleTemplatePath
        parameters: {
          name: '{{context.resource.name}}'
          namespace: '{{context.runtime.kubernetes.namespace}}'
          port: 6379
        }
        // Map the module's outputs onto the resource's properties.
        // Keys are resource property names; values are module output names.
        outputs: {
          endpoint: 'host'
          port: 'port'
        }
      }
    }
  }
}

resource env 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'default'
  properties: {
    providers: {
      kubernetes: {
        namespace: envNamespace
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
