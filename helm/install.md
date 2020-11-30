NOTE: I'm including these files here because `helm install` of the tarballs provided in the repos for AAD Pod Identity and CSI Secrets Store Provider for Azure crap out. Also, the examples in this repo work with specific versions of these providers, so this ensures that the examples don't break.

Install CSI Secrets Store Provider v0.0.10 and AAD Pod Identity 01.7.0

```bash
kubectl create ns aad-pod-id
helm install aad-pod-identity aad-pod-identity-2.0.3.tar.gz -n aad-pod-id

kubectl create ns csi
helm install csi csi-secrets-store-provider-azure-0.0.14.tar.gz -n csi
```
