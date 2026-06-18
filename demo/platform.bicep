// Platform-engineer baseline for the direct-module demo.
//
// The recipe pack points `recipeLocation` directly at a STANDARD, off-the-shelf
// Terraform Registry module (terraform-iaac/deployment/kubernetes) — no Radius
// wrapping, no `context` variable, no `result` output. Radius:
//   1. resolves the {{context.*}} expressions in `parameters` against the
//      resource being deployed,
//   2. runs the module through the existing Terraform driver, and
//   3. maps the module's plain outputs onto the resource's properties via the
//      `outputs` field.
//
// The registry module version is pinned with the Radius `<source>:<version>`
// convention, which the Terraform driver splits into the module `source` and
// `version` fields of the generated main.tf.json.

extension radius

@description('Kubernetes namespace the environment provisions resources into by default.')
param envNamespace string = 'default'

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'direct-module-recipes'
  properties: {
    recipes: {
      'Demo.Kubernetes/deployments': {
        recipeKind: 'terraform'
        // Standard Terraform Registry module, version pinned with `:<version>`
        // (https://registry.terraform.io/modules/terraform-iaac/deployment/kubernetes).
        recipeLocation: 'terraform-iaac/deployment/kubernetes:1.4.6'
        parameters: {
          name: '{{context.resource.name}}'
          namespace: '{{context.runtime.kubernetes.namespace}}'
          image: '{{context.resource.properties.image}}'
        }
        // Map the module's outputs onto the resource's properties.
        // Keys are resource property names; values are module output names.
        outputs: {
          deploymentName: 'name'
          namespace: 'namespace'
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
