#This script will deploy a windows server 2025 azure VM. From there we will set up hyper-V and add two nested VMs, in order to setup a cyber security lab.

# Variables
$rgName = "az-cyberlab-rg"
$location = "eastus2"
$vnetName = "az-cyberlab-vnet"
$subnetName = "az-cyberlab-subnet"
$vmName = "az-cyberlab-vm"

#Stop script if an error occurs
$ErrorActionPreference = "Stop"

# Determine the public IP of the machine running the script
Write-Host "Fetching current public IP..."
$myIP = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
$sourcePrefix = "$myIP/32"
Write-Host "Current public IP detected: $sourcePrefix"

#Write-Host "Allowing RDP from: $sourcePrefix"

# connect to Azure
Write-Host "Connecting to Azure.."
Connect-AzAccount

# Resource Group
Write-Host "Provisioning Resource Group '$rgName'..."
New-AzResourceGroup `
    -Name $rgName `
    -Location $location

Write-Host "Resource Group '$rgName' deployed."

# VNet + Subnet
$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix "10.0.0.0/24"

Write-Host "Provisioning Virtual Network '$vnetName' with Subnet '$subnetName'..."
$vnet = New-AzVirtualNetwork `
    -ResourceGroupName $rgName `
    -Location $location `
    -Name $vnetName `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnet

Write-Host "Virtual Network '$vnetName' with Subnet '$subnetName' deployed."

# NSG Rule - Allow RDP only from current public IP
$rdpRule = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP" `
    -Description "Allow RDP from current public IP" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 100 `
    -SourceAddressPrefix $sourcePrefix `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange "3389"

# NSG
Write-Host "Provisioning Network Security Group '$vmName-nsg'..."
$nsg = New-AzNetworkSecurityGroup `
    -Name "$vmName-nsg" `
    -ResourceGroupName $rgName `
    -Location $location `
    -SecurityRules $rdpRule
Write-Host "Network Security Group '$vmName-nsg' deployed."

# Public IP
$publicIP = New-AzPublicIpAddress `
    -Name "$vmName-pip" `
    -ResourceGroupName $rgName `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard

# NIC
$nic = New-AzNetworkInterface `
    -Name "$vmName-nic" `
    -ResourceGroupName $rgName `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -PublicIpAddressId $publicIP.Id `
    -NetworkSecurityGroupId $nsg.Id

# Credentials
$cred = Get-Credential

# VM Configuration
$vm = New-AzVMConfig `
    -VMName $vmName `
    -VMSize "Standard_E4s_v7"

$vm = Set-AzVMOperatingSystem `
    -VM $vm `
    -Windows `
    -ComputerName $vmName `
    -Credential $cred

$vm = Set-AzVMSourceImage `
    -VM $vm `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-g2" `
    -Version "latest"

$vm = Set-AzVMOSDisk `
    -VM $vm `
    -CreateOption FromImage `
    -DiskSizeInGB 256
    
$vm = Add-AzVMNetworkInterface `
    -VM $vm `
    -Id $nic.Id

# Create VM
Write-Host "Provisioning VM '$vmName'..."
New-AzVM `
    -ResourceGroupName $rgName `
    -Location $location `
    -VM $vm

# Display Public IP
$publicIP = Get-AzPublicIpAddress `
    -ResourceGroupName $rgName `
    -Name "$vmName-pip"



Write-Host ""
Write-Host "VM deployment complete."
Write-Host "Public IP Address: $($publicIP.IpAddress)"
Write-Host "RDP Access Allowed From: $sourcePrefix"

Disconnect-AzAccount # Disconnect from Azure

#RDP to VM and run the below code:
#Set-ExecutionPolicy Bypass -Force
#Invoke-WebRequest 'https://aka.ms/azlabs/scripts/hyperV-powershell' -Outfile SetupForNestedVirtualization.ps1
#.\SetupForNestedVirtualization.ps1



## Once done with the lab, delete the resources created for this lab by running the commands below. Reconnecting to Azure, and then deleting the resource group.
#Connnect-AzAccount
#Remove-AzResourceGroup -Name 'az-cyberlab-rg' -Force
#Disconnect-AzAccount
