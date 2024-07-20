#!/bin/bash

echo "Applying MetalLB manifests..."
sudo kubectl apply -f k3s-configs/metallb/metallb-complete.yaml

echo "Waiting for CRDs to be established..."
sudo kubectl wait --for=condition=Established --all crd

echo "Updating local DNS..."
HOSTS_ENTRY="192.168.1.241 homecluster"
if ! grep -q "$HOSTS_ENTRY" /etc/hosts; then
    echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null
    echo "Added homecluster to /etc/hosts"
else
    echo "homecluster entry already exists in /etc/hosts"
fi

echo "Setup complete!"