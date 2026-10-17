// The shared foundation of the integration platform (ADR 0010, 0011, 0012, 0014), in
// rg-intplat-platform, plus the tap in rg-intplat-tap. Deployed by this repository's own identity,
// which only has rights on those two resource groups (and reads the identities).
// The routing is configuration, in ../routing: which APIs the gateways serve, who publishes where,
// who may call the Process and System APIs, who receives which facts, and which staff may sign in
// from which web pages.

@description('Region of everything except API Management.')
param location string = 'belgiumcentral'

@description('API Management Consumption is not offered in Belgium Central; France Central is the fallback (ADR 0003).')
param apiManagementLocation string = 'francecentral'

@description('Receives API Management notifications. Passed at deploy time, never committed.')
param publisherEmail string

@description('One Event Grid topic per business domain.')
param domains array = ['sales', 'finance', 'supply', 'logistics', 'order']

@description('Application (client) id of the intplat-agent-gateway Entra application (bootstrap/agent-gateway-app.sh in azure-landing-zone).')
param agentGatewayAppId string = '881433d3-4894-411b-8b31-6912a67ef43f'

@description('Application (client) id of the intplat-platform-apis Entra application, the audience of internal calls (bootstrap/platform-apis-app.sh in azure-landing-zone).')
param platformApisAppId string = 'e3337087-144a-4b2e-8faa-c802660b9dee'

@description('Backends of the consumers that exist, by name: { baseUrl, path } (resolved by the pipeline from routing/consumers.yaml).')
param intakeBackends object = {}

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
var apis = loadYamlContent('../routing/apis.yaml').apis
var producers = loadYamlContent('../routing/producers.yaml').producers
var internalCallers = loadYamlContent('../routing/internal-callers.yaml').callers
var consumers = loadYamlContent('../routing/consumers.yaml').consumers
var staff = loadYamlContent('../routing/staff.yaml')

// People and websites reach the Experience APIs only; building blocks the Process and System APIs.
var peopleProducts = [
  {
    name: 'platform'
    displayName: 'Platform'
    description: 'APIs of the integration platform itself.'
    subscriptionRequired: true
  }
  {
    name: 'webshop'
    displayName: 'Webshop'
    description: 'The webshop channel, for staff signed in with Google through the customer portal (ADR 0017).'
    subscriptionRequired: false
    policy: loadTextContent('policies/staff-product.xml')
  }
  {
    name: 'customer-service'
    displayName: 'Customer Service'
    description: 'Customer service, for staff signed in with Google through the customer portal (ADR 0017).'
    subscriptionRequired: false
    policy: loadTextContent('policies/staff-product.xml')
  }
  {
    name: 'partners'
    displayName: 'Partners'
    description: 'The 3PL partner\'s notices; in the demo, staff play the partner through the customer portal (ADR 0017).'
    subscriptionRequired: false
    policy: loadTextContent('policies/staff-product.xml')
  }
  {
    name: 'process-apis'
    displayName: 'Process APIs'
    description: 'Process APIs, for building blocks only: an Entra ID token of a runtime identity on the platform allow-list, no subscription key (ADR 0014, 0017).'
    subscriptionRequired: false
    policy: loadTextContent('policies/system-apis-product.xml')
  }
  {
    name: 'system-apis'
    displayName: 'System APIs'
    description: 'System APIs, for building blocks only: an Entra ID token of a runtime identity on the platform allow-list, no subscription key (ADR 0014).'
    subscriptionRequired: false
    policy: loadTextContent('policies/system-apis-product.xml')
  }
]

// Runtime identities are created by the landing zone; the routing names them, Azure resolves them.
resource producerIdentities 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = [
  for p in producers: {
    scope: resourceGroup('rg-intplat-identities')
    name: p.identity
  }
]

resource callerIdentities 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = [
  for name in internalCallers: {
    scope: resourceGroup('rg-intplat-identities')
    name: name
  }
]

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
    producers: [
      for (p, i) in producers: {
        principalId: producerIdentities[i].properties.principalId
        topics: p.topics
      }
    ]
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
    globalPolicy: replace(loadTextContent('policies/people-gateway.xml'), '<!-- origins -->',
      join(map(staff.origins, origin => '<origin>${origin}</origin>'), ''))
    products: peopleProducts
    internalCallerClientIds: [for (name, i) in internalCallers: callerIdentities[i].properties.clientId]
    namedValues: {
      'tenant-id': tenant().tenantId
      'platform-apis-app-id': platformApisAppId
      'google-client-id': staff.google.clientId
      'staff-domain': staff.google.domain
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
    products: [
      {
        name: 'agents'
        displayName: 'Agents'
        description: 'Commands AI agents may send to the integration platform. Every call is audited in the tap.'
        subscriptionRequired: true
        policy: loadTextContent('policies/agents-product.xml')
      }
    ]
    namedValues: {
      'tenant-id': tenant().tenantId
      'agent-gateway-app-id': agentGatewayAppId
      'platform-apis-app-id': platformApisAppId
    }
  }
}

module peopleApis 'modules/apis.bicep' = {
  name: 'apis-people'
  params: {
    apimName: peopleGateway.outputs.name
    gateway: 'people'
    apis: apis
    keylessProducts: map(filter(peopleProducts, p => !p.subscriptionRequired), p => p.name)
  }
}

module agentApis 'modules/apis.bicep' = {
  name: 'apis-agents'
  params: {
    apimName: agentGateway.outputs.name
    gateway: 'agents'
    apis: apis
  }
}

module intake 'modules/intake.bicep' = {
  name: 'intake'
  params: {
    apimName: peopleGateway.outputs.name
    consumers: consumers
    backends: intakeBackends
    topicPrincipalIds: toObject(messaging.outputs.topics, t => t.name, t => t.principalId)
    tapStorageId: tap.outputs.storageId
    deadLetterContainer: tap.outputs.consumerDeadLetterContainer
    platformApisAppId: platformApisAppId
  }
}

output peopleGatewayUrl string = peopleGateway.outputs.gatewayUrl
output agentGatewayUrl string = agentGateway.outputs.gatewayUrl
output workspaceCustomerId string = monitoring.outputs.workspaceCustomerId
output topics array = messaging.outputs.topics
output serviceBusName string = messaging.outputs.serviceBusName
output agentGatewayAudience string = 'api://${agentGatewayAppId}'
output platformApisAudience string = 'api://${platformApisAppId}'
output intakeSubscriptions array = intake.outputs.subscriptions
output gatewayPrincipalIds array = [peopleGateway.outputs.principalId, agentGateway.outputs.principalId]
