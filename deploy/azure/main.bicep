@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Container Apps environment name')
param environmentName string = 'cfd-tiles-env'

@description('Frontend Container App name')
param frontendAppName string = 'cfd-tiles-frontend'

@description('Backend Container App name')
param backendAppName string = 'cfd-tiles-backend'

@description('Expose frontend publicly')
param publicAccess bool = false

@description('Frontend image (prebuilt)')
param frontendImage string = 'ghcr.io/cfd/tiles-frontend:latest'

@description('Backend image (prebuilt)')
param backendImage string = 'ghcr.io/cfd/tiles-backend:latest'

@description('Demo mode (mock data only)')
param demoMode bool = false

@description('Entra tenant ID')
param azureTenantId string

@description('Entra client ID')
param azureClientId string

@secure()
@description('Entra client secret')
param azureClientSecret string

@secure()
@description('Azure Storage connection string')
param azureStorageConnectionString string

@description('Azure subscription ID (optional)')
param azureSubscriptionId string = ''

@description('Auth tenant ID (optional)')
param authTenantId string = ''

@description('Auth audience (optional)')
param authAudience string = ''

@description('Optional GHCR username for private image pulls')
param ghcrUsername string = ''

@secure()
@description('Optional GHCR token/PAT for private image pulls')
param ghcrPassword string = ''

var backendImageLower = toLower(backendImage)
var frontendImageLower = toLower(frontendImage)
var backendUsesGhcr = contains(backendImageLower, 'ghcr.io/')
var frontendUsesGhcr = contains(frontendImageLower, 'ghcr.io/')
var useGhcrAuth = !empty(ghcrUsername) && !empty(ghcrPassword)

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${environmentName}-logs'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource env 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspace.properties.customerId
        sharedKey: logWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource backendApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: backendAppName
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: union({
      ingress: {
        external: false
        targetPort: 3001
        transport: 'auto'
      }
    }, (backendUsesGhcr && useGhcrAuth) ? {
      secrets: [
        {
          name: 'ghcr-password'
          value: ghcrPassword
        }
      ]
      registries: [
        {
          server: 'ghcr.io'
          username: ghcrUsername
          passwordSecretRef: 'ghcr-password'
        }
      ]
    } : {})
    template: {
      containers: [
        {
          name: 'backend'
          image: backendImage
          env: [
            { name: 'AZURE_TENANT_ID', value: azureTenantId }
            { name: 'AZURE_CLIENT_ID', value: azureClientId }
            { name: 'AZURE_CLIENT_SECRET', value: azureClientSecret }
            { name: 'AZURE_STORAGE_CONNECTION_STRING', value: azureStorageConnectionString }
            { name: 'AZURE_SUBSCRIPTION_ID', value: azureSubscriptionId }
            { name: 'AUTH_TENANT_ID', value: authTenantId }
            { name: 'AUTH_AUDIENCE', value: authAudience }
            { name: 'NODE_ENV', value: 'production' }
            { name: 'PORT', value: '3001' }
            { name: 'DEMO_MODE', value: demoMode ? 'true' : 'false' }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

resource frontendApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: frontendAppName
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: union({
      ingress: {
        external: publicAccess
        targetPort: 80
        transport: 'auto'
      }
    }, (frontendUsesGhcr && useGhcrAuth) ? {
      secrets: [
        {
          name: 'ghcr-password'
          value: ghcrPassword
        }
      ]
      registries: [
        {
          server: 'ghcr.io'
          username: ghcrUsername
          passwordSecretRef: 'ghcr-password'
        }
      ]
    } : {})
    template: {
      containers: [
        {
          name: 'frontend'
          image: frontendImage
          env: [
            { name: 'BACKEND_URL', value: 'https://${backendApp.properties.configuration.ingress.fqdn}' }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

output frontendFqdn string = frontendApp.properties.configuration.ingress.fqdn
output backendFqdn string = backendApp.properties.configuration.ingress.fqdn
