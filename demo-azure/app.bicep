extension radius
extension storageaccounts

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('Globally-unique storage account name (3-24 lowercase alphanumerics). The E2E workflow generates a unique value per run.')
param accountName string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'direct-module-azure-demo'
  properties: {
    environment: environment
  }
}

// A standard Radius resource. The platform engineer wired its recipe to a plain
// Azure Verified Module (see platform.bicep), so this developer-facing
// definition only supplies the (unique) account name. `accountId` and
// `primaryBlobEndpoint` are populated by Radius from the module's outputs.
resource account 'Demo.Azure/storageAccounts@2023-10-01-preview' = {
  name: 'demo-storage'
  properties: {
    environment: environment
    application: app.id
    accountName: accountName
  }
}

@description('Resource ID of the created storage account, mapped from the module `resourceId` output by the recipe.')
output accountId string = account.properties.accountId

@description('Primary blob endpoint, mapped from the module `primaryBlobEndpoint` output by the recipe.')
output primaryBlobEndpoint string = account.properties.primaryBlobEndpoint
