#!/bin/bash

./0-env_vars.sh

# ----------------------
# Login to Azure and set up kubectl
# ----------------------

az login -u $AZ_USERNAME -p $AZ_PASSWORD
az aks get-credentials --resource-group=$RESOURCE_GROUP --name=$AKS_CLUSTER_NAME --overwrite-existing

# ----------------------
# Install Secrets Store CSI Driver for Azure v0.0.10
# ----------------------

# Reference: https://github.com/Azure/secrets-store-csi-driver-provider-azure#azure-key-vault-provider-for-secrets-store-csi-driver
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts && helm repo update
kubectl create ns csi
helm install csi https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/charts/csi-secrets-store-provider-azure-0.0.14.tgz -n csi

# ----------------------
# Install Azure Pod Identity v1.7.0
# ----------------------

# Set up Pod Identity access to key vault
kubectl create ns aad-pod-id
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm install pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/blob/master/charts/aad-pod-identity-2.0.3.tgz -n aad-pod-id

# ----------------------
# Create Managed Identity
# ----------------------

# Create identity
export AZ_ID_NAME="aks-pod-identity"
export IDENTITY_DETAILS=$(az identity create --resource-group $RESOURCE_GROUP --name $AZ_ID_NAME --subscription $AZ_SUBSCRIPTION_ID)
export AZ_ID_CLIENT_ID=$(echo $IDENTITY_DETAILS | jq .clientId | tr -d '"')
export AZ_ID_RESOURCE_ID=$(echo $IDENTITY_DETAILS | jq .id | tr -d '"')
export AZ_ID_PRINCIPAL_ID=$(echo $IDENTITY_DETAILS | jq .principalId | tr -d '"')

export AKS_DETAILS=$(az aks show -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP)
export AKS_SP_PROFILE_CLIENT_ID=$(echo $AKS_DETAILS | jq .servicePrincipalProfile.clientId | tr -d '"')

export KV_ID=$(az keyvault show -n $KV_NAME --query id -o tsv)

# Role assignments
az role assignment create --role "Managed Identity Operator" --assignee $AKS_SP_PROFILE_CLIENT_ID --scope $AZ_ID_RESOURCE_ID
az role assignment create --role "Virtual Machine Contributor" --assignee $AKS_SP_PROFILE_CLIENT_ID --scope $AZ_ID_RESOURCE_ID

az role assignment create --role Reader --assignee $AZ_ID_PRINCIPAL_ID --scope $KV_ID

# Set policy to access kv secrets
az keyvault set-policy -n $KV_NAME --secret-permissions get --spn $AZ_ID_CLIENT_ID
