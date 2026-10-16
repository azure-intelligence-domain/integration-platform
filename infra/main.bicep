// The shared foundation of the integration platform (ADR 0010, 0011, 0012), in rg-intplat-platform,
// plus the tap in rg-intplat-tap. Deployed by this repository's own identity, which only has rights
// on those two resource groups.

@description('Region of everything except API Management.')
param location string = 'belgiumcentral'

@description('API Management Consumption is not offered in Belgium Central; France Central is the fallback (ADR 0003).')
param apiManagementLocation string = 'francecentral'

@description('Receives API Management notifications. Passed at deploy time, never committed.')
param publisherEmail string

@description('One Event Grid topic per business domain.')
param domains array = ['sales', 'finance', 'supply', 'logistics']

@description('Application (client) id of the intplat-agent-gateway Entra application (bootstrap/agent-gateway-app.sh in azure-landing-zone).')
param agentGatewayAppId string = '881433d3-4894-411b-8b31-6912a67ef43f'

@description('Principal id of this pipeline\'s identity: publishes tap probes, reads the tap queue length.')
param pipelinePrincipalId string

@description('Principal ids of every building block identity: they may publish platform events (deployments).')
param buildingBlockPrincipalIds array

var tags = {
  project: 'ai-intelligence-domain'
  component: 'integration-platform'
  owner: 'platform-team'
}
var topicNames = concat(domains, ['platform'])

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    tags: tags
  }
}

module messaging 'modules/messaging.bicep' = {
  name: 'messaging'
  params: {
    location: location
    tags: tags
    topicNames: topicNames
    workspaceId: monitoring.outputs.workspaceId
  }
}

module tap 'modules/tap.bicep' = {
  name: 'tap'
  scope: resourceGroup('rg-intplat-tap')
  params: {
    location: location
    tags: union(tags, { component: 'tap' })
    topicPrincipalIds: map(messaging.outputs.topics, t => t.principalId)
    pipelinePrincipalId: pipelinePrincipalId
  }
}

module tapWiring 'modules/tap-wiring.bicep' = {
  name: 'tap-wiring'
  params: {
    topicNames: map(messaging.outputs.topics, t => t.name)
    tapStorageId: tap.outputs.storageId
    tapQueueName: tap.outputs.queueName
    tapDeadLetterContainer: tap.outputs.deadLetterContainer
    workspaceName: monitoring.outputs.workspaceName
  }
}

module publishers 'modules/publishers.bicep' = {
  name: 'publishers'
  dependsOn: [messaging]
  params: {
    allTopicsPrincipalIds: [pipelinePrincipalId]
    platformTopicPrincipalIds: buildingBlockPrincipalIds
  }
}

module peopleGateway 'modules/api-management.bicep' = {
  name: 'gateway-people'
  dependsOn: [messaging]
  params: {
    name: 'apim-intplat-demo'
    location: apiManagementLocation
    tags: tags
    publisherEmail: publisherEmail
    appInsightsName: monitoring.outputs.appInsightsName
    globalPolicy: loadTextContent('policies/people-gateway.xml')
    product: {
      name: 'platform'
      displayName: 'Platform'
      description: 'APIs of the integration platform itself.'
    }
  }
}

module agentGateway 'modules/api-management.bicep' = {
  name: 'gateway-agents'
  dependsOn: [messaging]
  params: {
    name: 'apim-intplat-agents'
    location: apiManagementLocation
    tags: tags
    publisherEmail: publisherEmail
    appInsightsName: monitoring.outputs.appInsightsName
    globalPolicy: loadTextContent('policies/agent-gateway.xml')
    product: {
      name: 'agents'
      displayName: 'Agents'
      description: 'Commands AI agents may send to the integration platform. Every call is audited in the tap.'
    }
    productPolicy: loadTextContent('policies/agents-product.xml')
    namedValues: {
      'tenant-id': tenant().tenantId
      'agent-gateway-app-id': agentGatewayAppId
    }
  }
}

output peopleGatewayUrl string = peopleGateway.outputs.gatewayUrl
output agentGatewayUrl string = agentGateway.outputs.gatewayUrl
output workspaceCustomerId string = monitoring.outputs.workspaceCustomerId
output topics array = messaging.outputs.topics
output serviceBusName string = messaging.outputs.serviceBusName
output agentGatewayAudience string = 'api://${agentGatewayAppId}'
