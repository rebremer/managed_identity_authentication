$test = "4"

$rg = "test-funcvnet" + $test + "-rg"
$loc = "westeurope"
$funname = "test-funcvnet" + $test + "-func"
$funstor = "testfuncvnet" + $test + "stor"
$funplan = "test-funcvnet" + $test + "-plan"
$vnet = "test-funcvnet" + $test + "-vnet"
$nsg = "test-funcvnet" + $test + "-nsg"
$akv = "test-funcvnet" + $test + "-akv"
$subnet = "azurefunction"
$addressrange = "10.200.0.0"

# create resource group
az group create -n $rg -l $loc

# create Storage account
az storage account create -n $funstor -g $rg --sku Standard_LRS

# create VNET
az network vnet create -g $rg -n $vnet --address-prefix $addressrange/16 -l $loc

# create NSG
az network nsg create -g $rg -n $nsg

# create rule allowing outbound to storage account WestEurope, port 443 and AzureCloud.WestEurope, and then block all outbound
az network nsg rule create -g $rg --nsg-name $nsg -n allow_we_stor_443 --priority 100 --source-address-prefixes VirtualNetwork --source-port-ranges '*' --destination-address-prefixes Storage.WestEurope --destination-port-ranges '443' --access Allow --protocol '*' --description "Allow storage West Europe 443" --direction Outbound
az network nsg rule create -g $rg --nsg-name $nsg -n allow_azure_internal --priority 110 --source-address-prefixes VirtualNetwork --source-port-ranges '*' --destination-address-prefixes AzureCloud.WestEurope --destination-port-ranges '*' --access Allow --protocol '*' --description "Allow Azure internal" --direction Outbound
#az network nsg rule create -g $rg --nsg-name $nsg -n allow_vnet_internal --priority 120 --source-address-prefixes VirtualNetwork --source-port-ranges '*' --destination-address-prefixes VirtualNetwork --destination-port-ranges '*' --access Allow --protocol '*' --description "Allow Azure internal" --direction Outbound
az network nsg rule create -g $rg --nsg-name $nsg -n deny_all_outbound --priority 130 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges '*' --access Deny --protocol '*' --description "Deny all outbound" --direction Outbound

# create subnet with NSG to VNET
az network vnet subnet create -g $rg --vnet-name $vnet -n $subnet --address-prefixes $addressrange/24 --network-security-group $nsg

# Turn on firewall
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $rg -Name $funstor -DefaultAction Deny

# Set service endpoints for storage and web app to subnet
Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet | Set-AzVirtualNetworkSubnetConfig -Name $subnet -AddressPrefix $addressrange/24 -ServiceEndpoint "Microsoft.Storage", "Microsoft.Web", "Microsoft.KeyVault" | Set-AzVirtualNetwork

# Add firewall rules to Storage Account
$subnetobject = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet | Get-AzVirtualNetworkSubnetConfig -Name $subnet
Add-AzStorageAccountNetworkRule -ResourceGroupName $rg -Name $funstor -VirtualNetworkResourceId $subnetobject.Id

# Create Azure Function
az appservice plan create -n $funplan -g $rg --sku P1v2 --is-linux
az functionapp create -g $rg --os-type Linux --plan $funplan --runtime python --name $funname --storage-account $funstor

# turn on Managed Identity of Azure Function
az webapp identity assign -g $rg -n $funname

# Add VNET integration
az webapp vnet-integration add -g $rg -n $funname --vnet $vnet --subnet $subnet

# To create Azure Function in Python, see https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-functions/functions-create-first-function-python.md
func init $funname --python
cd $funname
func new --name HttpTrigger --template "HTTP trigger"

# create key vault
az keyvault create --name $akv --resource-group $rg --location $loc

# set policy such that Azure Function can read from AKV
$objectid_funname = az functionapp identity show -n $funname -g $rg --query "principalId"
az keyvault set-policy -n $akv --secret-permissions set get list --object-id $objectid_funname

# set acl on key vault
az keyvault network-rule add -n $akv -g $rg --subnet $subnet --vnet-name $vnet

# get storage connection string and add to key vault
$storageconnectionstring = az storage account show-connection-string -n testfuncvnet7stor --query "connectionString"
$keyref = az keyvault secret set -n storageconnectionstring --vault-name $akv --value $storageconnectionstring --query "id"

# set app settings of function such that function retrieves function keys from AKV instead of storage account
az functionapp config appsettings set --name $funname --resource-group $rg --settings AzureWebJobsSecretStorageKeyVaultConnectionString="" AzureWebJobsSecretStorageKeyVaultName=$akv AzureWebJobsSecretStorageType="keyvault"

# set app settings of function such that storage keys are retrieved from AKV instead of app settings
az functionapp config appsettings set --name $funname --resource-group $rg --settings AzureWebJobsStorage="@Microsoft.KeyVault(SecretUri=$keyref)" AzureWebJobsDashboard="@Microsoft.KeyVault(SecretUri=$keyref)"

# upload code Azure Function
Start-Sleep -s 60
cd ..
cd $funname
func azure functionapp publish $funname

#done 
# get function key
#$urlResourceName = $funname + "/HttpTrigger"
#$function_key = Invoke-AzResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/Functions -ResourceName $urlResourceName -Action listkeys -ApiVersion 2015-08-01 -Force
