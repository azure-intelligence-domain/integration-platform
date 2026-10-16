// The shared foundation of the integration platform (ADR 0010), in rg-intplat-platform.
// Deployed by this repository's own identity, which only has rights on that resource group.

@description('Region of everything except API Management.')
param location string = 'belgiumcentral'

@description('API Management Consumption is not offered in Belgium Central; France Central is the fallback (ADR 0003).')
param apiManagementLocation string = 'francecentral'

@description('Receives API Management notifications. Passed at deploy time, never committed.')
param publisherEmail string

@description('One Event Grid topic per business domain.')
param domains array = ['sales', 'finance', 'supply', 'logistics']

var tags = {
  project: 'ai-intelligence-domain'
  component: 'integration-platform'
  owner: 'platform-team'
}

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
    domains: domains
    workspaceId: monitoring.outputs.workspaceId
  }
}

module apiManagement 'modules/api-management.bicep' = {
  name: 'api-management'
  params: {
    location: apiManagementLocation
    tags: tags
    publisherEmail: publisherEmail
    appInsightsName: monitoring.outputs.appInsightsName
  }
}

output gatewayUrl string = apiManagement.outputs.gatewayUrl
output apiManagementName string = apiManagement.outputs.name
output workspaceCustomerId string = monitoring.outputs.workspaceCustomerId
output topicEndpoints array = messaging.outputs.topicEndpoints
output serviceBusName string = messaging.outputs.serviceBusName
