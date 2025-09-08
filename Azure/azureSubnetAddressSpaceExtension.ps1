$tenantID = "<your-tenant-id>"
Connect-AzAccount -tenant $tenantID

$rgName = "myResourceGroup1"
$location = "eastus"
$vnetName = "myVNet1"

# Create a resource group
New-AzResourceGroup -Name $rgName -Location $location
# Create a virtual network
$Vnet1AddressPrefix = "10.0.0.0/16"
$Subnet1AddressPrefix = "10.0.0.0/24"
$Subnet2AddressPrefix = "10.0.1.0/24"

$subnet1 = New-AzVirtualNetworkSubnetConfig -Name "mySubnet1" -AddressPrefix $Subnet1AddressPrefix
$subnet2 = New-AzVirtualNetworkSubnetConfig -Name "mySubnet2" -AddressPrefix $Subnet2AddressPrefix
$Network1 = New-AzVirtualNetwork -ResourceGroupName $rgName -Location $location -Name $vnetName -AddressPrefix $Vnet1AddressPrefix -Subnet $subnet1,$subnet2

# Create a second virtual network
$vnet2Name = "myVNet2"
$Vnet2AddressPrefix = "172.16.0.0/16"
$Subnet3AddressPrefix = "172.16.0.0/24"
$Subnet4AddressPrefix = "172.16.1.0/24"

$subnet3 = New-AzVirtualNetworkSubnetConfig -Name "mySubnet3" -AddressPrefix $Subnet3AddressPrefix
$subnet4 = New-AzVirtualNetworkSubnetConfig -Name "mySubnet4" -AddressPrefix $Subnet4AddressPrefix
$Network2 = New-AzVirtualNetwork -ResourceGroupName $rgName -Location $location -Name $vnet2Name -AddressPrefix $Vnet2AddressPrefix -Subnet $subnet3,$subnet4


$Peering12 = Add-AzVirtualNetworkPeering -Name "LinkVNet1ToVNet2" -VirtualNetwork $Network1 -RemoteVirtualNetworkId $Network2.Id -AllowForwardedTraffic -AllowGatewayTransit
$Peering21 = Add-AzVirtualNetworkPeering -Name "LinkVNet2ToVNet1" -VirtualNetwork $Network2 -RemoteVirtualNetworkId $Network1.Id -AllowForwardedTraffic


# Enable SCP for subnet1
Set-AzVirtualNetworkSubnetConfig -Name "mySubnet1" -VirtualNetwork $Network1 `
    -AddressPrefix $Subnet1AddressPrefix -ServiceEndpoint @('Microsoft.Storage','Microsoft.Sql')

$Network1 | Set-AzVirtualNetwork

# Enable SCP for subnet3
Set-AzVirtualNetworkSubnetConfig -Name "mySubnet3" -VirtualNetwork $Network2 `
    -AddressPrefix $Subnet3AddressPrefix -ServiceEndpoint @('Microsoft.Storage','Microsoft.Sql')

$Network2 | Set-AzVirtualNetwork

# Create test storage accounts with private endpoints in each vnet
$storageAccount1 = "mystorageacct1$(Get-Random -Maximum 10000)"
$storageAccount2 = "mystorageacct2$(Get-Random -Maximum 10000)"
$storageSku = "Standard_LRS"
$storage1 = New-AzStorageAccount -ResourceGroupName $rgName -Name $storageAccount1 -Location $location -SkuName $storageSku -Kind StorageV2
$storage2 = New-AzStorageAccount -ResourceGroupName $rgName -Name $storageAccount2 -Location $location -SkuName $storageSku -Kind StorageV2
$subnet1 = Get-AzVirtualNetworkSubnetConfig -Name "mySubnet1" -VirtualNetwork $Network1
$subnet3 = Get-AzVirtualNetworkSubnetConfig -Name "mySubnet3" -VirtualNetwork $Network2

$pec = @{
    Name = 'connection-1'
    PrivateLinkServiceId = $storage1.Id
    GroupID = 'blob'
}
$privateEndpointConnection1 = New-AzPrivateLinkServiceConnection @pec

$pec2 = @{
    Name = 'connection-2'
    PrivateLinkServiceId = $storage2.Id
    GroupID = 'blob'
}
$privateEndpointConnection2 = New-AzPrivateLinkServiceConnection @pec2



$pe1 = New-AzPrivateEndpoint -ResourceGroupName $rgName -Name "pe1" -Location $location -Subnet $subnet1 -PrivateLinkServiceConnection $privateEndpointConnection1
$pe2 = New-AzPrivateEndpoint -ResourceGroupName $rgName -Name "pe2" -Location $location -Subnet $subnet3 -PrivateLinkServiceConnection $privateEndpointConnection2


# Extending address space for subnet1 and subnet3
Set-AzVirtualNetworkSubnetConfig -Name "mySubnet1" -VirtualNetwork $Network1 -AddressPrefix '10.0.0.0/24', '10.0.2.0/24'
$Network1 | Set-AzVirtualNetwork
Set-AzVirtualNetworkSubnetConfig -Name "mySubnet3" -VirtualNetwork $Network2 -AddressPrefix '172.16.0.0/24', '172.16.2.0/24'
$Network2 | Set-AzVirtualNetwork