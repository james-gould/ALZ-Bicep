targetScope = 'resourceGroup'

@description('Name of the user-assigned managed identity the discovery rule runs as.')
param identityName string = 'id-ahm-discovery'

@description('Location for the managed identity.')
param location string = resourceGroup().location

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
}

resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, identityName, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output identityId string = identity.id
output principalId string = identity.properties.principalId
