
@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Virtual network name')
param vnetName string = 'vnet-iac-lab'

resource appNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-iac-app'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-app'
        properties: {
          addressPrefix: '10.10.1.0/24'
          networkSecurityGroup: {
            id: appNsg.id
          }
        }
      }
      {
        name: 'subnet-data'
        properties: {
          addressPrefix: '10.10.2.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output nsgId string = appNsg.id
