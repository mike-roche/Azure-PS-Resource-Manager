#notes
Connect-AzAccount -Environment AzureUSGovernment

$Params = @{
    City = 'Merritt Island'
    CompanyName = "Salas O'Brien"
    Department = 'Mechanical'
    DisplayName = 'Michael Knott'
    GivenName = 'Michael'
    JobTitle = 'Fire Protection Engineer'
    Mail = 'michael.knott@salasobriengov.com'
    MailNickName = 'michael.knott'
    PostalCode = '32953'
    State = 'Florida'
    StreetAddress = '5455 North Courtenay Parkway'
    Surname  = 'Knott'
    UsageLocation = 'US'
    UserPrincipalName = 'michael.knott@salasobriengov.com'
    Password = ConvertTo-SecureString -String 'r3dPlay56' -AsPlainText -Force  
}
New-AzADUser @Params

$Params = @{
    City = 'Merritt Island'
    CompanyName = "Salas O'Brien"
    Department = 'Drafting'
    DisplayName = 'Jay Fletcher'
    GivenName = 'Jay'
    JobTitle = 'Fire Protection Designer'
    Mail = 'jay.fletcher@salasobriengov.com'
    MailNickName = 'jay.fletcher'
    PostalCode = '32953'
    State = 'Florida'
    StreetAddress = '5455 North Courtenay Parkway'
    Surname  = 'Fletcher'
    UsageLocation = 'US'
    UserPrincipalName = 'jay.fletcher@salasobriengov.com'
    Password = ConvertTo-SecureString -String '@ngryFlag53' -AsPlainText -Force  
}
New-AzADUser @Params

$Params = @{
    City = 'Merritt Island'
    CompanyName = "Salas O'Brien"
    Department = 'Drafting'
    DisplayName = 'Matthew Johnson'
    GivenName = 'Matthew'
    JobTitle = 'Drafter'
    Mail = 'matthew.johnson@salasobriengov.com'
    MailNickName = 'matthew.johnson'
    PostalCode = '32953'
    State = 'Florida'
    StreetAddress = '5455 North Courtenay Parkway'
    Surname  = 'Johnson'
    UsageLocation = 'US'
    UserPrincipalName = 'matthew.johnson@salasobriengov.com'
    Password = ConvertTo-SecureString -String 'm3ssyRoll66' -AsPlainText -Force
}
New-AzADUser @Params

$Params = @{
    City = 'Merritt Island'
    CompanyName = "Salas O'Brien"
    Department = 'Drafting'
    DisplayName = 'Michael Horne'
    GivenName = 'Michael'
    JobTitle = 'BIM Production Manager'
    Mail = 'michael.horne@salasobriengov.com'
    MailNickName = 'michael.horne'
    PostalCode = '32953'
    State = 'Florida'
    StreetAddress = '5455 North Courtenay Parkway'
    Surname  = 'Horne'
    UsageLocation = 'US'
    UserPrincipalName = 'michael.horne@salasobriengov.com'
    Password = ConvertTo-SecureString -String 'dampM3mory51' -AsPlainText -Force
}
New-AzADUser @Params


$Params = @{
    City = 'Merritt Island'
    CompanyName = "Salas O'Brien"
    Department = 'Drafting'
    DisplayName = 'Bryan Harvey'
    GivenName = 'Bryan'
    JobTitle = 'BIM Department Manager'
    Mail = 'bryan.harvey@salasobriengov.com'
    MailNickName = 'bryan.harvey'
    PostalCode = '32953'
    State = 'Florida'
    StreetAddress = '5455 North Courtenay Parkway'
    Surname  = 'Harvey'
    UsageLocation = 'US'
    UserPrincipalName = 'bryan.harvey@salasobriengov.com'
    Password = ConvertTo-SecureString -String '!voryApple84' -AsPlainText -Force
}
New-AzADUser @Params



$Permissions = @(
    "Policy.Read.All",
    "Policy.ReadWrite.ConditionalAccess",
    "Application.Read.All",
    "User.ReadWrite.All",
    "Group.ReadWrite.All",
    "Organization.Read.All",
    "RoleManagement.ReadWrite.Directory"
)
Connect-MgGraph -Scopes $Permissions



$Params = @{
    DisplayName = 'Test Group'
    GroupTypes = DynamicMembership
    MailEnabled = $false
    MailNickName = 'testgroup'
    MembershipRule = 'user.companyName -eq "Test"'
    MembershipRuleProcessingState = 'On'
    SecurityEnabled = $true
}
New-MgGroup @Params


New-MgGroup -DisplayName 'Test Group' -MailEnabled:$False  -MailNickName 'testgroup' -SecurityEnabled

<# 
Service principal -	Application ID
Azure Virtual Desktop - 9cdead84-a844-4324-93f2-b2e6bb768d07
Azure Virtual Desktop Client - a85cf173-4192-42f8-81fa-777a763e6e2c
Azure Virtual Desktop ARM Provider - 50e95039-b200-4007-bc97-8d5790743a63
#>

$parameters = @{
    RoleDefinitionName = "Desktop Virtualization Power On Off Contributor"
    ApplicationId = "9cdead84-a844-4324-93f2-b2e6bb768d07"
    #Scope = ("/subscriptions/{0}" -f (Get-AzSubscription).Id)
    #Scope = ('/subscriptions/{0}/resourceGroups/{1}'-f (Get-AzSubscription).Id, $SharedResourceGroupName)
    ResourceGroupName = $SharedResourceGroupName
}
New-AzRoleAssignment @parameters #https://learn.microsoft.com/en-us/azure/virtual-desktop/service-principal-assign-roles

$Group = New-MgGroup -DisplayName 'NetCov Virtual Machine User Login' -MailEnabled:$False  -MailNickName (New-Guid).ToString().Substring(0,10) -SecurityEnabled -Description ''
$parameters = @{
    ObjectId = $Group.Id
    RoleDefinitionName = 'Virtual Machine User Login'
    ResourceGroupName = $SharedResourceGroupName
}
New-AzRoleAssignment @parameters #https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-powershell

$parameters = @{
    GroupId = $Group.Id
    DirectoryObjectId = (Get-MgUser -UserId 'michael.roche@netcovdemo.onmicrosoft.com').Id
}
New-MgGroupMember @parameters

Set-AzContext -Subscription (Get-AzSubscription).Id
Update-AzWvdHostPool -ResourceGroupName $SharedResourceGroupName -Name "avd-hpl-admin-eu2-1" -StartVMOnConnect:$true

