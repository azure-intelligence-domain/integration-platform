// Messaging: one Event Grid topic per domain (CloudEvents 1.0) and one Service Bus namespace
// (Basic) for the subscriber queues. Entra ID only: no keys or connection strings anywhere.
// The names match the shared landscape in the contracts repository.

param location string
param tags object
param domains array
param workspaceId string

resource topics 'Microsoft.EventGrid/topics@2025-02-15' = [
  for domain in domains: {
    name: 'evgt-intplat-${domain}'
    location: location
    tags: union(tags, { domain: domain })
    properties: {
      inputSchema: 'CloudEventSchemaV1_0'
      disableLocalAuth: true
      publicNetworkAccess: 'Enabled'
    }
  }
]

resource topicDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [
  for (domain, i) in domains: {
    name: 'to-log-analytics'
    scope: topics[i]
    properties: {
      workspaceId: workspaceId
      logs: [
        {
          categoryGroup: 'allLogs'
          enabled: true
        }
      ]
    }
  }
]

resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'sbns-intplat-demo'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    disableLocalAuth: true
    minimumTlsVersion: '1.2'
  }
}

resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-log-analytics'
  scope: serviceBus
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

output topicEndpoints array = [for (domain, i) in domains: { domain: domain, endpoint: topics[i].properties.endpoint }]
output serviceBusName string = serviceBus.name
