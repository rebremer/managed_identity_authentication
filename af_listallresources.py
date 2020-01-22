import logging

import azure.functions as func
from msrestazure.azure_active_directory import MSIAuthentication
from azure.mgmt.resource import ResourceManagementClient

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    subscription_id = req_body.get('subscription_id')

    credentials = MSIAuthentication()    
    resource_client = ResourceManagementClient(credentials, subscription_id)
    output = ""
    for group in resource_client.resource_groups.list():
        if output == "":
            output = group.name        
        else:
            output += "\n" + group.name
        logging.info(str(group.name))

        for resource in resource_client.resources.list_by_resource_group(group.name):
            output += "\n   " + resource.name
            logging.info(str(resource.name))

    return func.HttpResponse(str(output))
