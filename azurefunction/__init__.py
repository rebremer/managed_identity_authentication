# azure-functions
# azure-storage-blob==2.0.1
# msrestazure

import logging

import azure.functions as func
from msrestazure.azure_active_directory import MSIAuthentication
from azure.storage.blob import (
    AppendBlobService,
    BlockBlobService,
    BlobPermissions,
    ContainerPermissions
)

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')

    credentials = MSIAuthentication(resource='https://storage.azure.com/')    
    blob_service = BlockBlobService("blogfuncsec3stor", token_credential=credentials)
    blob_service.create_blob_from_text("testrb", "model.json", "{'test':'rene'}")
    result = {"status": "ok"}

    return func.HttpResponse(str(result))
