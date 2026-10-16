// Wiring into the tap (platform side): a "tap" subscription on every topic for all event types,
// and continuous export of the telemetry tables. Created by the platform, so no producer can
// forget it or opt out: subscribe by default (ADR 0011).

param topicNames array
param tapStorageId string
param tapQueueName string
param tapDeadLetterContainer string
param workspaceName string

@description('Telemetry tables exported to the tap. AzureDiagnostics cannot be exported, so platform logs use resource-specific tables.')
param telemetryTables array = [
  'AppRequests'
  'AppDependencies'
  'AppExceptions'
  'AppTraces'
  'AegDeliveryFailureLogs'
  'AegPublishFailureLogs'
  'AZMSOperationalLogs'
]

resource topics 'Microsoft.EventGrid/topics@2025-02-15' existing = [for name in topicNames: { name: name }]

resource tapSubscriptions 'Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15' = [
  for (name, i) in topicNames: {
    parent: topics[i]
    name: 'tap'
    properties: {
      eventDeliverySchema: 'CloudEventSchemaV1_0'
      deliveryWithResourceIdentity: {
        identity: {
          type: 'SystemAssigned'
        }
        destination: {
          endpointType: 'StorageQueue'
          properties: {
            resourceId: tapStorageId
            queueName: tapQueueName
            queueMessageTimeToLiveInSeconds: -1 // kept until the Intelligence domain drains it
          }
        }
      }
      deadLetterWithResourceIdentity: {
        identity: {
          type: 'SystemAssigned'
        }
        deadLetterDestination: {
          endpointType: 'StorageBlob'
          properties: {
            resourceId: tapStorageId
            blobContainerName: tapDeadLetterContainer
          }
        }
      }
      retryPolicy: {
        maxDeliveryAttempts: 30
        eventTimeToLiveInMinutes: 1440
      }
    }
  }
]

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workspaceName
}

resource telemetryExport 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  parent: workspace
  name: 'tap-telemetry'
  properties: {
    destination: {
      resourceId: tapStorageId
    }
    tableNames: telemetryTables
    enable: true
  }
}
