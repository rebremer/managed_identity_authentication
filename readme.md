## AAD authentication from Data Factory to Azure Function using Managed Identity  ##

Architecture is depicted as follows:

![Architecture](https://github.com/rebremer/managed_identity_authentication/blob/master/images/0_Architecture.png)

This github expands on the following [blog](https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions). The following steps are executed:

1. Create app registration linked to the Azure Function
2. Add SPN of ADFv2 as authorized application to SPN of app registration
3. Grant SPN of Azure Function RBAC role "Strorage Blob Data Contributer
4. Configure Azure Function as REST API in ADFv2 using Managed Identity authentication

### 1. Create app registration linked to the Azure Function ###

Follow the step in this [tutorial](https://docs.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad#-configure-with-express-settings "aad#-configure-with-express-settings"): Make sure that 1) App Service Plan: P1V2 is selected and 2) Choose AAD with express settings as indicated in tutorial. See also screenshots below how to turn:

![AAD Express Settings](https://github.com/rebremer/managed_identity_authentication/blob/master/images/1a1_AAD_Express_Option.png "1a1. AAD turned on using express settings")

Subsequently, the end situation of this step shall look as follows:

![AAD turned on](https://github.com/rebremer/managed_identity_authentication/blob/master/images/1a2_AAD_turned_on.png "1a2. AAD turned on using express settings")

### 2. Add SPN of ADFv2 as authorized application to SPN of app registration ###

The following steps need to be executed, see also [link](https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions) earlier:

a. Add app permission to manifest of app registration in step 1
b. Configure SPN of app registration with User assignment
c. Assign Managed Identity of ADFv2 as User to SPN of app registration

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

![Add app permission to manifest of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2a1_Manifest_app_permissions.png "2a1. Add app permission to manifest of app registrations")

#### 2b. Configure SPN of app registration with User assignment ####

In this step, the Managed Identity of ADFv2 will have permissions assigned to the SPN of the app registration that was created in step 1. Go to the app registration and click on "managed application in local directory", see also screenshot below:

![Look up SPN of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2b1_SPN_of_app_registration.png "2b1. Look up SPN of app registration")

Go to properties and set the "User Properties Assigned" option to yes. Also, look up the ObjectId of the SPN, this is needed in the next step.

![User Assignement and Object Id of SPN of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2b2_User_Assignment_Object_Id.png "2b2. User Assignement and Object Id of SPN of app registration")


#### 2c. Assign Managed Identity of ADFv2 as User to SPN of app registration ####

In this step, the Managed Identity of ADFv2 will be added as user to the SPN of the app registration. First of all, look up the ObjectID of the Managed Identity of Azure Data Factory. Go to Active Directory, Enterprise Applications and then type in the name of your ADFv2 instance.

Go to the app registration and click on "managed application in local directory", see also screenshot below:

![Find Object Id of SPN of ADFv2 instance](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2c1_ObjectID_MI_ADFv2.png "2c1. Object Id of SPN of ADFv2 instance")

Now run the following PowerShell script to Add the MSI of ADFv2 as user to the SPN of the app registration:



```PowerShell
Connect-AzureAD

New-AzureADServiceAppRoleAssignment -ObjectId <<step 2c, ObjectID of MSI assigned to Azure Data Factory instance>> -Id 32028ccd-3212-4f39-3212-beabd6787d81 -PrincipalId <<step 2c, ObjectID of MSI assigned to Azure Data Factory instance>> -ResourceId <<step 2b, ObjectID of SPN assigned to app registration>>

```

Go to the SPN of the app registration to verify that the Managed Identity of the ADFv2 is added, see also screenshot below.

![Managed Identity of ADFv2 added to SPN of app registration](https://github.com/rebremer/managed_identity_authentication/blob/master/images/2c2_Managed_Identity_ADFv2_added_to_SPN_of_app_registration.png "2c2. Managed Identity of ADFv2 added to SPN of app registration")

### 3. Grant SPN of Azure Function RBAC role "Strorage Blob Data Contributer ###

### 4. Configure Azure Function as REST API in ADFv2 using Managed Identity authentication ###