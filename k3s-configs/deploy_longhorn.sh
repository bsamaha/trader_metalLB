#!/bin/bash

# Ensure LONGHORN_AUTH_STRING is set
if [ -z "$LONGHORN_AUTH_STRING" ]; then
    echo "LONGHORN_AUTH_STRING is not set. Please set it and run this script again."
    exit 1
fi

# Apply Longhorn using Helm with custom values
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace -f k3s-configs/longhorn/longhorn-values.yaml

# Wait for the CRDs to be established
echo "Waiting for Longhorn CRDs to be established..."
kubectl wait --for=condition=Established crd/volumes.longhorn.io crd/engines.longhorn.io crd/replicas.longhorn.io crd/settings.longhorn.io crd/engineimages.longhorn.io crd/nodes.longhorn.io crd/instancemanagers.longhorn.io --timeout=60s

# Create the auth secret
envsubst < k3s-configs/longhorn/longhorn-basic-auth-secret.yaml | kubectl apply -f -

# Apply the ingress
kubectl apply -f k3s-configs/longhorn/longhorn-ingress.yaml

# Apply the storage class
kubectl apply -f k3s-configs/longhorn/longhorn-storageclass.yaml

echo "Longhorn deployment completed."