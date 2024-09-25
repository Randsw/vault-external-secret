#!/usr/bin/env bash

set -e

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

wait_ready(){
  local NAME=${1:-pods}
  local TIMEOUT=${2:-5m}
  local SELECTOR=${3:---all}

  log "WAIT $NAME ($TIMEOUT) ..."

  kubectl wait -A --timeout=$TIMEOUT --for=condition=ready $NAME $SELECTOR
}

wait_pods_ready(){
  local TIMEOUT=${1:-5m}

  wait_ready pods $TIMEOUT --field-selector=status.phase!=Succeeded
}

  log "Vault ..."

  helm upgrade --install --wait --timeout 35m --atomic --namespace vault --create-namespace \
    --repo https://helm.releases.hashicorp.com vault vault --values - <<EOF
server:
  ha:
    enabled: true
    raft: 
      enabled: true
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - host: vault.kind.cluster
        paths: 
        - /
EOF

sleep 30

kubectl exec vault-0 -n vault -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > cluster-keys.json

cat cluster-keys.json

VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)

kubectl exec vault-0 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec -ti vault-1 -n vault -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -ti vault-2 -n vault -- vault operator raft join http://vault-0.vault-internal:8200

kubectl exec -ti vault-1 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec -ti vault-2 -n vault -- vault operator unseal $VAULT_UNSEAL_KEY

VAULT_ROOT_TOKEN=$(jq -r ".root_token" cluster-keys.json)

export VAULT_ADDR=http://vault.kind.cluster

sleep 30

vault login $VAULT_ROOT_TOKEN

vault secrets enable -path=secret kv-v2

vault kv put -mount=secret config username="static-user" password="static-password"

vault kv get -mount=secret config

vault auth enable kubernetes

vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443"

vault policy write eso - <<EOF
path "secret/*" {
    capabilities = ["read", "list"]
}

path "auth/token/renew-self" {
    capabilities = ["update"]
}
EOF

vault write auth/kubernetes/role/webapp \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=vault \
        policies=eso \
        ttl=24h

kubectl create serviceaccount vault-auth -n vault


cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: vault
  name: vault-auth
  annotations:
    kubernetes.io/service-account.name: "vault-auth"
type: kubernetes.io/service-account-token
EOF

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: vault
  name: vault
  annotations:
    kubernetes.io/service-account.name: "vault"
type: kubernetes.io/service-account-token
EOF

cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
   name: role-tokenreview-binding
   namespace: vault
roleRef:
   apiGroup: rbac.authorization.k8s.io
   kind: ClusterRole
   name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault
  namespace: vault
EOF
