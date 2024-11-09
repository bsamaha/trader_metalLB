#!/bin/bash

# Create namespace if it doesn't exist
if ! kubectl get namespace trading >/dev/null 2>&1; then
    echo "Creating trading namespace..."
    kubectl create namespace trading
fi

kubectl apply -f ./k3s-configs/timescaledb/timescale-setup.yaml

# Create TimescaleDB secrets
echo "Creating TimescaleDB secrets..."
kubectl -n trading create secret generic timescaledb-secrets \
  --from-literal=password=$(openssl rand -base64 32) \
  --dry-run=client -o yaml | kubectl apply -f -

# Validate Coinbase credentials
if [[ -z "${COINBASE_API_KEY_NAME}" ]]; then
    echo "Error: COINBASE_API_KEY_NAME not set"
    exit 1
fi

if [[ -z "${COINBASE_API_SECRET}" ]]; then
    echo "Error: COINBASE_API_SECRET not set"
    exit 1
fi

# Create Coinbase secrets
echo "Creating Coinbase API secrets..."
kubectl -n trading create secret generic coinbase-secrets \
  --from-literal=api-key="${COINBASE_API_KEY_NAME}" \
  --from-literal=api-secret="${COINBASE_API_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Wait for TimescaleDB pod to be ready
echo "Waiting for TimescaleDB to be ready..."
kubectl wait --for=condition=ready pod -l app=timescaledb -n trading --timeout=300s

# Forward TimescaleDB port
echo "Setting up port forward..."
kubectl port-forward -n trading svc/timescaledb 5432:5432 &
FORWARD_PID=$!

# Give the port forward a moment to establish
sleep 5

# Get password
PGPASSWORD=$(kubectl get secret -n trading timescaledb-secrets -o jsonpath="{.data.password}" | base64 --decode)

# Apply schema
echo "Applying database schema..."
PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -f timescaledb/schema.sql

# Clean up port forward
kill $FORWARD_PID

echo "Setup complete!"