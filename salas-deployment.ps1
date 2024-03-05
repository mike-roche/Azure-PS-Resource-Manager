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

# Configure roles and access to facilitate AVD management and access
# First add the "Desktop Virtualization Power On Off Contributor" role to the resource group allowing the automatic startup and shutdown of AVDs
$parameters = @{
    RoleDefinitionName = 'Desktop Virtualization Power On Off Contributor'
    ApplicationId = "9cdead84-a844-4324-93f2-b2e6bb768d07"
    #Scope = ("/subscriptions/{0}" -f (Get-AzSubscription).Id)
    #Scope = ('/subscriptions/{0}/resourceGroups/{1}'-f (Get-AzSubscription).Id, $SharedResourceGroupName)
    ResourceGroupName = $SharedResourceGroupName
}
New-AzRoleAssignment @parameters

# Create group for all AVD users and assign the 'Virtual Machine User Login' role to the group
$parameters = @{
    DisplayName = 'Virtual Machine User Login'
    MailEnabled = $False 
    MailNickName = (New-Guid).ToString().Substring(0,10)
    SecurityEnabled = $true
    Description = 'Members of this group will be assigned the Virtual Machine User Login role. This role enables authentication to Azure AD joined VMs'
    MembershipRule = "(user.companyName -eq `"Network Coverage`") or (user.companyName -eq `"Salas O'Brien`")"
    MembershipRuleProcessingState = 'On'
    GroupTypes = 'DynamicMembership'
}
$Group = New-MgGroup @parameters

Start-Sleep -Seconds 180 # give time for azure to propaget the new group

$parameters = @{
    ObjectId = $Group.Id
    RoleDefinitionName = 'Virtual Machine User Login'
    ResourceGroupName = $SharedResourceGroupName
}
New-AzRoleAssignment @parameters #https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell

# Deploy admin AVD pool
$DeploymentName = 'admin-avd-hostpool-1'
$ParameterObject = @{
    hostpoolName = ('avd-hp-admin-{0}-1' -f $LocationShortName)
    hostpoolDescription = 'AVD pool for administrtive use only'
    hostpoolDiagnosticSettingsLogAnalyticsWorkspaceName = ('log-shd-{0}-2' -f $LocationShortName)
    location = $Location
    workSpaceName = ('avd-ws-{0}-1' -f $LocationShortName)
    workspaceLocation = $Location
    workspaceResourceGroup = $SharedResourceGroupName
    isNewWorkspace = $true
    addToWorkspace = $true
    vmAdministratorAccountUsername = 'vmadmin'
    vmAdministratorAccountPassword = 'ALP!q$L?Hqoz&c5M'
    vmResourceGroup = $SharedResourceGroupName
    vmLocation = $Location
    vmSize = 'Standard_D2s_v3'
    vmDiskSizeGB = 0
    vmHibernate = $false
    vmNumberOfInstances = 1
    vmNamePrefix = 'avd-admin'
    vmImageType = 'Gallery'
    vmGalleryImageOffer = 'windows-11'
    vmGalleryImagePublisher = 'microsoftwindowsdesktop'
    vmGalleryImageSKU = 'win11-22h2-ent'
    vmDiskType = 'Premium_LRS'
    existingVnetName = ('vnet-shd-{0}-1' -f $LocationShortName)
    existingSubnetName = ('snet-shd-{0}-1' -f $LocationShortName)
    virtualNetworkResourceGroupName = $SharedResourceGroupName
    hostpoolType = 'Personal'
    personalDesktopAssignmentType = 'Automatic'
    loadBalancerType = 'Persistent'
    customRdpProperty = 'enablerdsaadauth:i:1;enablecredsspsupport:i:1;videoplaybackmode:i:1;audiocapturemode:i:1;audiomode:i:0;camerastoredirect:s:*;devicestoredirect:s:;drivestoredirect:s:*;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:0;redirectwebauthn:i:1;usbdevicestoredirect:s:*;use multimon:i:1;dynamic resolution:i:1'
    vmTemplate = '{"domain":"","galleryImageOffer":"windows-11","galleryImagePublisher":"microsoftwindowsdesktop","galleryImageSKU":"win11-22h2-ent","imageType":"Gallery","customImageId":null,"namePrefix":"avd-vm-admin","osDiskType":"Premium_LRS","vmSize":{"id":"Standard_D2s_v3","cores":2,"ram":8},"galleryItemId":"microsoftwindowsdesktop.windows-11win11-22h2-ent","hibernate":false,"diskSizeGB":0,"securityType":"TrustedLaunch","secureBoot":true,"vTPM":true}'
    tokenExpirationTime = (Get-Date).AddDays(25)
    hostpoolTags = @{environment = 'admin'}
    applicationGroupTags = @{environment = 'admin'}
    availabilitySetTags = @{environment = 'admin'}
    networkInterfaceTags = @{environment = 'admin'}
    networkSecurityGroupTags = @{environment = 'admin'}
    virtualMachineTags = @{environment = 'admin'}
    apiVersion = '2022-10-14-preview'
    deploymentId = $DeploymentName
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
    Name = $DeploymentName
    ResourceGroupName = $SharedResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\azure-virtual-desktop\host-pool\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams

# Add virtual machines to the hostpool
$DeploymentName = 'admin-avd-hostpool-vm-1'
$ParameterObject = @{
    hostpoolName = ('avd-hp-admin-{0}-1' -f $LocationShortName)
    hostpoolToken = (Get-AzWvdHostPoolRegistrationToken -ResourceGroupName $SharedResourceGroupName -HostPoolName ('avd-hp-admin-{0}-1' -f $LocationShortName)).Token
    vmAdministratorAccountUsername = 'vmadmin'
    vmAdministratorAccountPassword = 'ALP!q$L?Hqoz&c5M'
    vmResourceGroup = $SharedResourceGroupName
    vmLocation = $Location
    vmSize = 'Standard_D2s_v3'
    vmDiskSizeGB = 0
    vmInitialNumber = [int](Get-AzWvdSessionHost -HostPoolName ('avd-hp-admin-{0}-1' -f $LocationShortName) -ResourceGroupName $SharedResourceGroupName).Name[-1].Split('-')[-1] + 1 # next number up so must find what the last number used was
    vmNumberOfInstances = 1
    vmNamePrefix = 'avd-admin'
    vmImageType = 'Gallery'
    vmGalleryImageOffer = 'windows-11'
    vmGalleryImagePublisher = 'microsoftwindowsdesktop'
    vmGalleryImageSKU = 'win11-22h2-ent'
    vmDiskType = 'Premium_LRS'
    existingVnetName = ('vnet-shd-{0}-1' -f $LocationShortName)
    existingSubnetName = ('snet-shd-{0}-2' -f $LocationShortName)
    virtualNetworkResourceGroupName = $SharedResourceGroupName
    deploymentId = $DeploymentName
    apiVersion = '2022-10-14-preview'
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
    Name = $DeploymentName
    ResourceGroupName = $SharedResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\azure-virtual-desktop\add-machines-to-pool\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams

#Set-AzContext -Subscription (Get-AzSubscription).Id
# Add StartVMOnConnect to host pool
Update-AzWvdHostPool -ResourceGroupName $SharedResourceGroupName -Name ('avd-hp-admin-{0}-1' -f $LocationShortName) -StartVMOnConnect:$true

# Create a groups od users to assign to the AVD application
$parameters = @{
    DisplayName = 'Admin Host Pool Users'
    MailEnabled = $False 
    MailNickName = (New-Guid).ToString().Substring(0,10)
    SecurityEnabled = $true
    Description = 'Members of this group will have access to the AVDs in admin host pool'
}
$Group = New-MgGroup @parameters

Start-Sleep -Seconds 180 # give time for azure to propgate the new group

# Assign groups to the host pool desktop application group
$parameters = @{
    ObjectId = $Group.Id
    ResourceName = 'dag-avd-hp-admin-uv-1'
    ResourceGroupName = $SharedResourceGroupName
    RoleDefinitionName = 'Desktop Virtualization User'
    ResourceType = 'Microsoft.DesktopVirtualization/applicationGroups'
}

New-AzRoleAssignment @parameters

# Add users to the host pool group
$parameters = @{
    GroupId = $Group.Id
    DirectoryObjectId = (Get-MgUser -UserId 'mroche@salasobriengov.onmicrosoft.us').Id
}
New-MgGroupMember @parameters

$parameters = @{
    GroupId = $Group.Id
    DirectoryObjectId = (Get-MgUser -UserId 'spotts@salasobriengov.onmicrosoft.us').Id
}
New-MgGroupMember @parameters

<# The code below deploys a vm with a pip and nsg. Needs to be used in a subnet not protected via Azure Firewall
# Deploy Golden Image
$ParameterObject = @{
    location = $Location
    networkInterfaceName = 'nic-avd-gld-img-1'
    enableAcceleratedNetworking = $true
    networkSecurityGroupName = 'nsg-avd-gld-img-1'
    networkSecurityGroupRules = @(
        @{
            name = 'rdp-in'
            properties = @{
                priority = 300
                protocol = 'TCP'
                access = 'Allow'
                direction = 'Inbound'
                sourceAddressPrefix = '*'
                sourcePortRange = '*'
                destinationAddressPrefix = '*'
                destinationPortRange = '3389'
            }
        }
    )
    subnetName = ('snet-shd-{0}-1' -f $LocationShortName)
    virtualNetworkId = (Get-AzVirtualNetwork -Name ('vnet-shd-{0}-1' -f $LocationShortName) -ResourceGroupName $SharedResourceGroupName).Id
    publicIpAddressName = 'pip-avd-gld-img-1'
    publicIpAddressType = 'Static'
    publicIpAddressSku = 'Standard'
    pipDeleteOption = 'Delete'
    virtualMachineName = 'avd-gld-img-1'
    virtualMachineComputerName = 'avd-gld-img-1'
    virtualMachineRG = $SharedResourceGroupName
    osDiskType = 'Premium_LRS'
    osDiskDeleteOption = 'Delete'
    virtualMachineSize = 'Standard_D2s_v3'
    nicDeleteOption  = 'Delete'
    hibernationEnabled  = $false
    adminUsername = 'vmadmin'
    adminPassword = 'ALP!q$L?Hqoz&c5M'
    patchMode = 'AutomaticByOS'
    enableHotpatching = $false
    securityType = 'TrustedLaunch'
    secureBoot   = $true
    vTPM = $true
}
$DeploymentParams = @{
    Name = 'avd-golden-img'
    ResourceGroupName = $SharedResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\virtual-machines\vm-nsg-pip\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams
#>

$ParameterObject = @{
    location = $Location
    networkInterfaceName = 'nic-avd-gld-img-0'
    enableAcceleratedNetworking = $true
    subnetName = ('snet-shd-{0}-1' -f $LocationShortName)
    virtualNetworkId = (Get-AzVirtualNetwork -Name ('vnet-shd-{0}-1' -f $LocationShortName) -ResourceGroupName $SharedResourceGroupName).Id
    virtualMachineName = 'avd-gld-img-0'
    virtualMachineComputerName = 'avd-gld-img-0'
    virtualMachineRG = $SharedResourceGroupName
    osDiskType = 'Premium_LRS'
    osDiskDeleteOption = 'Delete'
    virtualMachineSize = 'Standard_D2s_v3'
    nicDeleteOption  = 'Delete'
    hibernationEnabled  = $false
    adminUsername = 'vmadmin'
    adminPassword = 'ALP!q$L?Hqoz&c5M'
    patchMode = 'AutomaticByOS'
    enableHotpatching = $false
    securityType = 'TrustedLaunch'
    secureBoot   = $true
    vTPM = $true
}
$DeploymentParams = @{
    Name = 'avd-golden-img'
    ResourceGroupName = $SharedResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\virtual-machines\vm-base\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams

<# Not working
$params = @{
    Name = "rdp-gld-img-in"
    Protocol = "TCP"
    SourceAddress = '162.199.14.193/32'
    DestinationAddress = (Get-AzPublicIpAddress -Name (Get-AzFirewall -ResourceGroupName $SharedResourceGroupName | Select-Object -ExpandProperty IpConfigurations).PublicIpAddress.Id.Split('/')[-1] -ResourceGroupName $SharedResourceGroupName).IpAddress
    DestinationPort = '3389'
    TranslatedAddress = (Get-AzNetworkInterface -Name (Get-AzVM -Name 'avd-gld-img-0').NetworkProfile.NetworkInterfaces.Id.Split('/')[-1]).IpConfigurations.PrivateIpAddress
    TranslatedPort = '3389'
}
$NatRule = New-AzFirewallNatRule @params
$NatCollection = New-AzFirewallNatRuleCollection -Name  dnatrules-rdp-allow -Priority 501 -Rule $NatRule
$params = @{
    Name = ('wafrg-shd-{0}-2' -f $LocationShortName)
    Priority = 500
    RuleCollection = $NatCollection
    ResourceGroupName = $SharedResourceGroupName
    FirewallPolicyName = ('waf-shd-{0}-1' -f $LocationShortName)
}
New-AzFirewallPolicyRuleCollectionGroup @params 
#>


# Configure roles and access to facilitate AVD management and access
# First add the "Desktop Virtualization Power On Off Contributor" role to the resource group allowing the automatic startup and shutdown of AVDs
$parameters = @{
    RoleDefinitionName = 'Desktop Virtualization Power On Off Contributor'
    ApplicationId = "9cdead84-a844-4324-93f2-b2e6bb768d07"
    #Scope = ("/subscriptions/{0}" -f (Get-AzSubscription).Id)
    #Scope = ('/subscriptions/{0}/resourceGroups/{1}'-f (Get-AzSubscription).Id, $SharedResourceGroupName)
    ResourceGroupName = $CustomerResourceGroupName
}
New-AzRoleAssignment @parameters

# Add virtual machine user login rbac role to resource group
$parameters = @{
    ObjectId = (Get-AzADGroup -DisplayName 'Virtual Machine User Login').Id
    RoleDefinitionName = 'Virtual Machine User Login'
    ResourceGroupName = $CustomerResourceGroupName
}
New-AzRoleAssignment @parameters #https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell

# Deploy CAD AVD pool
$DeploymentName = 'cad-avd-hostpool-1'
$GalleryName = (Get-AzGallery -ResourceGroupName $SharedResourceGroupName).Name
$GalleryImageName = (Get-AzGalleryImageDefinition -ResourceGroupName $SharedResourceGroupName -GalleryName $GalleryName).Name
$GalleryImageVersionId = (Get-AzGalleryImageVersion -ResourceGroupName $SharedResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $GalleryImageName).Id

$ParameterObject = @{
    hostpoolName = ('avd-hp-cad-{0}-1' -f $LocationShortName)
    hostpoolDescription = 'AVD pool for CAD user personas'
    hostpoolDiagnosticSettingsLogAnalyticsWorkspaceName = ('log-{0}-{1}-1' -f $CustomerShortName, $LocationShortName)
    location = $Location
    workSpaceName = ('avd-ws-{0}-2' -f $LocationShortName)
    workspaceLocation = $Location
    workspaceResourceGroup = $CustomerResourceGroupName
    isNewWorkspace = $true
    addToWorkspace = $true
    vmAdministratorAccountUsername = 'vmadmin'
    vmAdministratorAccountPassword = 'ALP!q$L?Hqoz&c5M'
    vmResourceGroup = $CustomerResourceGroupName
    vmLocation = $Location
    vmSize = 'Standard_NC8as_T4_v3'
    vmDiskSizeGB = 0
    vmHibernate = $false
    vmNumberOfInstances = 3
    vmNamePrefix = 'avd-cad'
    vmImageType = 'CustomImage'
    vmCustomImageSourceId = $GalleryImageVersionId 
    vmDiskType = 'Premium_LRS'
    existingVnetName = ('vnet-{0}-{1}-1' -f $CustomerShortName, $LocationShortName)
    existingSubnetName = ('snet-{0}-{1}-1' -f $CustomerShortName, $LocationShortName)
    virtualNetworkResourceGroupName = $CustomerResourceGroupName
    hostpoolType = 'Personal'
    personalDesktopAssignmentType = 'Automatic'
    loadBalancerType = 'Persistent'
    customRdpProperty = 'enablerdsaadauth:i:1;enablecredsspsupport:i:1;videoplaybackmode:i:1;audiocapturemode:i:1;audiomode:i:0;camerastoredirect:s:*;devicestoredirect:s:;drivestoredirect:s:*;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:0;redirectwebauthn:i:1;usbdevicestoredirect:s:*;use multimon:i:1;dynamic resolution:i:1'
    vmTemplate = "{`"domain`":`"`",`"galleryImageOffer`":null,`"galleryImagePublisher`":null,`"galleryImageSKU`":null,`"imageType`":`"CustomImage`",`"customImageId`":`"$GalleryImageVersionId`",`"namePrefix`":`"cad-avd`",`"osDiskType`":`"Premium_LRS`",`"vmSize`":{`"id`":`"Standard_NC8as_T4_v3`",`"cores`":8,`"ram`":56,`"rdmaEnabled`":false,`"supportsMemoryPreservingMaintenance`":false},`"galleryItemId`":null,`"hibernate`":false,`"diskSizeGB`":0,`"securityType`":`"TrustedLaunch`",`"secureBoot`":true,`"vTPM`":true,`"vmInfrastructureType`":`"Cloud`",`"virtualProcessorCount`":null,`"memoryGB`":null,`"maximumMemoryGB`":null,`"minimumMemoryGB`":null,`"dynamicMemoryConfig`":false}"
    tokenExpirationTime = (Get-Date).AddDays(25)
    hostpoolTags = @{environment = 'cad'}
    applicationGroupTags = @{environment = 'cad'}
    availabilitySetTags = @{environment = 'cad'}
    networkInterfaceTags = @{environment = 'cad'}
    networkSecurityGroupTags = @{environment = 'cad'}
    virtualMachineTags = @{environment = 'cad'}
    apiVersion = '2022-10-14-preview'
    deploymentId = $DeploymentName
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
    Name = $DeploymentName
    ResourceGroupName = $CustomerResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\azure-virtual-desktop\host-pool\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams

# Add virtual machines to the hostpool
$DeploymentName = 'cad-avd-hostpool-vm-1'
$HostPoolName = ('avd-hp-cad-{0}-1' -f $LocationShortName)
$ParameterObject = @{
    hostpoolName = $HostPoolName
    hostpoolToken = (Get-AzWvdHostPoolRegistrationToken -ResourceGroupName $CustomerResourceGroupName -HostPoolName $HostPoolName).Token
    vmAdministratorAccountUsername = 'vmadmin'
    vmAdministratorAccountPassword = 'ALP!q$L?Hqoz&c5M'
    vmResourceGroup = $CustomerResourceGroupName
    vmLocation = $Location
    vmSize = 'Standard_NC8as_T4_v3'
    vmDiskSizeGB = 0
    vmInitialNumber = [int](Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $CustomerResourceGroupName).Name[-1].Split('-')[-1] + 1 # next number up so must find what the last number used was
    vmNumberOfInstances = 3
    vmNamePrefix = 'avd-cad'
    vmImageType = 'CustomImage'
    vmCustomImageSourceId = $GalleryImageVersionId 
    vmDiskType = 'Premium_LRS'
    existingVnetName = ('vnet-{0}-{1}-1' -f $CustomerShortName, $LocationShortName)
    existingSubnetName = ('snet-{0}-{1}-2' -f $CustomerShortName, $LocationShortName)
    virtualNetworkResourceGroupName = $CustomerResourceGroupName
    deploymentId = $DeploymentName
    apiVersion = '2022-10-14-preview'
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
    Name = $DeploymentName
    ResourceGroupName = $CustomerResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\azure-virtual-desktop\add-machines-to-pool\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams

# Add StartVMOnConnect to host pool
Update-AzWvdHostPool -ResourceGroupName $CustomerResourceGroupName -Name $HostPoolName -StartVMOnConnect:$true

# Create a groups od users to assign to the AVD application
$parameters = @{
    DisplayName = 'CAD Host Pool Users'
    MailEnabled = $False 
    MailNickName = (New-Guid).ToString().Substring(0,10)
    SecurityEnabled = $true
    Description = 'Members of this group will have access to the AVDs in cad host pool'
}
$Group = New-MgGroup @parameters

Start-Sleep -Seconds 180 # give time for azure to propgate the new group

# Assign groups to the host pool desktop application group
$parameters = @{
    ObjectId = $Group.Id
    ResourceName = 'dag-avd-hp-cad-uv-1'
    ResourceGroupName = $CustomerResourceGroupName
    RoleDefinitionName = 'Desktop Virtualization User'
    ResourceType = 'Microsoft.DesktopVirtualization/applicationGroups'
}
New-AzRoleAssignment @parameters

# Add users to the host pool group
Get-MgUser -ConsistencyLevel eventual -Count userCount -Filter  "endsWith(UserPrincipalName, '@salasobriengov.com')" | ForEach-Object {
    $parameters = @{
        GroupId = $Group.Id
        DirectoryObjectId = $_.Id
    }
    New-MgGroupMember @parameters
}


$ParameterObject = @{
    scalingPlanName = 'scal-salas-uv-default-1'
    scalingPlanDescription = 'Default scaling plan'
    timezone = 'Eastern Standard Time'
    friendlyName = 'Default Scaling'
    hostpoolType = 'Personal'
    schedules = @(
        @{
            name = 'weekdays_schedule'
            daysOfWeek = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday','Saturday', 'Sunday')
            rampUpStartTime = @{
                hour = 7
                minute = 0
            }
            peakStartTime = @{
                hour = 9
                minute = 0
            }
            peakMinutesToWaitOnDisconnect = 0
            peakActionOnDisconnect = 'None'
            peakMinutesToWaitOnLogoff = 0
            peakActionOnLogoff = 'None'
            peakStartVMOnConnect = 'Enable'
            rampDownStartTime = @{
                hour = 20
                minute = 0
            }
            rampDownMinutesToWaitOnDisconnect = 30
            rampDownActionOnDisconnect = 'Deallocate'
            rampDownMinutesToWaitOnLogoff = 15
            rampDownActionOnLogoff = 'Deallocate'
            rampDownStartVMOnConnect = 'Enable'
            rampUpAutoStartHosts = 'None'
            rampUpStartVMOnConnect = 'Enable'
            rampUpMinutesToWaitOnDisconnect = 0
            rampUpActionOnDisconnect = 'None'
            rampUpMinutesToWaitOnLogoff = 0
            rampUpActionOnLogoff = 'None'
            offPeakStartTime = @{
                hour = 22
                minute = 0
            }
            offPeakMinutesToWaitOnDisconnect = 15
            offPeakActionOnDisconnect = 'Deallocate'
            offPeakMinutesToWaitOnLogoff = 5
            offPeakActionOnLogoff = 'Deallocate'
            offPeakStartVMOnConnect = 'Enable'
        }<# ,
        @{
            name = 'weekends_schedule'
            daysOfWeek = @('Saturday', 'Sunday')
            rampUpStartTime = @{
                hour = 8
                minute = 0
            }
            peakStartTime = @{
                hour = 9
                minute = 0
            }
            peakMinutesToWaitOnDisconnect = 60
            peakActionOnDisconnect = 'Deallocate'
            peakMinutesToWaitOnLogoff = 15
            peakActionOnLogoff = 'Deallocate'
            peakStartVMOnConnect = 'Enable'
            rampDownStartTime = {
                hour = 18
                minute = 0
            }
            rampDownMinutesToWaitOnDisconnect = 30
            rampDownActionOnDisconnect = 'Deallocate'
            rampDownMinutesToWaitOnLogoff = 15
            rampDownActionOnLogoff = 'Deallocate'
            rampDownStartVMOnConnect = 'Enable'
            rampUpAutoStartHosts = 'None'
            rampUpStartVMOnConnect = 'Disable'
            rampUpMinutesToWaitOnDisconnect = 60
            rampUpActionOnDisconnect = 'Deallocate'
            rampUpMinutesToWaitOnLogoff = 15
            rampUpActionOnLogoff = 'Deallocate'
            offPeakStartTime = {
                hour = 22
                minute = 0
            }
            offPeakMinutesToWaitOnDisconnect = 15
            offPeakActionOnDisconnect = 'Deallocate'
            offPeakMinutesToWaitOnLogoff = 5
            offPeakActionOnLogoff = 'Deallocate'
            offPeakStartVMOnConnect = 'Enable'
        } #>
    )
    location = 'usgovvirginia'
    systemData = @{ 
            personalScalingPlanFeature = $true
    }
    apiVersion = '2022-10-14-preview'
    hostpoolreferences = @(
        @{
            hostpoolArmPath = (Get-AzWvdHostPool -Name 'avd-hp-cad-uv-1' -ResourceGroupName $CustomerResourceGroupName).Id
            scalingPlanEnabled = $true
        }
    )
}
$DeploymentParams = @{
    Name = 'scaling-plan-avd-hp-cad-uv-1'
    ResourceGroupName = $CustomerResourceGroupName
    TemplateFile = 'C:\GitHub\Azure-PS-Resource-Manager\microsoft.compute\azure-virtual-desktop\scaling-plan\azuredeploy.json'
    TemplateParameterObject = $ParameterObject
}
New-AzResourceGroupDeployment @DeploymentParams