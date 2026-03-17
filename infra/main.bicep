// =============================================================
// main.bicep – Azure VM deployment template
// =============================================================

@description('Name of the virtual machine.')
param vmName string = 'vm-actions-demo'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Admin username for the VM OS.')
param adminUsername string

@description('Admin password for the VM OS.')
@secure()
param adminPassword string

@description('Azure VM SKU.')
@allowed([
  'Standard_B1s'
  'Standard_B2s'
  'Standard_D2s_v3'
  'Standard_D4s_v3'
])
param vmSize string = 'Standard_B2s'

@description('OS managed-disk storage type.')
@allowed([
  'Standard_LRS'
  'Premium_LRS'
])
param osDiskType string = 'Premium_LRS'

// ── Derived names ────────────────────────────────────────────
var vnetName  = '${vmName}-vnet'
var subnetName = '${vmName}-subnet'
var pipName   = '${vmName}-pip'
var nicName   = '${vmName}-nic'
var nsgName   = '${vmName}-nsg'
var addressPrefix       = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

// ── Network Security Group ───────────────────────────────────
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow inbound SSH traffic'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 1100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          description: 'Allow inbound HTTP traffic'
        }
      }
      {
        name: 'Allow-HTTPS'
        properties: {
          priority: 1200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow inbound HTTPS traffic'
        }
      }
    ]
  }
}

// ── Virtual Network ──────────────────────────────────────────
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// ── Public IP ────────────────────────────────────────────────
resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: pipName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower(vmName)
    }
  }
}

// ── Network Interface ─────────────────────────────────────────
resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: pip.id }
        }
      }
    ]
    networkSecurityGroup: { id: nsg.id }
  }
}

// ── Virtual Machine ───────────────────────────────────────────
resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: 'Delete'
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: { deleteOption: 'Delete' }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────
@description('Public IP address of the deployed VM.')
output publicIPAddress string = pip.properties.ipAddress

@description('Fully qualified domain name of the VM.')
output fqdn string = pip.properties.dnsSettings.fqdn

@description('Resource ID of the virtual machine.')
output vmResourceId string = vm.id
