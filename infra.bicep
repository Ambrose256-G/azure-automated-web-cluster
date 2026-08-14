param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminSshKey string

var vnetName = 'lab-vnet'
var subnetName = 'lab-subnet'
var lbName = 'lab-load-balancer'
var vmNames = [ 'web-vm-1', 'web-vm-2' ]

// Network Security Group allowing HTTP and SSH
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'lab-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1001
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// Load Balancer Public IP
resource lbPublicIP 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'lb-public-ip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// Load Balancer
resource loadBalancer 'Microsoft.Network/loadBalancers@2023-11-01' = {
  name: lbName
  location: location
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'lb-frontend'
        properties: { publicIPAddress: { id: lbPublicIP.id } }
      }
    ]
    backendAddressPools: [ { name: 'lb-backend-pool' } ]
    probes: [
      {
        name: 'http-probe'
        properties: { protocol: 'Http', port: 80, requestPath: '/' }
      }
    ]
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'lb-frontend') }
          backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'lb-backend-pool') }
          probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'http-probe') }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
        }
      }
    ]
  }
}

// Public IPs for individual VMs (Required for GitHub runner to access via Ansible SSH)
resource vmPublicIPs 'Microsoft.Network/publicIPAddresses@2023-11-01' = [for name in vmNames: {
  name: '${name}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}]

// Network Interfaces attaching VMs to the Subnet and the Load Balancer Pool
resource nics 'Microsoft.Network/networkInterfaces@2023-11-01' = [for (name, i) in vmNames: {
  name: '${name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: { id: vmPublicIPs[i].id }
          subnet: { id: vnet.properties.subnets[0].id }
          loadBalancerBackendAddressPools: [
            { id: loadBalancer.properties.backendAddressPools[0].id }
          ]
        }
      }
    ]
  }
}]

// Virtual Machines
resource vms 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (name, i) in vmNames: {
  name: name
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v7' }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            { path: '/home/${adminUsername}/.ssh/authorized_keys', keyData: adminSshKey }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    networkProfile: { networkInterfaces: [ { id: nics[i].id } ] }
  }
  tags: { role: 'web' }
}]
