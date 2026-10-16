// Messaging: one Event Grid topic per business domain plus the platform topic (gateway actions,
// agent actions, deployments), all CloudEvents 1.0, and one Service Bus namespace (Basic) for the
// subscriber queues. Entra ID only: no keys or connection strings anywhere.
// The names match the shared landscape in the contracts repository.

param location string
param tags object
param topicNames array
param workspaceId string

resource topics 'Microsoft.EventGrid/topics@2025-02-15' = [
  for name in topicNames: {
    name: 'evgt-intplat-${name}'
    location: location
    tags: union(tags, { domain: name })
    // The topic's own identity delivers to the tap, so the tap needs no keys either.
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      inputSchema: 'CloudEventSchemaV1_0'
      disableLocalAuth: true
      publicNetworkAccess: 'Enabled'
    }
  }
]

// Resource-specific tables (Dedicated): AzureDiagnostics cannot be exported to the tap.
resource topicDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [
  for (name, i) in topicNames: {
    name: 'to-log-analytics'
    scope: topics[i]
    properties: {
      workspaceId: workspaceId
      logAnalyticsDestinationType: 'Dedicated'
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
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

output topics array = [
  for (name, i) in topicNames: {
    name: topics[i].name
    endpoint: topics[i].properties.endpoint
    principalId: topics[i].identity.principalId
  }
]
output serviceBusName string = serviceBus.name
