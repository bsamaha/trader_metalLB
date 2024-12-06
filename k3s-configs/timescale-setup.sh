#!/bin/bash

# Create namespace if it doesn't exist
if ! kubectl get namespace trading >/dev/null 2>&1; then
    echo "Creating trading namespace..."
    kubectl create namespace trading
fi

# Apply TimescaleDB configuration
echo "Deploying TimescaleDB..."
kubectl apply -f ./k3s-configs/timescaledb/timescale-setup.yaml

# Create TimescaleDB secrets
echo "Creating TimescaleDB secrets..."
TIMESCALEDB_PASSWORD=$(openssl rand -base64 32)
kubectl -n trading create secret generic timescaledb-secrets \
  --from-literal=password=$TIMESCALEDB_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ingestion service user secrets
echo "Creating ingestion service user secrets..."
INGESTION_PASSWORD=$(openssl rand -base64 32)
kubectl -n trading create secret generic timescaledb-ingestion-secrets \
  --from-literal=username=trading_ingestion \
  --from-literal=password=$INGESTION_PASSWORD \
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

# Deploy pgAdmin4
echo "Deploying pgAdmin4..."
kubectl apply -f ./k3s-configs/timescaledb/pgadmin4.yaml

# Wait for TimescaleDB pod to be ready
echo "Waiting for TimescaleDB pod to be ready..."
kubectl wait --for=condition=ready pod -l app=timescaledb -n trading --timeout=300s

# Get the pod name
TIMESCALE_POD=$(kubectl get pod -n trading -l app=timescaledb -o jsonpath="{.items[0].metadata.name}")

# Function to check if PostgreSQL is ready
check_postgres_ready() {
    kubectl exec -n trading $TIMESCALE_POD -- pg_isready -U postgres &>/dev/null
    return $?
}

# Function to check if TimescaleDB extension is ready
check_timescaledb_ready() {
    kubectl exec -n trading $TIMESCALE_POD -- psql -U postgres -c "SELECT extname FROM pg_extension WHERE extname = 'timescaledb';" | grep -q timescaledb
    return $?
}

# Wait for PostgreSQL to be ready with timeout
echo "Waiting for PostgreSQL to be ready..."
TIMEOUT=60
COUNTER=0
until check_postgres_ready; do
    if [ $COUNTER -eq $TIMEOUT ]; then
        echo "Timeout waiting for PostgreSQL to be ready"
        exit 1
    fi
    echo "Waiting for PostgreSQL to be ready... ($COUNTER/$TIMEOUT)"
    sleep 2
    ((COUNTER++))
done

# Wait for TimescaleDB extension to be ready
echo "Waiting for TimescaleDB extension to be ready..."
COUNTER=0
until check_timescaledb_ready; do
    if [ $COUNTER -eq $TIMEOUT ]; then
        echo "Timeout waiting for TimescaleDB extension to be ready"
        exit 1
    fi
    echo "Waiting for TimescaleDB extension to be ready... ($COUNTER/$TIMEOUT)"
    sleep 2
    ((COUNTER++))
done

# Copy schema file to the pod
echo "Copying schema to pod..."
kubectl cp ./k3s-configs/timescaledb/schema.sql trading/$TIMESCALE_POD:/tmp/schema.sql

# Apply schema with retries
echo "Applying database schema..."
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl exec -n trading $TIMESCALE_POD -- psql -U postgres -f /tmp/schema.sql; then
        echo "Schema applied successfully"
        break
    else
        ((RETRY_COUNT++))
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo "Failed to apply schema after $MAX_RETRIES attempts"
            exit 1
        fi
        echo "Failed to apply schema, retrying in 5 seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
        sleep 5
    fi
done

# Wait for pgAdmin pod to be ready with debugging
echo "Waiting for pgAdmin to be ready..."
kubectl wait --for=condition=ready pod -l app=pgadmin -n trading --timeout=120s || {
    echo "pgAdmin pod not ready, checking status..."
    kubectl describe pod -l app=pgadmin -n trading
    kubectl logs -l app=pgadmin -n trading
    echo "Failed to start pgAdmin, exiting..."
    exit 1
}

# Get service IPs
PGADMIN_IP=$(kubectl get svc pgadmin -n trading -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
TIMESCALEDB_PASSWORD=$(kubectl get secret -n trading timescaledb-secrets -o jsonpath="{.data.password}" | base64 --decode)

echo "Setup complete!"
echo "-------------------"
echo "pgAdmin is available at: http://$PGADMIN_IP"
echo "Login credentials:"
echo "  Email: admin@admin.com"
echo "  Password: pgadmin123"
echo ""
echo "TimescaleDB connection details:"
echo "  Host: timescaledb"
echo "  Port: 5432"
echo "  Database: trading"
echo "  Username: postgres"
echo "  Password: $TIMESCALEDB_PASSWORD"