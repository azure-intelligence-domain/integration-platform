// One API Management (Consumption) gateway. Used twice: apim-intplat-demo for people and websites,
// apim-intplat-agents for AI agents (ADR 0010, 0012). Each gets its own global policy, product and
// smoke-test subscription; every call is traced to Application Insights (W3C), and the gateway's
// managed identity may publish to the platform topic (the tap of gateway and agent actions).

param name string
param location string
param tags object
param publisherEmail string
param appInsightsName string

@description('Global policy (XML), applies to every API on this gateway.')
param globalPolicy string

@description('Products on this gateway: name, displayName, description, subscriptionRequired, optional policy (XML). The Health API joins the first.')
param products product[]

@description('Client ids allowed in by product policies, filled in where a policy has the comment <!-- internal callers -->.')
param internalCallerClientIds array = []

@description('Named values referenced by the policies as {{name}}.')
param namedValues object = {}

param platformTopicName string = 'evgt-intplat-platform'

@export()
type product = {
  name: string
  displayName: string
  description: string
  subscriptionRequired: bool
  policy: string?
}

var dataSender = 'd5a91429-5739-47e2-a06b-3470a27159e7' // EventGrid Data Sender

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource platformTopic 'Microsoft.EventGrid/topics@2025-02-15' existing = {
  name: platformTopicName
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: 'Azure Intelligence Domain'
  }
}

resource publishesActions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(platformTopic.id, apim.id, dataSender)
  scope: platformTopic
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dataSender)
    description: '${name}: publishes gateway actions to the tap.'
  }
}

resource values 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = [
  for item in items(namedValues): {
    parent: apim
    name: item.key
    properties: {
      displayName: item.key
      value: item.value
    }
  }
]

resource logger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = {
  parent: apim
  name: 'appinsights'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsights.id
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
  }
}

resource tracing 'Microsoft.ApiManagement/service/diagnostics@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: logger.id
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: false
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: { headers: ['Correlation-Id'] }
      response: { headers: ['Correlation-Id'] }
    }
    backend: {
      request: { headers: ['Correlation-Id'] }
      response: { headers: ['Correlation-Id'] }
    }
  }
}

resource policy 'Microsoft.ApiManagement/service/policies@2024-05-01' = {
  parent: apim
  name: 'policy'
  dependsOn: [values, publishesActions]
  properties: {
    format: 'xml'
    value: globalPolicy
  }
}

resource apiProducts 'Microsoft.ApiManagement/service/products@2024-05-01' = [
  for p in products: {
    parent: apim
    name: p.name
    properties: {
      displayName: p.displayName
      description: p.description
      subscriptionRequired: p.subscriptionRequired
      approvalRequired: false
      state: 'published'
    }
  }
]

resource apiProductPolicies 'Microsoft.ApiManagement/service/products/policies@2024-05-01' = [
  for (p, i) in products: if (!empty(p.?policy ?? '')) {
    parent: apiProducts[i]
    name: 'policy'
    dependsOn: [values]
    properties: {
      format: 'xml'
      value: replace(
        p.?policy ?? '',
        '<!-- internal callers -->',
        join(map(internalCallerClientIds, id => '<application-id>${id}</application-id>'), '')
      )
    }
  }
]

resource healthApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'platform-health'
  properties: {
    displayName: '[Platform] Health API'
    path: 'platform'
    protocols: ['https']
    subscriptionRequired: true
    format: 'openapi'
    value: loadTextContent('../../openapi.yaml')
  }
}

resource healthApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: healthApi
  name: 'policy'
  properties: {
    format: 'xml'
    value: loadTextContent('../policies/health-api.xml')
  }
}

resource healthInProduct 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = {
  parent: apiProducts[0]
  name: healthApi.name
}

// Used by the pipeline's smoke and end-to-end tests, for every API on this gateway. Its key is read
// at deploy time and never stored.
resource smokeTest 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: 'smoke-test'
  properties: {
    displayName: 'Smoke test (platform pipeline)'
    scope: '${apim.id}/apis'
    state: 'active'
  }
}

output gatewayUrl string = apim.properties.gatewayUrl
output name string = apim.name
output principalId string = apim.identity.principalId
