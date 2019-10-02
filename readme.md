### Authentication from Azure Data Factory to Azure Function using Managed Identity  ###

Architecture is depicted as follows:

![Architecture](https://github.com/rebremer/managed_identity_authentication/blob/master/images/Architecture.png)

This github expands on the following blog: https://joonasw.net/view/calling-your-apis-with-aad-msi-using-app-permissions

The following steps are executed:

1. Create app registration linked to the Azure Function
2. Add SPN of ADFv2 as authorized application to SPN of app registration
3. Grant SPN of Azure Function RBAC role "Strorage Blob Data Contributer
4. Configure Azure Function as REST API in ADFv2 using Managed Identity authentication

#### 1. Create app registration linked to the Azure Function ####

Follow the step in this [tutorial](https://docs.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad#-configure-with-express-settings "aad#-configure-with-express-settings"): Make sure you have the followin settings:

1. Choose at least the following App service plan: P1V2
2. Choose AAD with express settings as indicated in tutorial

#### 2. Add SPN of ADFv2 as authorized application to SPN of app registration ####

#### 3. Grant SPN of Azure Function RBAC role "Strorage Blob Data Contributer ####

#### 4. Configure Azure Function as REST API in ADFv2 using Managed Identity authentication ####