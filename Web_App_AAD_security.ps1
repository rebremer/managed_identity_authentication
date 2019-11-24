# Powershell script to enable AAD authentication from ADFv2 to Azure Function using Managed Identity
# Manual steps are descriped in https://github.com/rebremer/managed_identity_authentication/blob/master/readme.md
# Make sure that you have enough rights to create app registrations in Azure AD (typically, service connections in Azure DevOps cannot do this)

# 0.1 params
$rg_name = "<<your resource group>>"
$loc = "<<your azure location, e.g. westeurope>>"
$fun_name = "<<your Azure Function name>>"
$fun_stor = "<<your storage account linked to your Azure Function>>"
$fun_app_plan = "<<your App service plan name>>"
$adfv2_name = "<<your ADFv2 instance name>>"

# 0.2 connect to AAD
$Environment = "AzureCloud"
$aadConnection = Connect-AzureAD -AzureEnvironmentName $Environment

# 1. create resources for web app (azure function)
New-AzResourceGroup -Name $rg_name -Location $loc
New-AzStorageAccount -ResourceGroupName $rg_name -AccountName $fun_stor -Location $loc -SkuName Standard_LRS
New-AzAppServicePlan -ResourceGroupName $rg_name -Name $fun_app_plan -Location $loc -Tier "Basic" -NumberofWorkers 2 -WorkerSize "Small"
New-AzWebApp -ResourceGroupName $rg_name -Name $fun_name -Location $loc -AppServicePlan $fun_app_plan

# 2. Creat App registration
# step 2 is derived from https://devblogs.microsoft.com/azuregov/web-app-easy-auth-configuration-using-powershell/
$Password = [System.Convert]::ToBase64String($([guid]::NewGuid()).ToByteArray())
$startDate = Get-Date
$PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
$PasswordCredential.StartDate = $startDate
$PasswordCredential.EndDate = $startDate.AddYears(10)
$PasswordCredential.Value = $Password
$identifier_url = "https://" + $fun_name + ".azurewebsites.net"
[string[]]$reply_url = $identifier_url + ".auth/login/aad/callback"
$reqAAD = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$reqAAD.ResourceAppId = "00000002-0000-0000-c000-000000000000"
$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope" #Sign you in and read your profile
$reqAAD.ResourceAccess = $delPermission1
$appReg = New-AzureADApplication -DisplayName $fun_name -IdentifierUris $identifier_url -Homepage $identifier_url -ReplyUrls $reply_url -PasswordCredential $PasswordCredential -RequiredResourceAccess $reqAAD

# 3. Add new AppRole object to app registration
# step 3 is derived from https://gist.github.com/psignoret/45e2a5769ea78ae9991d1adef88f6637
$newAppRole = [Microsoft.Open.AzureAD.Model.AppRole]::new()
$newAppRole.DisplayName = "Allow MSI SPN of ADFv2 to authenticate to Azure Function using its MSI"
$newAppRole.Description = "Allow MSI SPN of ADFv2 to authenticate to Azure Function using its MSI"
$newAppRole.Value = "Things.Read.All"
$Id = [Guid]::NewGuid().ToString()
$newAppRole.Id = $Id
$newAppRole.IsEnabled = $true
$newAppRole.AllowedMemberTypes = "Application"
$appRoles = $appReg.AppRoles
$appRoles += $newAppRole
$appReg | Set-AzureADApplication -AppRoles $appRoles

# 4. add app registration to web app
$authResourceName = $fun_name + "/authsettings"
$auth = Invoke-AzResourceAction -ResourceGroupName $rg_name -ResourceType Microsoft.Web/sites/config -ResourceName $authResourceName -Action list -ApiVersion 2016-08-01 -Force
$auth.properties.enabled = "True"
$auth.properties.unauthenticatedClientAction = "RedirectToLoginPage"
$auth.properties.tokenStoreEnabled = "True"
$auth.properties.defaultProvider = "AzureActiveDirectory"
$auth.properties.isAadAutoProvisioned = "False"
$auth.properties.clientId = $appReg.AppId
$auth.properties.clientSecret = $Password
$loginBaseUrl = $(Get-AzEnvironment -Name $environment).ActiveDirectoryAuthority
$auth.properties.issuer = $issuerUrl = $loginBaseUrl + $aadConnection.Tenant.Id.Guid + "/"
New-AzResource -PropertyObject $auth.properties -ResourceGroupName $rg_name -ResourceType Microsoft.Web/sites/config -ResourceName $authResourceName -ApiVersion 2016-08-01 -Force

# 5. Create SPN connected to app registration
$servicePrincipal = New-AzADServicePrincipal -ApplicationId $appReg.AppId -DisplayName $fun_name

# 6. Set "User assignment required?" to true in SPN
Set-AzureADServicePrincipal -ObjectId $servicePrincipal.Id -AppRoleAssignmentRequired $true

# 7. Set MI of ADFv2 as only authorized user to log in web app (azure function) 

$adfv2_resource = Get-AzDataFactoryV2 -ResourceGroupName $rg_name -Name $adfv2_name
New-AzureADServiceAppRoleAssignment -ObjectId $adfv2_resource.Identity.PrincipalId -Id $newAppRole.Id -PrincipalId $adfv2_resource.Identity.PrincipalId -ResourceId $servicePrincipal.Id