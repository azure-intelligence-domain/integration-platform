// The event intake (ADR 0016): how events reach the building blocks that receive them.
// For every consumer in routing/consumers.yaml whose backend exists: one Event Grid subscription per
// topic, filtered on its event types, pushing each event (CloudEvents, as the topic's managed
// identity) to the gateway's [Platform] Event Intake API, which forwards it to the backend. Failed
// deliveries are retried, then dead-lettered into the tap storage. Nothing polls: idle costs nothing.

param apimName string

@description('Entries of routing/consumers.yaml.')
param consumers array

@description('Backends that exist, by consumer name: { baseUrl, path } (resolved by the pipeline).')
param backends object

@description('Managed identities of the topics, by topic name (evgt-intplat-<topic>): the only callers of the intake.')
param topicPrincipalIds object

param tapStorageId string
param deadLetterContainer string
param platformApisAppId string

var routed = filter(consumers, c => contains(backends, c.name))
var subscriptions = flatten(map(routed, c => map(items(c.receives), r => {
  consumer: c.name
  topic: 'evgt-intplat-${r.key}'
  types: r.value
})))

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource routes 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'intake-backends'
  properties: {
    displayName: 'intake-backends'
    value: base64(string(backends))
  }
}

resource intakeApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'event-intake'
  properties: {
    path: 'intake'
    protocols: ['https']
    subscriptionRequired: false
    format: 'openapi'
    value: loadTextContent('../../intake.openapi.yaml')
  }
}

resource intakePolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: intakeApi
  name: 'policy'
  dependsOn: [routes]
  properties: {
    format: 'xml'
    value: replace(
      loadTextContent('../policies/event-intake.xml'),
      '<!-- topic identities -->',
      join(map(items(topicPrincipalIds), t => '<value>${t.value}</value>'), '')
    )
  }
}

resource topics 'Microsoft.EventGrid/topics@2025-02-15' existing = [for s in subscriptions: { name: s.topic }]

resource deliveries 'Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15' = [
  for (s, i) in subscriptions: {
    parent: topics[i]
    name: s.consumer
    dependsOn: [intakePolicy]
    properties: {
      eventDeliverySchema: 'CloudEventSchemaV1_0'
      filter: {
        includedEventTypes: s.types
      }
      deliveryWithResourceIdentity: {
        identity: { type: 'SystemAssigned' }
        destination: {
          endpointType: 'WebHook'
          properties: {
            endpointUrl: '${apim.properties.gatewayUrl}/intake/consumers/${s.consumer}/events'
            azureActiveDirectoryTenantId: tenant().tenantId
            azureActiveDirectoryApplicationIdOrUri: 'api://${platformApisAppId}'
            maxEventsPerBatch: 1
            preferredBatchSizeInKilobytes: 64
          }
        }
      }
      deadLetterWithResourceIdentity: {
        identity: { type: 'SystemAssigned' }
        deadLetterDestination: {
          endpointType: 'StorageBlob'
          properties: {
            resourceId: tapStorageId
            blobContainerName: deadLetterContainer
          }
        }
      }
      retryPolicy: {
        maxDeliveryAttempts: 3
        eventTimeToLiveInMinutes: 60
      }
    }
  }
]

output routed array = map(routed, c => c.name)
output subscriptions array = map(subscriptions, s => '${s.topic}/${s.consumer}')
