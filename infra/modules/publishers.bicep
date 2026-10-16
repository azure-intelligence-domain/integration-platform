// Who may publish to which topic (EventGrid Data Sender), granted by the platform within its own
// resource group. The platform owns the routing (ADR 0011, 0014: routing/producers.yaml).

@description('Principals that may publish to every topic (the platform pipeline, for its tap probes).')
param allTopicsPrincipalIds array

@description('Principals that may publish platform events (every building block identity, for deployment events).')
param platformTopicPrincipalIds array

@description('Producers of domain events: principalId and the topics (domain names) it publishes to.')
param producers array

param platformTopicName string = 'evgt-intplat-platform'

var dataSender = 'd5a91429-5739-47e2-a06b-3470a27159e7' // EventGrid Data Sender
var grants = flatten(map(producers, p => map(p.topics, t => { principalId: p.principalId, topic: 'evgt-intplat-${t}' })))

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

resource producerTopics 'Microsoft.EventGrid/topics@2025-02-15' existing = [
  for g in grants: {
    name: g.topic
  }
]

resource domainEvents 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (g, i) in grants: {
    name: guid(producerTopics[i].id, g.principalId, dataSender)
    scope: producerTopics[i]
    properties: {
      principalId: g.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dataSender)
      description: 'Producer of ${g.topic} (routing/producers.yaml).'
    }
  }
]
