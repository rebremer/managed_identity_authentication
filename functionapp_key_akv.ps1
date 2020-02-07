$test = "4"

$rg = "test-funcvnet" + $test + "-rg"
$loc = "westeurope"
$funname = "test-funcvnet" + $test + "-func"
$funstor = "testfuncvnet" + $test + "stor"
$funplan = "test-funcvnet" + $test + "-plan"

# create resource group
az group create -n $rg -l $loc

# create Storage account
az storage account create -n $funstor -g $rg --sku Standard_LRS

# create Azure Function
az appservice plan create -n $funplan -g $rg --sku P1v2 --is-linux
az functionapp create -g $rg --os-type Linux --plan $funplan --runtime python --name $funname --storage-account $funstor

# turn on Managed Identity of Azure Function
az webapp identity assign -g $rg -n $funname

# create Azure Function with HTTP trigger in Python, see https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/azure-functions/functions-create-first-function-python.md
func init $funname --python
cd $funname
func new --name HttpTrigger --template "HTTP trigger"

# create key vault
az keyvault create --name $akv --resource-group $rg --location $loc

# set policy such that Azure Function can read from AKV
$objectid_funname = az functionapp identity show -n $funname -g $rg --query "principalId"
az keyvault set-policy -n $akv --secret-permissions set get list --object-id $objectid_funname

# set app settings of function such that function retrieves keys from AKV instead of stor
az functionapp config appsettings set --name $funname --resource-group $rg --settings AzureWebJobsSecretStorageKeyVaultConnectionString="" AzureWebJobsSecretStorageKeyVaultName=$akv AzureWebJobsSecretStorageType="keyvault"

# upload code Azure Function
Start-Sleep -s 60
cd ..
cd $funname
func azure functionapp publish $funname

#done 
# get function key
#$urlResourceName = $funname + "/HttpTrigger"
#$function_key = Invoke-AzResourceAction -ResourceGroupName $rg -ResourceType Microsoft.Web/sites/Functions -ResourceName $urlResourceName -Action listkeys -ApiVersion 2015-08-01 -Force
