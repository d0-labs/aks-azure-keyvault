#!/bin/bash

./0-env_vars.sh

export LOCATION="eastus2"

az login -u $AZ_USERNAME -p $AZPASSWORD && az account set --subscription $AZ_SUBSCRIPTION_ID

# Create resource group
az group create --name $KV_RESOURCE_GROUP --location $LOCATION

# Create keyvault
az keyvault create --name $KV_NAME --location $LOCATION --resource-group $KV_RESOURCE_GROUP

# Set access policy
az keyvault set-policy --upn $AZ_USERNAME --name $KV_NAME --resource-group $KV_RESOURCE_GROUP --key-permissions get list create delete encrypt decrypt --secret-permissions get list set delete

# Set secrets
# az keyvault secret set --vault-name $KV_NAME --name "$SP_USERID" --value "$SP_PASSWORD"
az keyvault secret set --vault-name $KV_NAME --name captain-name --value "Picard"
az keyvault secret set --vault-name $KV_NAME --name ship-name --value "USS Enterprise"
