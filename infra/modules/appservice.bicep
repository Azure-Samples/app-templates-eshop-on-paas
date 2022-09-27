param webAppName string
param location string = resourceGroup().location // Location for all resources
param serverFarmId string
param appInsightsName string
param registryName string
param imageName string
param apimName string
param vueConfig bool = false

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: appInsightsName
}

resource registry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: registryName
}

resource apimResource 'Microsoft.ApiManagement/service@2020-12-01' existing = {
  name: apimName
}

resource appService 'Microsoft.Web/sites@2020-06-01' = {
  name: webAppName
  location: location
  kind: 'linux,container'
  properties: {
    serverFarmId: serverFarmId
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: registry.properties.loginServer
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: registry.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: registry.listCredentials().passwords[0].value
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
      ]
      linuxFxVersion: 'DOCKER|${registry.properties.loginServer}/${imageName}:latest'
      minTlsVersion: '1.2'
    }
  }
}

resource appServiceLogging 'Microsoft.Web/sites/config@2020-06-01' = {
  parent: appService
  name: 'logs'
  properties: {
    applicationLogs: {
      fileSystem: {
        level: 'Warning'
      }
    }
    httpLogs: {
      fileSystem: {
        retentionInMb: 40
        enabled: true
      }
    }
    failedRequestsTracing: {
      enabled: true
    }
    detailedErrorMessages: {
      enabled: true
    }
  }
}

resource appServiceAppSettings 'Microsoft.Web/sites/config@2020-06-01' = if (vueConfig) {
  parent: appService
  name: 'appsettings'
  properties: {
    VUE_APP_MAKELINE_BASE_URL: '${apimResource.properties.gatewayUrl}/makeline/'
    VUE_APP_ACCOUNTING_BASE_URL: '${apimResource.properties.gatewayUrl}/accounting/'
  }
  dependsOn: [
    apimResource
  ]
}

output defaultHostName string = appService.properties.defaultHostName
