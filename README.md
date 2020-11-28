# Azure Keyvault Integration

[Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure#azure-key-vault-provider-for-secrets-store-csi-driver) was developed by Microsoft to allow for secure access of Azure KeyVault secrets from an AKS cluster.

It addresses a shortcoming with Kubernets `secrets`, whereby they are only Base64-encoded, and can therefore be easily read.

Secrets Store CSI Driver provides seamless integration with Azure Keyvault, and allows you to access Kubernetes secrets via environment variables or as  volumes (more secure) mounted to your `Pod`.

Be sure to check out my [blog post on Medium](https://medium.com/dzerolabs/kubernetes-saved-today-f-cked-tomorrow-a-rant-azure-key-vault-secrets-à-la-kubernetes-fc3be5e65d18) for more details on this setup.
## Setup

1. Set up the environment variables

  Fill out the values in `scripts/0-env_vars.sh`

2. Create the demo Key Vault in Azure

  ```bash
  ./scripts/1-keyvault_creation.sh
  ```

3. Install Secrets Store CSI Driver for Azure v0.0.10 and Azure Pod Identity v1.7.0 in your Kubernetes cluster

  ```bash
  ./scripts/2-aks_setup.sh
  ```

4. Deploy the Kubernetes manifests

  Be sure to edit `aadpodidentity-and-binding.yml` and `secret-provider-class.yml` before applying the changes to Kubernetes.


## References

* [Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure#azure-key-vault-provider-for-secrets-store-csi-driver)
* [Secrets Store CSI Driver - Pod Identity](https://github.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/docs/pod-identity-mode.md)
* [AAD Pod Identity](https://github.com/Azure/aad-pod-identity)
* [Cloud IQ - Implementing Azure AD Pod Identity in AKS Cluster](https://www.cloudiqtech.com/implementing-azure-ad-pod-identity-in-aks-cluster/)
* [Medium - Using AAD Pod Identity in an AKS Cluster](https://medium.com/@kimvisscher/using-aad-pod-identity-in-an-aks-cluster-117c08565692)
* [Secrets Store CSI Driver with Pod Identity Tutorial](https://github.com/HoussemDellai/aks-keyvault)
