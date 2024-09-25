k get secret -n app

k describe secret -n app vault-secrets

kubectl get secrets/vault-secrets -n app --template={{.data.password}} | base64 -d

kubectl get secrets/vault-secrets -n app --template={{.data.user}} | base64 -d

