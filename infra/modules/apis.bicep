// The APIs one gateway serves, from routing/apis.yaml (ADR 0014): each imported from the openapi.yaml
// of its repository's release, published in its product, and calling its backend with the gateway's
// managed identity (policies/backend-api.xml).

param apimName string

@description('Which gateway this is, as keyed in routing/apis.yaml: people or agents.')
param gateway string

@description('Entries of routing/apis.yaml.')
param apis array

@description('Products on this gateway without a subscription key: their policy decides who gets in.')
param keylessProducts array = []

var mine = filter(apis, a => contains(a.gateways, gateway))

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = [
  for a in mine: {
    parent: apim
    name: a.name
    properties: {
      path: a.path
      protocols: ['https']
      subscriptionRequired: !contains(keylessProducts, a.gateways[gateway])
      format: 'openapi-link'
      value: 'https://raw.githubusercontent.com/azure-intelligence-domain/${a.repository}/${a.release}/openapi.yaml'
      serviceUrl: 'https://${a.backend}.azurewebsites.net'
    }
  }
]

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = [
  for (a, i) in mine: {
    parent: api[i]
    name: 'policy'
    properties: {
      format: 'xml'
      value: replace(loadTextContent('../policies/backend-api.xml'), '__BACKEND__', 'https://${a.backend}.azurewebsites.net')
    }
  }
]

resource product 'Microsoft.ApiManagement/service/products@2024-05-01' existing = [
  for a in mine: {
    parent: apim
    name: a.gateways[gateway]
  }
]

resource inProduct 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = [
  for (a, i) in mine: {
    parent: product[i]
    name: a.name
    dependsOn: [api]
  }
]
