## AAD authentication from ADFv2 to Azure Function using Managed Identity  ##

Executing an Azure Function from an Azure Data Factory (ADFv2) pipeline is popular pattern. In every ADFv2 pipeline, security is an
important topic. In this tutorial, the following security aspects are discussed:

- Enable AAD authentication in Azure Function
- Add Managed Identity of ADfv2 instance as user that can access Azure Function
- Grant Managed of Azure Function RBAC roles to access other resources
- Add network isolation of Azure Function, use Self-hosted Integrated Runtime to call Azure Function from ADFv2
- Add firewall rule to storage account, such that only Azure Function VNET can access ADLS gen2 account

It extends the following [blog](https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions). The following steps are executed:

1. Create app registration linked to the Azure Function
2. Add SPN of ADFv2 as authorized application to SPN of app registration
3. Grant SPN of Azure Function RBAC role "Storage Blob Data Contributor"
4. Configure Azure Function as REST API in ADFv2 using Managed Identity authentication
5. (Network isolation only) Create VNET and self-hosted integration runtime
6. (Network isolation only) Run Azure Function with VNET from ADFv2
7. (Network isolation only) Add firewall rule to ADLSgen2 account with VNET of Azure Function

Architecture is depicted below.

![Architecture](https://github.com/rebremer/managed_identity_authentication/blob/master/images/0_Architecture.png "Architecture")

### 1. Create app registration linked to the Azure Function ###

The following steps need to be executed:

- 1a. Create app registration
- 1b. Verify that AAD authentication is turned on for Azure Function

#### 1a. Create app registration ####

Go to your Azure Function in the Portal, select "PlatForm Features", then "All Settings" and then "Authentication/Authorization". Then follow the steps in this [tutorial](https://docs.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad#-configure-with-express-settings "aad#-configure-with-express-settings"). In this, make sure that 1)App Service Plan, P1V2 is selected and 2) AAD with express settings as indicated in tutorial. See also below.

![1a1. AAD Express Settings](https://github.com/rebremer/managed_identity_authentication/blob/master/images/1a1_AAD_Express_Option.png "1a1. AAD turned on using express settings")

#### 1b. Verify that AAD authentication is turned on for Azure Function ####

Again, go to your Azure Function in the Portal, select "PlatForm Features", then "All Settings" and then "Authentication/Authorization" and verify that AAD is turned on, see also below. 

![1b1. AAD turned on](https://github.com/rebremer/managed_identity_authentication/blob/master/images/1b1_AAD_turned_on.png "1b1. AAD turned on using express settings")

### 2. Add SPN of ADFv2 as authorized application to SPN of app registration ###

The following steps need to be executed, see also [link](https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions) earlier:

- 2a. Add app permission to manifest of app registration in step 1
- 2b. Configure SPN of app registration with User assignment
- 2c. Assign Managed Identity of ADFv2 as User to SPN of app registration

#### 2a. Add app permission to manifest of app registration in step 1 ####

Go to the manifest of the app registration in step 1 and add the following manifest. Nb, you can create your own GUID as ID, you will need it in step 2b.

```json
    "appRoles": [
        {
            "allowedMemberTypes": [
                "Application"
            ],
            "displayName": "Allow MSI SPN of ADFv2 to authenticate to Azure Function using its MSI",
            "id": "32028ccd-3212-4f39-3212-beabd6787d81",
            "isEnabled": true,
            "description": "Allow MSI SPN of ADFv2 to authenticate to Azure Function using its MSI",
            "value": "Things.Read.All"
        }
    ],

```

See also screenshot below:

![2a1. Add app permission to manifest of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2a1_Manifest_app_permissions.png "2a1. Add app permission to manifest of app registrations")

#### 2b. Configure SPN of app registration with User assignment ####

In this step, the Managed Identity of ADFv2 will have permissions assigned to the SPN of the app registration that was created in step 1. Go to the app registration and click on "managed application in local directory", see also screenshot below:

![2b1. Look up SPN of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2b1_SPN_of_app_registration.png "2b1. Look up SPN of app registration")

Go to properties and set the "User Properties Assigned" option to yes. Also, look up the ObjectId of the SPN, this is needed in the next step.

![2b2. User Assignement and Object Id of SPN of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2b2_User_Assignment_Object_Id.png "2b2. User Assignement and Object Id of SPN of app registration")

#### 2c. Assign Managed Identity of ADFv2 as User to SPN of app registration ####

In this step, the Managed Identity of ADFv2 will be added as user to the SPN of the app registration. First of all, look up the ObjectID of the Managed Identity of Azure Data Factory. Go to Active Directory, Enterprise Applications and then type in the name of your ADFv2 instance.

Go to the app registration and click on "managed application in local directory", see also screenshot below:

![2c1. Find Object Id of SPN of ADFv2 instance](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2c1_ObjectID_MI_ADFv2.png "2c1. Object Id of SPN of ADFv2 instance")

Now run the following PowerShell script to Add the MSI of ADFv2 as user to the SPN of the app registration:

```PowerShell
Connect-AzureAD

New-AzureADServiceAppRoleAssignment -ObjectId <<step 2c, ObjectID of MSI assigned to Azure Data Factory instance>> -Id 32028ccd-3212-4f39-3212-beabd6787d81 -PrincipalId <<step 2c, ObjectID of MSI assigned to Azure Data Factory instance>> -ResourceId <<step 2b, ObjectID of SPN assigned to app registration>>

```

Go to the SPN of the app registration to verify that the Managed Identity of the ADFv2 is added, see also screenshot below.

![2c2. Managed Identity of ADFv2 added to SPN of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2c2_Managed_Identity_ADFv2_added_to_SPN_of_app_registration.png "2c2. Managed Identity of ADFv2 added to SPN of app registration")

### 3. Grant SPN of Azure Function RBAC role "Storage Blob Data Contributer" ###

The following steps need to be executed, see also [link](https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions) earlier:

- 3a. Turn on Identity of Azure Function
- 3b. Assign SPN of Azure Function RBAC role "Storage Blob Data Contributor"

#### 3a. Turn on Identity of Azure Function ####

Go to your Azure Function in the Portal, select "PlatForm Features", then "All Settings" and then select "Identity" and then turn on. See also below.

![3a1. Turn on Identity of Azure Function](https://github.com/rebremer/managed_identity_authentication/blob/master/images/3a1_Turn_on_Identity_Azure_Function.png "3a1. Turn on Identity of Azure Function")


#### 3b. Assign SPN of Azure Function RBAC role "Storage Blob Data Contributor" ####

Go to your Storage Account in the Portal, select "PlatForm Features", then "All Settings" and then select "Identity" and then turn on. See also below.

![3b1. Added Managed Identity of Azure Function RBAC role \"Storage Blob Data Contributor\"](https://github.com/rebremer/managed_identity_authentication/blob/master/images/3b1_Managed_Identity_Azure_Function_ADLSgen2.png "3b1. Added Managed Identity of Azure Function RBAC role \"Storage Blob Data Contributor\"")

### 4. Configure Azure Function as REST API in ADFv2 using Managed Identity authentication ###

The following steps need to be executed:

- 4a. Get Function URL
- 4b. Run pipeline with Azure Function as REST API

#### 4a. Get Function URL ####

Go to your Azure Function, click on your trigger and then select "Get Function URL", see also below.

![4a1. Get URL of Function\"](https://github.com/rebremer/managed_identity_authentication/blob/master/images/4a1_get_Function_URL.png "4a1. Get URL of Function")

#### 4b. Run pipeline with Azure Function as REST API ####

Go to your Azure Data Factory, select your pipeline and deploy the Azure Data Factory described in this [tutorial](https://towardsdatascience.com/how-to-add-metadata-to-your-azure-data-lake-f8ec2022f50). Subsequently, delete the Azure Function from this pipeline and replace it with a web App. Then fill in the URL retrieved in step 4a and fill in MSI as authentication. Also, fill in the base URL as resource in the authentication. See also below.

![4b1. Add web app to ADFv2 pipeline](https://github.com/rebremer/managed_identity_authentication/blob/master/images/4b1_Add_webapp_to_ADFv2_pipeline.png "4b1. Add web app to ADFv2 pipeline")

### 5. (Network isolation only) Create VNET and self-hosted integration runtime ###

The following steps need to be executed:

- 5a. Create VNET
- 5b. Create self-hosted integration runtime in VNET

#### 5a. Create VNET ####

Go to the Azure Portal and create a VNET using [this tutorial](https://docs.microsoft.com/en-us/azure/virtual-network/quick-create-portal). One subnet is sufficient. Subsequently, go to your VNET, select Service Endpoints and add Microsoft.Web as allowed service endpoint, see also below.

![5a1. Microsoft.Web as allowed service endpoint](https://github.com/rebremer/managed_identity_authentication/blob/master/images/5a1_Microsoft_web_service_endpoint.png "5a1. Microsoft.Web as allowed service endpoint")


#### 5b. Create self-hosted integration runtime in VNET ####

Create a self-hosted integration runtime by using [this template](https://github.com/Azure/azure-quickstart-templates/tree/master/101-vms-with-selfhost-integration-runtime). Fill in all parameters, make sure that you have at least two nodes. It can take 10 minutes before the self-hosted integrated runtime is up and runtime. You can verify this by going to your Azure Data Factory instance, going to Connections, linked services and then look up your runtimes, see also below.

![5b1. Verify that self-hosted integration runtime is up and running](https://github.com/rebremer/managed_identity_authentication/blob/master/images/5b1_Check_self_hosted_integration_runtime.png "5b1. Verify that self-hosted integration runtime is up and running")

### 6. (Network isolation only) Run Azure Function with VNET from ADFv2 ###

The following steps need to be executed:

- 6a. Add VNET as firewall rule to Azure Function
- 6b. Create REST API linked service
- 6c. Create Copy Activity and Run Azure pipeline

#### 6a. Add VNET as firewall rule to Azure Function ####

Go to your Azure Function, click on "Platform Features" and then "Networking". Subsequently, choose "Configure Access Restrictions" and add the VNET and subnet in which the self-hosted integration runtime is deployed, see also below. Alternatively, you can also whitelist the public IP addresses of the VMs on which the self-hosted integration runtime runs.

![6a1. Firewall rule subnet Azure function](https://github.com/rebremer/managed_identity_authentication/blob/master/images/6a1_Firewall_rule_subnet_Azure_function.png "6a1. Firewall rule subnet Azure function")

#### 6b. Create REST API linked service ####

In part 5 of this tutorial a Web Activity was used to call the Azure Function with managed Identity. However, a Web Activity can only be used with public endpoints, see [this link](https://docs.microsoft.com/en-us/azure/data-factory/control-flow-web-activity). Therefore, a linked service REST API is created that can be used with the Azure Function protected with firewall rules. Go to your ADFv2 instance, select linked services and then REST API. Subsequently, fill in the parameters similar as was done in step 4. Make sure that you select your self-hosted integration runtime created in 5b as integration runtime, see also below.

![6b1. Create REST API Azure Function SHIR](https://github.com/rebremer/managed_identity_authentication/blob/master/images/6b1_Create_REST_API_Azure_Function_SHIR.png "6b1. Create REST API Azure Function SHIR")

#### 6c. Create Copy Activity and Run Azure pipeline ####

Linked Service REST API is normally used in copy activity to fetch data from an external system. However, it now used to call an Azure Function. Therefore, the linked service created in 6b is addes as source in Copy Activity Destination in copy activity only created a dummy file. Pipeline can be found in [this github repo](https://github.com/rebremer/adfv2_cdm_metadata/blob/master/pipeline/BlogMetadataRESTMSIVnet.json), see also below.

![6c1. Azure Function with VNET in ADFv2 pipeline](https://github.com/rebremer/managed_identity_authentication/blob/master/images/6c1_Azure_Function_VNET_ADFv2_pipeline.png "6c1. Azure Function with VNET in ADFv2 pipeline")


### 7. (Network isolation only) Add firewall rule to ADLSgen2 account with VNET of Azure Function ###

The following steps need to be executed:

- 7a. Add VNet Integration to Azure Function
- 7b. Add VNET as firewall rule to ADLS gen2

#### 7a. Add VNet Integration to Azure Function ####

Go to your Azure Function, click on "Platform Features" and then "Networking". Subsequently, choose "VNET integration". Subsequently, add the VNET and subnet. Make sure that a different subnet is choosen in which the SHIR of step 6a runs, see also below.

![7a1. Azure Function VNET Integration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/7a1_Azure_Function_VNET_Integration.png "7a1. Azure Function VNET Integration")

Make sure that Service Endpoint "Storage" and Web is enabled for subnet, see also below.

![7a2. Service Endpoints](https://github.com/rebremer/managed_identity_authentication/blob/master/images/7a2_subnet_service_endpoint.png "7a2. Service Endpoints")

#### 7b. Add VNET as firewall rule to ADLS gen2 ####

Go to your ADLS gen2 account, click on "Firewalls and virtual networks" and then add the VNET/subnet in which the Azure function is integrated in step 7a". Subsequently, also select "Allow trusted Microsoft Services to access this storage account" such that ADFv2 can also access the storage account (e.g. for copy activities), see also below.

![7b1. Firewall rule subnet Azure function](https://github.com/rebremer/managed_identity_authentication/blob/master/images/7b1_Firewall_rule_subnet_ADLSgen2.png "7b1. Firewall rule subnet Azure functions")


