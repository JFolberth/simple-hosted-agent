using './main.bicep'

param environmentName = 'simple-hosted-agent3'
param resourceGroupName = 'rg-simple-hosted-agent3-dev'
param location = 'swedencentral'
param aiDeploymentsLocation = 'swedencentral'
param aiFoundryProjectName = 'ai-project3'
param deployments = [
  {
    name: 'gpt-4.1-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
    sku: {
      name: 'Standard'
      capacity: 10
    }
  }
]
