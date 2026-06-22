// Platform-engineer baseline for the AWS direct-module demo.
//
// The recipe pack points `recipeLocation` directly at a STANDARD, off-the-shelf
// Terraform Registry module (terraform-aws-modules/sns/aws) — no Radius
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
      'Demo.AWS/topics': {
        recipeKind: 'terraform'
        // Standard Terraform Registry module, version pinned with `:<version>`
        // (https://registry.terraform.io/modules/terraform-aws-modules/sns/aws).
        recipeLocation: 'terraform-aws-modules/sns/aws:7.1.0'
        parameters: {
          // `use_name_prefix` makes the module treat `name` as a prefix and
          // append a unique suffix, so the topic name never collides across
          // runs. The prefix is derived from the resource name via a
          // {{context.*}} expression.
          name: '{{context.resource.name}}'
          use_name_prefix: true
        }
        // Map the module's outputs onto the resource's properties.
        // Keys are resource property names; values are module output names.
        outputs: {
          topicName: 'topic_name'
          topicArn: 'topic_arn'
          topicOwner: 'topic_owner'
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
