#!/usr/bin/env bash

set -e

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

log "Setup app that use Vault injector ..."

# Create ns for app
kubectl create namespace app || true

# Create service account for role
kubectl create serviceaccount webapp-auth -n app || true

# Add secret to service account vault-auth (from kubernetes 1.24 service account created without tokens)
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  namespace: app
  name: webapp-auth
  annotations:
    kubernetes.io/service-account.name: "webapp-auth"
type: kubernetes.io/service-account-token
EOF

# Add deployment
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
  namespace: app
spec:
  selector:
    matchLabels:
      app: webapp
  replicas: 1
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "webapp"
        vault.hashicorp.com/tls-skip-verify: "true"
        vault.hashicorp.com/agent-inject-secret-config: secret/config
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/config" -}}
          {{ .Data.data | toJSON }}
          {{- end }}
      labels:
        app: webapp
    spec:
      serviceAccountName: webapp-auth
      automountServiceAccountToken: true
      containers:
      - name: webapp
        image: dengelhardt1/alpine-curl-non-root:v1.0.0
        command:
          - /bin/sh
          - -c
        args:
          - |
            cat /vault/secrets/config
            while true;do sleep 1;done
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          privileged: false
          seccompProfile:
            type: RuntimeDefault
EOF

# Add service to access web app
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
  namespace: app
spec:
  selector:
    app: webapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
EOF

# Add ingress to access web app
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: app
spec:
  ingressClassName: nginx
  rules:
    - host: "foo.bar.com"
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: webapp-service
              port:
                number: 80
EOF

