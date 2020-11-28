# Azure Keyvault Integration

[Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure#azure-key-vault-provider-for-secrets-store-csi-driver) was developed by Microsoft to allow for secure access of Azure KeyVault secrets from an AKS cluster.

It addresses a shortcoming with Kubernets `secrets` shortcoming, whereby they are only Base64-encoded, and can therefore be easily read.

Secrets Store CSI Driver provides seamless integration with Azure Keyvault, and allows you to access Kubernetes secrets via environment variables or as  volumes (more secure) mounted to your `Pod` or `Deployment`.
## Setup

1. Install Secrets Store CSI Driver for Azure v0.0.10 in Kubernetes

    The script below will install the latest version of the CRDs via Helm:

    ```bash
    helm repo add --insecure-skip-tls-verify csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts && helm repo update
    kubectl create ns csi
    helm --debug install --insecure-skip-tls-verify csi csi-secrets-store-provider-azure/csi-secrets-store-provider-azure -n csi
    ```

    Alternately, to install a specific version (i.e. v0.0.10) via Helm:

    ```bash
    kubectl create ns csi
    helm --debug install --insecure-skip-tls-verify csi https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/charts/csi-secrets-store-provider-azure-0.0.14.tgz -n csi
    ```

    **References:**
    * [Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure#azure-key-vault-provider-for-secrets-store-csi-driver)

2. Install Azure Pod Identity v1.7.0 in Kubernetes

    This allows us to use an Azure Managed Identity to authenticate from k8s to the Azure KeyVault.

    The script below will install the latest version of the CRDs via Helm:

    ```bash
    kubectl create ns aad-pod-id
    helm repo add --insecure-skip-tls-verify aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
    helm install --insecure-skip-tls-verify pod-identity aad-pod-identity/aad-pod-identity -n aad-pod-id
    ```

    Alternately, to install a specific version (i.e. v1.7.0) via Helm:

    ```bash
    kubectl create ns aad-pod-id
    helm --debug install --insecure-skip-tls-verify pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/blob/master/charts/aad-pod-identity-2.0.3.tgz -n aad-pod-id
    ```

    **References:**
    * [Secrets Store CSI Driver - Pod Identity](https://github.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/docs/pod-identity-mode.md)
    * [AAD Pod Identity](https://github.com/Azure/aad-pod-identity)
    * [Cloud IQ - Implementing Azure AD Pod Identity in AKS Cluster](https://www.cloudiqtech.com/implementing-azure-ad-pod-identity-in-aks-cluster/)
    * [Medium - Using AAD Pod Identity in an AKS Cluster](https://medium.com/@kimvisscher/using-aad-pod-identity-in-an-aks-cluster-117c08565692)
    * [Secrets Store CSI Driver with Pod Identity Tutorial](https://github.com/HoussemDellai/aks-keyvault)

3. Create the Managed Identity & Set Permissions

    Create an Azure Managed Identity. We need to give it the following permissions:
    * Permission to access our KeyVault
    * Permission to access the secrets in our KeyVault

    Since we have a Service Principal managing our cluster, we must also grant the Service Principal `Managed Identity Operator` and `Virtual Machine Contributor` roles.

    ```bash
    export AZ_ID_NAME="aks-pod-identity"
    export IDENTITY_DETAILS=$(az identity create --resource-group $RESOURCE_GROUP --name $AZ_ID_NAME --subscription $AZ_SUBSCRIPTION_ID)
    export AZ_ID_CLIENT_ID=$(echo $IDENTITY_DETAILS | jq .clientId | tr -d '"')
    export AZ_ID_RESOURCE_ID=$(echo $IDENTITY_DETAILS | jq .id | tr -d '"')
    export AZ_ID_PRINCIPAL_ID=$(echo $IDENTITY_DETAILS | jq .principalId | tr -d '"')
    ```

    Role assignments
    ```bash
    # Get Service Principal ID
    export AKS_DETAILS=$(az aks show -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP)
    export AKS_SP_PROFILE_CLIENT_ID=$(echo $AKS_DETAILS | jq .servicePrincipalProfile.clientId | tr -d '"')

    export KV_NAME="demo-kv"
    export KV_RESOURCE_GROUP="demo-rg"
    export KV_ID=$(az keyvault show -n $KV_NAME --query id -o tsv)

    # AKS Service Principal role assignments
    az role assignment create --role "Managed Identity Operator" --assignee $AKS_SP_PROFILE_CLIENT_ID --scope $AZ_ID_RESOURCE_ID
    az role assignment create --role "Virtual Machine Contributor" --assignee $AKS_SP_PROFILE_CLIENT_ID --scope $AZ_ID_RESOURCE_ID

    az role assignment create --role Reader --assignee $AZ_ID_PRINCIPAL_ID --scope $KV_ID

    # Set policy to allow the Managed Identity to access kv secrets
    az keyvault set-policy -n $KV_NAME --secret-permissions get --spn $AZ_ID_CLIENT_ID
    ```

4. Run our test

    We're creating an `AzureIdentity` and `AzureIdentityBinding` in the `default` namespace. All resources, regardless of namespace, will have
    access to these, which means that they can access secrets in our KeyVault.

    ```bash
    cd cluster_setup/azure_keyvault_2

    kubectl create ns az-keyvault-demo

    kubectl apply -f aadpodidentity-and-binding.yml
    kubectl apply -f secret-provider-class.yml
    kubectl apply -f 2048-game.yml

    kubectl get AzureAssignedIdentities

    sleep 60
    kubectl describe pods -n az-keyvault-demo

    kubectl -n az-keyvault-demo exec -it $(kubectl -n az-keyvault-demo get pods -o jsonpath='{.items[0].metadata.name}') -- ls /mnt/secrets-store
    ```

    If we're successful, `kubectl get AzureAssignedIdentities` will return results.

## Config Files Explained

There are 3 resources which make all this work:
* `AzureIdentity`
* `AzureIdentityBinding`
* `SecretProviderClass`

### AzureIdentity

The `AzureIdentity` resource was created as part of the [Azure Pod Identity](https://github.com/Azure/aad-pod-identity) installation in Step 2. It references the Azure Managed Identity created via `az identity create` in Step 3.

Sample:

```yaml
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: demo-kv-az-id
spec:
  type: 0
  # Managed identity resource ID
  resourceID: <managed_identity_resource_id>
  # Managed identity clientID
  clientID: <managed_identity_client_id>

```

The `resourceID` field references the `id` field of the Managed Identity created above. Get the `id` by running the command below:

```bash
az identity show --resource-group $RESOURCE_GROUP --name $AZ_ID_NAME --query id -o tsv
```

The `clientID` field references the `clientId` field of the Managed Identity created above. Get the `clientId` by running the command below:

```bash
az identity show --resource-group $RESOURCE_GROUP --name $AZ_ID_NAME --query clientId -o tsv
```

### AzureIdentityBinding

The `AzureIdentityBinding` resource was created as part of the [Azure Pod Identity](https://github.com/Azure/aad-pod-identity) installation in Step 2. It references the Azure Managed Identity created via `az identity create` in Step 3.

It serves to glue to bind the `AzureIdentity` to a `Pod` or `Deployment`. This is done via the `selector` field. This field is refernced as a label in a `Pod` or `Deployment`'s definition.

Sample:

```yaml
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: demo-kv-az-id-binding
spec:
  azureIdentity: demo-kv-az-id
  selector: pod-id-binding
```

The `azureIdentity` field refers to the name given to the `AzureIdentity`

The `selector` field can be whatever you want; however, the same value must be referenced in your `Pod` or `Deployment` definition as a label.

For example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: "2048-deployment"
namespace: az-keyvault-demo
labels:
    aadpodidbinding: pod-id-binding
spec:
...
template:
    metadata:
    labels:
        app: "2048"
        aadpodidbinding: pod-id-binding
...
```

Note how `pod-id-binding` in the label `aadpodidbinding: pod-id-binding` of the `Deployment` definition matches the value of the `selector` field in the `AzureIdentityBinding` definition.

## SecretProviderClass

The `SecretProviderClass` resource was created as part of the [Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure) installation.

It references your KeyVault, and exposes the keys, secrets, and certificates that you want to expose.

Sample:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: secret-provider-kv
  namespace: az-keyvault-demo
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    useVMManagedIdentity: "false"
    userAssignedIdentityID: ""
    keyvaultName: "demo-kv"
    cloudName: AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: secret2
          objectType: secret
    resourceGroup: "demo-rg"
    subscriptionId: <azure_subscription_id>
    tenantId: <azure_tenant_id>
```

The `usePodIdentity` field must be true so that `SecretProviderClass` can use the Azure Managed Identity (created in Step 3 and referenced in the `AzureIdentity` spec) to give Kubernetes access to the KeyVault.

The `useVMManagedIdentity` and `userAsignedIdentityID` must bhe `false` and `""`, respectively.

Additional Fields:
* `keyvaultName` is the name of the KeyVault being accessed.
* `resourceGroup` is the name in which the KeyVault resides
* `subscriptionId` is the KeyVault's subscription ID
* `tenantId` is the Azure Tenant ID
* `objects` lists the secrets/keys/certificates from the specified KeyVault in `keyvaultName` to be made available to the `Pod` or `Deployment`.

The `Pod` or `Deployment` in turn access the secrets by mounting them as volumes, like this:

Sample deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "2048-deployment"
  namespace: az-keyvault-demo
  labels:
    aadpodidbinding: pod-id-binding
spec:
  replicas: 1
  selector:
    matchLabels:
      app: "2048"
  template:
    metadata:
      labels:
        app: "2048"
        aadpodidbinding: pod-id-binding
        version: v1
    spec:
      containers:
      - image: alexwhen/docker-2048
        imagePullPolicy: Always
        name: "2048"
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secrets-store-inline
          mountPath: "/mnt/secrets-store"
          readOnly: true
        env:
          - name: KUBERNETES_SERVICE_HOST
            value: k8spoc-aks
      volumes:
        - name: secrets-store-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "secret-provider-kv"

```

The `volumeMount` references a volume called `secrets-store-inline`, which is defined in the `volumes.name` section. The `secretProviderClass` value matches the name in the `SecretProviderClass` definition above.