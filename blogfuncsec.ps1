$test = "3"

$rg = "blog-funcsec" + $test + "-rg"
$loc = "westeurope"
$funname = "blog-funcsec" + $test + "-func"
$funstor = "blogfuncsec" + $test + "stor"
$funplan = "blog-funcsec" + $test + "-plan"
$vnet = "blog-funcsec" + $test + "-vnet"
$nsg = "blog-funcsec" + $test + "-nsg"
$subnet = "azurefunction"
$addressrange = "10.200.0.0"
$funcontainer = "testrb"

$Environment = "AzureCloud"
$aadConnection = Connect-AzureAD -AzureEnvironmentName $Environment

# create resource group
az group create -n $rg -l $loc

# create Storage account
az storage account create -n $funstor -g $rg --sku Standard_LRS
az storage container create --account-name $funstor -n $funcontainer

# create VNET
az network vnet create -g $rg -n $vnet --address-prefix $addressrange/16 -l $loc

# create NSG
az network nsg create -g $rg -n $nsg

# create rule allowing outbound to storage account WestEurope and port 443, and then block all outbound
az network nsg rule create -g $rg --nsg-name $nsg -n allow_we_stor_443 --priority 100 --source-address-prefixes VirtualNetwork --source-port-ranges '*' --destination-address-prefixes Storage.WestEurope --destination-port-ranges '443' --access Allow --protocol '*' --description "Allow storage West Europe 443" --direction Outbound
az network nsg rule create -g $rg --nsg-name $nsg -n allow_azure_internal --priority 110 --source-address-prefixes VirtualNetwork --source-port-ranges '*' --destination-address-prefixes AzureCloud.WestEurope --destination-port-ranges '*' --access Allow --protocol '*' --description "Allow Azure internal" --direction Outbound
#az network nsg rule create -g $rg --nsg-name $nsg -n allow_vnet_internal --priority 120 --source-address-prefixes VirtualNetwork --source-port-ranges '*' --destination-address-prefixes VirtualNetwork --destination-port-ranges '*' --access Allow --protocol '*' --description "Allow Azure internal" --direction Outbound
az network nsg rule create -g $rg --nsg-name $nsg -n deny_all_outbound --priority 130 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '*' --access Deny --protocol '*' --description "Deny all outbound" --direction Outbound

# create subnet with NSG to VNET
az network vnet subnet create -g $rg --vnet-name $vnet -n $subnet --address-prefixes $addressrange/24 --network-security-group $nsg

# Turn on firewall
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $rg -Name $funstor -DefaultAction Deny

# Set service endpoints for storage and web app to subnet
Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet | Set-AzVirtualNetworkSubnetConfig -Name $subnet -AddressPrefix $addressrange/24 -ServiceEndpoint "Microsoft.Storage", "Microsoft.Web" | Set-AzVirtualNetwork

# Add firewall rules to Storage Account
$subnetobject = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet | Get-AzVirtualNetworkSubnetConfig -Name $subnet
Add-AzStorageAccountNetworkRule -ResourceGroupName $rg -Name $funstor -VirtualNetworkResourceId $subnetobject.Id

# Create Azure Function
az appservice plan create -n $funplan -g $rg --sku P1v2 --is-linux
az functionapp create -g $rg --os-type Linux --plan $funplan --runtime python --name $funname --storage-account $funstor

# Add VNET integration
az webapp vnet-integration add -g $rg -n $funname --vnet $vnet --subnet $subnet

# To create Azure Function in Python, see https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-functions/functions-create-first-function-python.md
func init $funname --python
cd $funname
func new --name HttpTrigger --template "HTTP trigger"

# upload code Azure Function
Start-Sleep -s 60
cd ..
cd $funname
func azure functionapp publish $funname

# done

# 2. Creat App registration
# step 2 is derived from https://devblogs.microsoft.com/azuregov/web-app-easy-auth-configuration-using-powershell/
$Password = [System.Convert]::ToBase64String($([guid]::NewGuid()).ToByteArray())
$startDate = Get-Date
$PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
$PasswordCredential.StartDate = $startDate
$PasswordCredential.EndDate = $startDate.AddYears(10)
$PasswordCredential.Value = $Password
$identifier_url = "https://" + $funname + ".azurewebsites.net"
[string[]]$reply_url = $identifier_url + "/.auth/login/aad/callback"
$reqAAD = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$reqAAD.ResourceAppId = "00000002-0000-0000-c000-000000000000"
$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope" #Sign you in and read your profile
$reqAAD.ResourceAccess = $delPermission1
$appReg = New-AzureADApplication -DisplayName $funname -IdentifierUris $identifier_url -Homepage $identifier_url -ReplyUrls $reply_url -PasswordCredential $PasswordCredential -RequiredResourceAccess $reqAAD

# 3. add app registration to web app
$authResourceName = $funname + "/authsettings"
$auth = Invoke-AzResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/config -ResourceName $authResourceName -Action list -ApiVersion 2016-08-01 -Force
$auth.properties.enabled = "True"
$auth.properties.unauthenticatedClientAction = "RedirectToLoginPage"
$auth.properties.tokenStoreEnabled = "True"
$auth.properties.defaultProvider = "AzureActiveDirectory"
$auth.properties.isAadAutoProvisioned = "False"
$auth.properties.clientId = $appReg.AppId
$auth.properties.clientSecret = $Password
$loginBaseUrl = $(Get-AzEnvironment -Name $environment).ActiveDirectoryAuthority
$auth.properties.issuer = $loginBaseUrl + $aadConnection.Tenant.Id.Guid + "/"
$auth.properties.allowedAudiences = @($identifier_url)
New-AzResource -PropertyObject $auth.properties -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/config -ResourceName $authResourceName -ApiVersion 2016-08-01 -Force

# 4. Add identity web app
Set-AzWebApp -AssignIdentity $true -Name $funname -ResourceGroupName $rg 
$fun_resource = Get-AzWebApp -ResourceGroupName $rg -Name $funname

# 5. Add identity as reader to storage account
$sub_id = (Get-AzContext).Subscription.id
New-AzRoleAssignment -ObjectId $fun_resource.Identity.PrincipalId -RoleDefinitionName "Storage Blob Data Contributor" -Scope  "/subscriptions/$sub_id/resourceGroups/$rg/providers/Microsoft.Storage/storageAccounts/$funstor/blobServices/default/containers/$funcontainer"

# 6. Get FunctionURL

$urlResourceName = $funname + "/HttpTrigger"
$function_key = Invoke-AzResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/Functions -ResourceName $urlResourceName -Action listkeys -ApiVersion 2015-08-01 -Force
$functionurl = $identifier_url + "/api/HttpTrigger?code=" + $function_key.default
write-host $functionurl
