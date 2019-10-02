## AAD authentication from Data Factory to Azure Function using Managed Identity  ##

In this tutorial, AAD authentication from Data Factory to Azure Function is created. It extends the following [blog](https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions). The following steps are executed:

1. Create app registration linked to the Azure Function
2. Add SPN of ADFv2 as authorized application to SPN of app registration
3. Grant SPN of Azure Function RBAC role "Strorage Blob Data Contributer
4. Configure Azure Function as REST API in ADFv2 using Managed Identity authenticationArchitecture is depicted as follows:

Architecture is depicted below.

![Architecture](https://github.com/rebremer/managed_identity_authentication/blob/master/images/0_Architecture.png)

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
