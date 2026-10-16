// API Management (Consumption): the one gateway for every API on the platform.
// Every call is traced to Application Insights (W3C), and the global policy enforces the
// Correlation-Id header for every API.

param location string
param tags object
param publisherEmail string
param appInsightsName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: 'apim-intplat-demo'
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

resource globalPolicy 'Microsoft.ApiManagement/service/policies@2024-05-01' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../policies/global.xml')
  }
}

resource platformProduct 'Microsoft.ApiManagement/service/products@2024-05-01' = {
  parent: apim
  name: 'platform'
  properties: {
    displayName: 'Platform'
    description: 'APIs of the integration platform itself.'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

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
    format: 'rawxml'
    value: loadTextContent('../policies/health-api.xml')
  }
}

resource healthInProduct 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = {
  parent: platformProduct
  name: healthApi.name
}

// Used by the pipeline's smoke test. Its key is read at deploy time and never stored.
resource smokeTest 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: 'smoke-test'
  properties: {
    displayName: 'Smoke test (platform pipeline)'
    scope: platformProduct.id
    state: 'active'
  }
}

output gatewayUrl string = apim.properties.gatewayUrl
output name string = apim.name
