#!/bin/sh

cd demo

kubectl create ns az-keyvault-demo

kubectl apply -f aadpodidentity-and-binding.yml
kubectl apply -f secret-provider-class.yml
kubectl apply -f 2048-game.yml

# If creation of AzureIdentity and AzureIdentityBinding is successful, we'll see entries here
kubectl get AzureAssignedIdentities

sleep 60
kubectl describe pods -n az-keyvault-demo

kubectl -n az-keyvault-demo exec -it $(kubectl -n az-keyvault-demo get pods -o jsonpath='{.items[0].metadata.name}') -- ls /mnt/secrets-store
