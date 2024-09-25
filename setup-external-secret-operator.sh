#!/usr/bin/env bash

set -e

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

log "External Secret Operator ..."

helm upgrade --install --wait --timeout 35m --atomic --namespace external-secrets --create-namespace \
    --repo https://charts.external-secrets.io external-secrets external-secrets --set installCRDs=true


cat << EOF | kubectl apply -f -
 apiVersion: external-secrets.io/v1beta1
 kind: ClusterSecretStore
 metadata:
   name: vault-backend
   spec:
     provider:
       vault:
         server: "http://vault.vault.svc:8200"
         path: "secret"
         version: "v2"
         auth:
           kubernetes:
             mountPath: "kubernetes"
             role: "eso"
             serviceAccountRef:
               name: "vault-auth" # имя нашего serviceAccount
               namespace: vault
EOF


cat << EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app
  namespace: app
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: vault-secrets # имя будущего секрета kubernetes
  data:
    - secretKey: user # ключ секрета
      remoteRef:
        key: webapp/config # путь до секрета в vault
        property: username # ключ секрета в vault
    - secretKey: password
      remoteRef:
        key: webapp/config
        property: password
EOF

