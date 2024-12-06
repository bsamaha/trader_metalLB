#!/bin/bash

# Create namespace if it doesn't exist
if ! kubectl get namespace trading >/dev/null 2>&1; then
    echo "Creating trading namespace..."
    kubectl create namespace trading
fi

# Create TimescaleDB secrets
echo "Creating TimescaleDB secrets..."
TIMESCALEDB_PASSWORD=$(openssl rand -base64 32)
kubectl -n trading create secret generic timescaledb-secrets \
  --from-literal=password=$TIMESCALEDB_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Create service user secrets
echo "Creating service user secrets..."
SERVICE_PASSWORD=$(openssl rand -base64 32)
kubectl -n trading create secret generic timescaledb-service-secrets \
  --from-literal=username=trading_service \
  --from-literal=password=$SERVICE_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Create pgAdmin secrets
echo "Creating pgAdmin secrets..."
kubectl -n trading create secret generic pgadmin-secret \
  --from-literal=admin-email=admin@admin.com \
  --from-literal=admin-password=pgadmin123 \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply TimescaleDB and pgAdmin configuration
echo "Deploying TimescaleDB and pgAdmin..."
kubectl apply -f ./k3s-configs/timescaledb/timescale-setup.yaml

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

# Copy schema file to the pod
echo "Copying schema to pod..."
kubectl cp ./k3s-configs/timescaledb/schema.sql trading/$TIMESCALE_POD:/tmp/schema.sql

# Apply schema with retries
echo "Applying database schema..."
MAX_RETRIES=5
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if kubectl exec -n trading $TIMESCALE_POD -- psql -U postgres \
        -v SERVICE_PASSWORD="'$SERVICE_PASSWORD'" \
        -f /tmp/schema.sql; then
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

# Wait for pgAdmin pod to be ready
echo "Waiting for pgAdmin to be ready..."
kubectl wait --for=condition=ready pod -l app=psql -n trading --timeout=300s

# Function to check if pgAdmin is accessible
check_pgadmin_ready() {
    PGADMIN_POD=$(kubectl get pod -n trading -l app=psql -o jsonpath="{.items[0].metadata.name}")
    kubectl exec -n trading $PGADMIN_POD -- curl -s http://localhost:80/misc/ping &>/dev/null
    return $?
}

# Wait for pgAdmin to be fully ready
echo "Waiting for pgAdmin service to be accessible..."
TIMEOUT=30
COUNTER=0
until check_pgadmin_ready; do
    if [ $COUNTER -eq $TIMEOUT ]; then
        echo "Timeout waiting for pgAdmin to be accessible"
        exit 1
    fi
    echo "Waiting for pgAdmin to be accessible... ($COUNTER/$TIMEOUT)"
    sleep 1
    ((COUNTER++))
done

# Get service IPs
PGADMIN_IP=$(kubectl get svc psql -n trading -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
TIMESCALEDB_IP=$(kubectl get svc timescaledb -n trading -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Setup complete!"
echo "-------------------"
echo "pgAdmin is available at: http://$PGADMIN_IP"
echo "Login credentials:"
echo "  Email: admin@admin.com"
echo "  Password: pgadmin123"
echo ""
echo "TimescaleDB connection details:"
echo "  Host: $TIMESCALEDB_IP"
echo "  Port: 5432"
echo "  Database: trading"
echo ""
echo "Admin credentials:"
echo "  Username: postgres"
echo "  Password: $TIMESCALEDB_PASSWORD"
echo ""
echo "Service credentials:"
echo "  Username: trading_service"
echo "  Password: $SERVICE_PASSWORD"