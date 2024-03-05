$CustomerShortName = 'nc'
$Location = 'eastus2'
$LocationShortName = 'eu2'
$SharedResourceGroupName = ('rg-shd-{0}-1' -f $LocationShortName)
$FirewallSubnetAddressSpace = '10.1.0.192/26'
$BastionSubnetAddressSpace = '10.1.0.128/26'
$SharedSubnetAddressSpaces = @('10.1.0.0/26', '10.1.0.64/26')
$SharedVnetAddressSpace = '10.1.0.0/24'
$CustomerResourceGroupName = ('rg-{0}-{1}-1' -f $CustomerShortName, $LocationShortName)
$CustomerSubnetAddressSpaces = @('10.1.1.0/25','10.1.1.128/25','10.1.2.0/25','10.1.2.128/25')
$CustomerVnetAddressSpaces = @('10.1.1.0/24','10.1.2.0/24')

Connect-AzAccount

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


$ParameterObject = @{
    hostpoolName = "avd-hpl-admin-eu2-1"
    hostpoolDescription = "Created through the Azure Virtual Desktop extension"
    hostpoolDiagnosticSettingsLogAnalyticsWorkspaceName = 'log-nc-avd-eu1-1'
    location = $Location
    workSpaceName = 'avd-wks-eu2-1'
    workspaceLocation = $Location
    workspaceResourceGroup = $SharedResourceGroupName
    isNewWorkspace = $true
    addToWorkspace = $true
    vmAdministratorAccountUsername = 'vmadmin'
    vmAdministratorAccountPassword = 'ALP!q$L?Hqoz&c5M' #(ConvertTo-SecureString -String 'ALP!q$L?Hqoz&c5M' -AsPlainText -Force)
    vmResourceGroup = $SharedResourceGroupName
    vmLocation = $Location
    vmSize = 'Standard_D2s_v3' #The size of the session host VMs in GB. If the value of this parameter is 0, the disk will be created with the default size set in the image.
    vmDiskSizeGB = 0
    vmHibernate = $false
    vmNumberOfInstances = 1
    vmNamePrefix = 'avd-vm-admin'
    vmImageType = 'Gallery'
    vmGalleryImageOffer = 'windows-11'
    vmGalleryImagePublisher = 'microsoftwindowsdesktop'
    vmGalleryImageSKU = 'win11-22h2-ent'
    vmDiskType = 'Premium_LRS'
    existingVnetName = 'vnet-shd-eu2-1'
    existingSubnetName = 'snet-shd-eu2-1'
    virtualNetworkResourceGroupName = $SharedResourceGroupName
    hostpoolType = 'Personal'
    personalDesktopAssignmentType = 'Automatic'
    loadBalancerType = 'Persistent'
    customRdpProperty = 'enablerdsaadauth:i:1;enablecredsspsupport:i:1;videoplaybackmode:i:1;audiocapturemode:i:1;audiomode:i:0;camerastoredirect:s:*;devicestoredirect:s:;drivestoredirect:s:*;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:0;redirectwebauthn:i:1;usbdevicestoredirect:s:*;use multimon:i:1;dynamic resolution:i:1'
    <#vmTemplate = @{
        domain = ''
        galleryImageOffer = 'windows-11'
        galleryImagePublisher = 'microsoftwindowsdesktop'
        galleryImageSKU = 'win11-22h2-ent'
        imageType = 'Gallery'
        customImageId = $null
        namePrefix = 'avd-vm-admin'
        osDiskType = 'Premium_LRS'
        vmSize = @{
            id = 'Standard_D2s_v3'
            cores = 2
            ram = 8
        }
        galleryItemId = 'microsoftwindowsdesktop.windows-11win11-22h2-ent'
        hibernate = $false
        diskSizeGB = 0
        securityType = 'TrustedLaunch'
        secureBoot = $true
        vTPM = $true
    }#>
    vmTemplate = '{"domain":"","galleryImageOffer":"windows-11","galleryImagePublisher":"microsoftwindowsdesktop","galleryImageSKU":"win11-22h2-ent","imageType":"Gallery","customImageId":null,"namePrefix":"avd-vm-admin","osDiskType":"Premium_LRS","vmSize":{"id":"Standard_D2s_v3","cores":2,"ram":8},"galleryItemId":"microsoftwindowsdesktop.windows-11win11-22h2-ent","hibernate":false,"diskSizeGB":0,"securityType":"TrustedLaunch","secureBoot":true,"vTPM":true}'
    tokenExpirationTime = (Get-Date).AddDays(25) #2023-08-11T22:52:39.825Z"
    hostpoolTags = @{environment = 'admin'}
    applicationGroupTags = @{environment = 'admin'}
    availabilitySetTags = @{environment = 'admin'}
    networkInterfaceTags = @{environment = 'admin'}
    networkSecurityGroupTags = @{environment = 'admin'}
    virtualMachineTags = @{environment = 'admin'}
    apiVersion = '2022-10-14-preview'
    deploymentId = 'admin-avd-hostpool'
    aadJoin = $true
    intune = $true
    bootDiagnostics = @{enabled = $true}
    systemData = @{
        aadJoinPreview = $false
        firstPartyExtension = $false
    }
    securityType = 'TrustedLaunch'
    secureBoot = $true
    vTPM = $true
}
$DeploymentParams = @{
    Name ='admin-avd-hostpool'
    ResourceGroupName = $SharedResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\azure-virtual-desktop\host-pool\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams




$AppRule1 = New-AzFirewallApplicationRule -Name Allow-Google -SourceAddress 10.0.2.0/24 -Protocol http, https -TargetFqdn www.google.com

$AppRuleCollection = New-AzFirewallApplicationRuleCollection -Name App-Coll01 -Priority 200 -ActionType Allow -Rule $AppRule1

$Azfw.ApplicationRuleCollections.Add($AppRuleCollection)

Set-AzFirewall -AzureFirewall $Azfw