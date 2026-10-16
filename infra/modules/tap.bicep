// The tap's storage, in rg-intplat-tap: never deleted by the kill switch (ADR 0011).
// - Queue tap-events: every CloudEvent from every topic, kept without expiry until the
//   Intelligence domain drains it (phase 2).
// - Container tap-deadletter: events Event Grid could not deliver to the tap (e.g. over 64 KB).
// - Container deadletters: events a consumer could not handle (ADR 0016), per topic and consumer.
// - Log Analytics data export writes the telemetry here too (containers am-<table>).
// Entra ID only. The topics deliver with their own managed identity.

param location string
param tags object

@description('Managed identities of the topics: they deliver to the queue and dead-letter to the container.')
param topicPrincipalIds array

@description('Identity of the platform pipeline: reads the queue length in the smoke test.')
param pipelinePrincipalId string

var queueSender = 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a' // Storage Queue Data Message Sender
var queueReader = '19e7f393-937e-4f77-808e-94535e297925' // Storage Queue Data Reader
var blobContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor

resource tap 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'sttapintplatdemo'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
  }
}

resource queues 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: tap
  name: 'default'
}

resource events 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = {
  parent: queues
  name: 'tap-events'
}

resource blobs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: tap
  name: 'default'
}

resource deadLetter 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobs
  name: 'tap-deadletter'
}

// Events a consumer could not handle after Event Grid's retries (ADR 0016): the Intelligence
// domain sees failed deliveries next to everything else.
resource consumerDeadLetters 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobs
  name: 'deadletters'
}

resource topicsSend 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in topicPrincipalIds: {
    name: guid(tap.id, principalId, queueSender)
    scope: tap
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', queueSender)
      description: 'Event Grid topic delivers every event to the tap queue.'
    }
  }
]

resource topicsDeadLetter 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in topicPrincipalIds: {
    name: guid(tap.id, principalId, blobContributor)
    scope: tap
    properties: {
      principalId: principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobContributor)
      description: 'Event Grid topic dead-letters undeliverable events to the tap.'
    }
  }
]

resource pipelineReads 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(tap.id, pipelinePrincipalId, queueReader)
  scope: tap
  properties: {
    principalId: pipelinePrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', queueReader)
    description: 'Platform pipeline: smoke test reads the tap queue length.'
  }
}

output storageId string = tap.id
output queueName string = events.name
output deadLetterContainer string = deadLetter.name
output consumerDeadLetterContainer string = consumerDeadLetters.name
