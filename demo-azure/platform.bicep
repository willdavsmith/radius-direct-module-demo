// Platform-engineer baseline for the Azure direct-module demo.
//
// The recipe pack points `recipeLocation` directly at a STANDARD Azure Verified
// Module (AVM) published to the Microsoft Container Registry — no Radius
// wrapping, no `context` parameter, no `result` output. Radius:
//   1. resolves the {{context.*}} expressions in `parameters` against the
//      resource being deployed,
//   2. runs the module through the existing Bicep driver and deployment engine —
//      deploying to the environment's Azure subscription + resource group below
//      with the credentials registered via `rad credential register azure sp`,
//      and
//   3. maps the module's plain outputs onto the resource's properties via the
//      `outputs` field.
//
// The AVM version is pinned with the standard Bicep/OCI `:<tag>` syntax, which
// Radius reads directly from `recipeLocation`.

extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into.')
param azureResourceGroup string

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'direct-module-azure-recipes'
  properties: {
    recipes: {
      'Demo.Azure/storageAccounts': {
        recipeKind: 'bicep'
        // Standard Azure Verified Module, version pinned with `:<tag>`
        // (https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/storage/storage-account).
        recipeLocation: 'mcr.microsoft.com/bicep/avm/res/storage/storage-account:0.14.3'
        parameters: {
          // The storage account name must be globally unique and <=24 lowercase
          // alphanumerics; the developer supplies a unique value on the resource.
          name: '{{context.resource.properties.accountName}}'
          skuName: 'Standard_LRS'
          kind: 'StorageV2'
          // AVM modules emit a Microsoft.Resources/deployments telemetry resource
          // (api-version 2024-03-01) that the Radius bicep deployment engine can't
          // process at location "global". Disabling telemetry skips it — this is
          // the standard AVM-sanctioned opt-out, not a workaround.
          enableTelemetry: false
        }
        // Map the module's outputs onto the resource's properties.
        // Keys are resource property names; values are module output names.
        // `location` is computed by the module (we don't pass it), so it proves
        // a value the developer never supplied flows back from the module.
        outputs: {
          accountId: 'resourceId'
          location: 'location'
        }
      }
    }
  }
}

resource env 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'default'
  properties: {
    providers: {
      azure: {
        subscriptionId: azureSubscriptionId
        resourceGroupName: azureResourceGroup
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
