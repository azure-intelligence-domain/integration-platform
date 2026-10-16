// Monitoring: one Log Analytics workspace with a daily ingestion cap, and Application Insights
// on top of it. Every building block sends its telemetry here: one trace per journey.

param location string
param tags object

@description('Daily ingestion cap in GB. 0.15 GB/day stays within the free 5 GB per month (ADR 0003).')
param dailyCapGb string = '0.15'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-intplat-demo'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json(dailyCapGb)
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-intplat-demo'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
