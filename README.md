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

Run `kubectl get secret -n app`

![alt text](/media/secret-a.png)

## Describe secret

`kubectl describe secret -n app vault-secrets`

![alt text](/media/secret-b.png)

## Check sensetive values

`kubectl get secrets/vault-secrets -n app --template={{.data.password}} | base64 -d`

![alt text](/media/secret-d.png)

`kubectl get secrets/vault-secrets -n app --template={{.data.user}} | base64 -d`

![alt text](/media/secret-c.png)

## How it works

We configure `Vault` to use `kubernetes auth` with service accounts. To make `Vault` be able to check service account token in `TokenReviewAPI`  first we must create secret with token for service account `vault`(From kubernetes 1.24 service account created by kubectl hasn't token and user must create it manually).
Next we create policy and role to access our secret in Vault key-value store using proper service account `vault-auth`.

After install ESO(External Secret Operator) we create two CRD - one for connecting to `Vault` using service-account `vault-auth`(ClusterSecretStore) and one for sync secret from `Vault` to cluster(ExternalSecret). If all goes as planned we can see that secret `vault-secret` in namespace app contain our data from `Vault`.

## Bonus - Vault Injector

For inject Vault secret in pod we need to add special annotation:

```bash
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "webapp"
        vault.hashicorp.com/tls-skip-verify: "true"
        vault.hashicorp.com/agent-inject-secret-config: secret/config
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/config" -}}
          {{ .Data.data | toJSON }}
          {{- end }}
```

Last annotation configure templating - i choose simple JSON presentation

Run `./setup-injector.sh`

Check webapp using `curl`

Run `curl webapp.kind.cluster`

![alt text](/media/secret-e.png)
