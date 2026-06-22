// Platform-engineer baseline for the AWS direct-module demo.
//
// The recipe pack points `recipeLocation` directly at a STANDARD, off-the-shelf
// Terraform Registry module (terraform-aws-modules/ecr/aws) — no Radius
// wrapping, no `context` variable, no `result` output. Radius:
//   1. resolves the {{context.*}} expressions in `parameters` against the
//      resource being deployed,
//   2. runs the module through the existing Terraform driver — injecting the
//      AWS credentials registered with `rad credential register aws access-key`
//      and the region from the environment's AWS provider below, and
//   3. maps the module's plain outputs onto the resource's properties via the
//      `outputs` field.
//
// The registry module version is pinned with the Radius `<source>:<version>`
// convention, which the Terraform driver splits into the module `source` and
// `version` fields of the generated main.tf.json.

extension radius

@description('AWS account ID the environment provisions resources into.')
param awsAccountId string

@description('AWS region the environment provisions resources into.')
param awsRegion string

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'direct-module-aws-recipes'
  properties: {
    recipes: {
      'Demo.AWS/repositories': {
        recipeKind: 'terraform'
        // Standard Terraform Registry module, version pinned with `:<version>`
        // (https://registry.terraform.io/modules/terraform-aws-modules/ecr/aws).
        recipeLocation: 'terraform-aws-modules/ecr/aws:3.2.0'
        parameters: {
          // The repository name is derived from the resource name via a
          // {{context.*}} expression. `create_repository_policy: false` keeps
          // the module to a single `aws_ecr_repository` resource, and
          // `repository_force_delete: true` lets cleanup tear it down cleanly.
          repository_name: '{{context.resource.name}}'
          create_repository_policy: false
          repository_force_delete: true
        }
        // Map the module's outputs onto the resource's properties.
        // Keys are resource property names; values are module output names.
        outputs: {
          repositoryName: 'repository_name'
          repositoryArn: 'repository_arn'
          repositoryUrl: 'repository_url'
        }
      }
    }
  }
}

resource env 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'default'
  properties: {
    providers: {
      aws: {
        accountId: awsAccountId
        region: awsRegion
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
