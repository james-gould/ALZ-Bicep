targetScope = 'subscription'

// ============================================================================
//  healthmodel-policy
//  Deploys a DeployIfNotExists policy that creates a Microsoft.CloudHealth
//  health model whose discovery rule finds every other health model in a
//  resource group and roots them under the model, then assigns it. The only
//  resource-group-scoped piece (the discovery identity) is imported as a
//  module. Deploy this file; it deploys everything.
// ============================================================================

// ----------------------------------------------------------------------------
//  Parameters
// ----------------------------------------------------------------------------

@description('Location for the discovery identity, policy assignment identity and remediation deployments. Must support Microsoft.CloudHealth (for example uksouth, centralus, swedencentral, northeurope).')
param location string = 'uksouth'

@description('Resource group the health model is deployed into and whose health models are discovered. Must already exist.')
param targetResourceGroupName string = 'rg-aon2-global'

@description('Health model name to deploy.')
param healthModelName string = 'hm-portfolio-aon2'

@description('Name of the user-assigned managed identity the discovery rule runs as.')
param identityName string = 'id-ahm-discovery'

@description('Policy definition name.')
param policyName string = 'deploy-cloudhealth-portfolio-healthmodel'

@description('Policy assignment name.')
@maxLength(24)
param assignmentName string = 'deploy-ahm-discovery'

@description('Policy effect.')
@allowed([
  'DeployIfNotExists'
  'Disabled'
])
param effect string = 'DeployIfNotExists'

@description('Enforcement mode for the assignment.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Resource Graph query for discovery. Leave empty to discover all health models in the target resource group except the deployed model.')
param resourceGraphQuery string = ''

// ----------------------------------------------------------------------------
//  Variables
// ----------------------------------------------------------------------------

var builtInRoleIds = {
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  ManagedIdentityOperator: 'f1a07417-d97a-45cb-824c-7a7467783830'
}

var discoveryQuery = empty(resourceGraphQuery) ? 'resources | where type =~ \'microsoft.cloudhealth/healthmodels\' | where resourceGroup =~ \'${targetResourceGroupName}\' | where name !~ \'${healthModelName}\' | project id' : resourceGraphQuery

resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: targetResourceGroupName
}

// ----------------------------------------------------------------------------
//  Discovery identity (resource-group-scoped module)
// ----------------------------------------------------------------------------

module discoveryIdentity 'healthmodel-discovery-identity.bicep' = {
  scope: targetResourceGroup
  name: 'ahm-discovery-identity'
  params: {
    identityName: identityName
    location: location
  }
}

// ----------------------------------------------------------------------------
//  Policy definition (DeployIfNotExists)
//  Embedded template (runs at remediation): health model + authentication
//  setting + discovery rule + a relationship that roots the discovery entity
//  under the model. dependsOn here is inside the policy's ARM payload and is
//  required by the CloudHealth resource provider (parent and reference
//  existence are validated server-side).
// ----------------------------------------------------------------------------

resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2025-01-01' = {
  name: policyName
  properties: {
    displayName: 'Deploy a Microsoft CloudHealth health model that discovers all health models in a resource group'
    description: 'Deploys a Microsoft.CloudHealth health model and a discovery rule that discovers all health models in the target resource group, when missing.'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Monitoring'
      version: '1.0.0'
      preview: true
    }
    parameters: {
      effect: {
        type: 'String'
        allowedValues: [
          'DeployIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      targetResourceGroupName: {
        type: 'String'
      }
      healthModelName: {
        type: 'String'
      }
      location: {
        type: 'String'
      }
      userAssignedIdentityId: {
        type: 'String'
      }
      authenticationSettingName: {
        type: 'String'
        defaultValue: 'managed-identity'
      }
      discoveryRuleName: {
        type: 'String'
        defaultValue: 'discover-healthmodels'
      }
      discoveryRuleDisplayName: {
        type: 'String'
        defaultValue: 'Discover all health models in the resource group'
      }
      relationshipName: {
        type: 'String'
        defaultValue: 'root-to-discovery'
      }
      resourceGraphQuery: {
        type: 'String'
      }
      addRecommendedSignals: {
        type: 'String'
        allowedValues: [
          'Enabled'
          'Disabled'
        ]
        defaultValue: 'Disabled'
      }
      addResourceHealthSignal: {
        type: 'String'
        allowedValues: [
          'Enabled'
          'Disabled'
        ]
        defaultValue: 'Disabled'
      }
      discoverRelationships: {
        type: 'String'
        allowedValues: [
          'Enabled'
          'Disabled'
        ]
        defaultValue: 'Disabled'
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Resources/subscriptions/resourceGroups'
          }
          {
            field: 'name'
            equals: '[parameters(\'targetResourceGroupName\')]'
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.CloudHealth/healthmodels'
          existenceScope: 'resourceGroup'
          existenceCondition: {
            field: 'name'
            equals: '[parameters(\'healthModelName\')]'
          }
          deploymentScope: 'resourceGroup'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/${builtInRoleIds.Contributor}'
            '/providers/Microsoft.Authorization/roleDefinitions/${builtInRoleIds.ManagedIdentityOperator}'
          ]
          deployment: {
            properties: {
              mode: 'Incremental'
              parameters: {
                healthModelName: {
                  value: '[parameters(\'healthModelName\')]'
                }
                location: {
                  value: '[parameters(\'location\')]'
                }
                userAssignedIdentityId: {
                  value: '[parameters(\'userAssignedIdentityId\')]'
                }
                authenticationSettingName: {
                  value: '[parameters(\'authenticationSettingName\')]'
                }
                discoveryRuleName: {
                  value: '[parameters(\'discoveryRuleName\')]'
                }
                discoveryRuleDisplayName: {
                  value: '[parameters(\'discoveryRuleDisplayName\')]'
                }
                relationshipName: {
                  value: '[parameters(\'relationshipName\')]'
                }
                resourceGraphQuery: {
                  value: '[parameters(\'resourceGraphQuery\')]'
                }
                addRecommendedSignals: {
                  value: '[parameters(\'addRecommendedSignals\')]'
                }
                addResourceHealthSignal: {
                  value: '[parameters(\'addResourceHealthSignal\')]'
                }
                discoverRelationships: {
                  value: '[parameters(\'discoverRelationships\')]'
                }
              }
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  healthModelName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                  userAssignedIdentityId: {
                    type: 'string'
                  }
                  authenticationSettingName: {
                    type: 'string'
                  }
                  discoveryRuleName: {
                    type: 'string'
                  }
                  discoveryRuleDisplayName: {
                    type: 'string'
                  }
                  relationshipName: {
                    type: 'string'
                  }
                  resourceGraphQuery: {
                    type: 'string'
                  }
                  addRecommendedSignals: {
                    type: 'string'
                  }
                  addResourceHealthSignal: {
                    type: 'string'
                  }
                  discoverRelationships: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.CloudHealth/healthmodels'
                    apiVersion: '2026-05-01-preview'
                    name: '[parameters(\'healthModelName\')]'
                    location: '[parameters(\'location\')]'
                    identity: {
                      type: 'UserAssigned'
                      userAssignedIdentities: {
                        '[parameters(\'userAssignedIdentityId\')]': {}
                      }
                    }
                    properties: {}
                  }
                  {
                    type: 'Microsoft.CloudHealth/healthmodels/authenticationsettings'
                    apiVersion: '2026-05-01-preview'
                    name: '[format(\'{0}/{1}\', parameters(\'healthModelName\'), parameters(\'authenticationSettingName\'))]'
                    properties: {
                      authenticationKind: 'ManagedIdentity'
                      managedIdentityName: '[parameters(\'userAssignedIdentityId\')]'
                    }
                    dependsOn: [
                      '[resourceId(\'Microsoft.CloudHealth/healthmodels\', parameters(\'healthModelName\'))]'
                    ]
                  }
                  {
                    type: 'Microsoft.CloudHealth/healthmodels/discoveryrules'
                    apiVersion: '2026-05-01-preview'
                    name: '[format(\'{0}/{1}\', parameters(\'healthModelName\'), parameters(\'discoveryRuleName\'))]'
                    properties: {
                      displayName: '[parameters(\'discoveryRuleDisplayName\')]'
                      authenticationSetting: '[parameters(\'authenticationSettingName\')]'
                      addRecommendedSignals: '[parameters(\'addRecommendedSignals\')]'
                      addResourceHealthSignal: '[parameters(\'addResourceHealthSignal\')]'
                      discoverRelationships: '[parameters(\'discoverRelationships\')]'
                      specification: {
                        kind: 'ResourceGraphQuery'
                        resourceGraphQuery: '[parameters(\'resourceGraphQuery\')]'
                      }
                    }
                    dependsOn: [
                      '[resourceId(\'Microsoft.CloudHealth/healthmodels/authenticationsettings\', parameters(\'healthModelName\'), parameters(\'authenticationSettingName\'))]'
                    ]
                  }
                  {
                    type: 'Microsoft.CloudHealth/healthmodels/relationships'
                    apiVersion: '2026-05-01-preview'
                    name: '[format(\'{0}/{1}\', parameters(\'healthModelName\'), parameters(\'relationshipName\'))]'
                    properties: {
                      parentEntityName: '[parameters(\'healthModelName\')]'
                      childEntityName: '[parameters(\'discoveryRuleName\')]'
                    }
                    dependsOn: [
                      '[resourceId(\'Microsoft.CloudHealth/healthmodels/discoveryrules\', parameters(\'healthModelName\'), parameters(\'discoveryRuleName\'))]'
                    ]
                  }
                ]
              }
            }
          }
        }
      }
    }
  }
}

// ----------------------------------------------------------------------------
//  Policy assignment
// ----------------------------------------------------------------------------

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: assignmentName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Deploy CloudHealth health model with resource group discovery'
    policyDefinitionId: policyDefinition.id
    enforcementMode: enforcementMode
    parameters: {
      effect: {
        value: effect
      }
      targetResourceGroupName: {
        value: targetResourceGroupName
      }
      healthModelName: {
        value: healthModelName
      }
      location: {
        value: location
      }
      userAssignedIdentityId: {
        value: discoveryIdentity.outputs.identityId
      }
      resourceGraphQuery: {
        value: discoveryQuery
      }
    }
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in items(builtInRoleIds): {
    name: guid(subscription().id, assignmentName, role.value)
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.value)
      principalId: policyAssignment.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ----------------------------------------------------------------------------
//  Outputs
// ----------------------------------------------------------------------------

output policyDefinitionId string = policyDefinition.id
output policyAssignmentId string = policyAssignment.id
output discoveryIdentityId string = discoveryIdentity.outputs.identityId
