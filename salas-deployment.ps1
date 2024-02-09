$CustomerShortName = 'salas'
$Location = 'usgovvirginia'
$LocationShortName = 'uv'
$SharedResourceGroupName = ('rg-shd-{0}-1' -f $LocationShortName)
$FirewallSubnetAddressSpace = '10.201.0.192/26'
$BastionSubnetAddressSpace = '10.201.0.128/26'
$SharedSubnetAddressSpaces = @('10.201.0.0/26', '10.201.0.64/26')
$SharedVnetAddressSpace = '10.201.0.0/24'
$CustomerResourceGroupName = ('rg-{0}-{1}-1' -f $CustomerShortName, $LocationShortName)
$CustomerSubnetAddressSpaces = @('10.201.1.0/25','10.201.1.128/25','10.201.2.0/25','10.201.2.128/25')
$CustomerVnetAddressSpaces = @('10.201.1.0/24','10.201.2.0/24')

Connect-AzAccount -Environment AzureUSGovernment

# Shared
New-AzResourceGroup -Name $SharedResourceGroupName -Location $Location

$ParameterObject = @{
    firewallSubnetAddressSpace = $FirewallSubnetAddressSpace
    bastionSubnetAddressSpace = $BastionSubnetAddressSpace
    locationShortName = $LocationShortName
    subnetAddressSpaces = $SharedSubnetAddressSpaces
    vnetAddressSpace = $SharedVnetAddressSpace
}
$DeploymentParams = @{
    Name = 'shared-vnet-fw-bst' 
    ResourceGroupName = $SharedResourceGroupName 
    TemplateFile = 'C:\Scripts\GitHub\Azure-PS-Resource-Manager\microsoft.network\shared-vnet-fw-bas\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
    
}
New-AzResourceGroupDeployment @DeploymentParams

Start-Sleep -Seconds 600

# Customer 
New-AzResourceGroup -Name $CustomerResourceGroupName -Location $Location

$ParameterObject = @{
    customerShortName = $CustomerShortName
    locationShortName = $LocationShortName
    sharedResourceGroupName = $SharedResourceGroupName
    sharedRouteTableName = (Get-AzRouteTable -ResourceGroupName $SharedResourceGroupName).Name
    sharedVnetName = (Get-AzVirtualNetwork -ResourceGroupName $SharedResourceGroupName).Name
    sharedVnetAddressSpace = $SharedVnetAddressSpace
    subnetAddressSpaces = $CustomerSubnetAddressSpaces
    vnetAddressSpaces = $CustomerVnetAddressSpaces
}
$DeploymentParams = @{
    Name = ('{0}-vnet-peer' -f $CustomerShortName) 
    ResourceGroupName = $CustomerResourceGroupName
    TemplateFile = 'C:\Scripts\GitHub\Azure-PS-Resource-Manager\microsoft.network\customer-vnet\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams