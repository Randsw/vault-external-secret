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
