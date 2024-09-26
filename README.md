# Using Extrnal Secret Operator to sync secrets from Hashicorp Vault to kubernetes cluster

## Requirements

- docker
- kubectl
- kind cli
- helm
- vault cli

## Setup kubernetes cluster

Run `./cluster-setup.sh` and you got 1 control-plane nodes and 3 worker nodes kubernetes cluster with installed ingress-nginx, metallb and 4 proxy image repository in docker containers in one network

## Deploy Vault

Run `./setup-vault.sh`

## Deploy External Secret Operator

Run `./setup-external-secret-operator.sh`

## Check secret in app namespace

Run `k get secret -n app`

## Describe secret

`k describe secret -n app vault-secrets`

## Check sensetive values

`kubectl get secrets/vault-secrets -n app --template={{.data.password}} | base64 -d`

`kubectl get secrets/vault-secrets -n app --template={{.data.user}} | base64 -d`

## How it works

We configure `Vault` to use `kubernetes auth` with service accounts. To make `Vault` be able to check service account token in `TokenReviewAPI`  first we must create secret with token for service account `vault`(From kubernetes 1.24 service account created by kubectl hasn't token and user must create it manually).
Next we create policy and role to access our secret in Vault key-value store using proper service account `vault-auth`.

After install ESO(External Secret Operator) we create two CRD - one for connecting to `Vault` using service-account `vault-auth`(ClusterSecretStore) and one for sync secret from `Vault` to cluster(ExternalSecret). If all goes as planned we can see that secret `vault-secret` in namespace app contain our data from `Vault`.
