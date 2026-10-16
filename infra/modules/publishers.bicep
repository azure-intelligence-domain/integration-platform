// Who may publish to which topic (EventGrid Data Sender), granted by the platform within its own
// resource group. The platform owns the routing (ADR 0011).

@description('Principals that may publish to every topic (the platform pipeline, for its tap probes).')
param allTopicsPrincipalIds array

@description('Principals that may publish platform events (gateways and every building block, for deployment events).')
param platformTopicPrincipalIds array

param platformTopicName string = 'evgt-intplat-platform'

var dataSender = 'd5a91429-5739-47e2-a06b-3470a27159e7' // EventGrid Data Sender

resource platformTopic 'Microsoft.EventGrid/topics@2025-02-15' existing = {
  name: platformTopicName
}

resource allTopics 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in allTopicsPrincipalIds: {
    name: guid(resourceGroup().id, principalId, dataSender)
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dataSender)
      description: 'May publish to every platform topic (tap probes).'
    }
  }
]

resource platformEvents 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in platformTopicPrincipalIds: {
    name: guid(platformTopic.id, principalId, dataSender)
    scope: platformTopic
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dataSender)
      description: 'May publish platform events (gateway actions, agent actions, deployments).'
    }
  }
]
