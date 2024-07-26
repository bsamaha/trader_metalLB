#!/bin/bash

echo "Applying MetalLB manifests..."
sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.7/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB pods to be ready..."
sudo kubectl wait --namespace metallb-system \
                  --for=condition=ready pod \
                  --selector=app=metallb \
                  --timeout=90s

echo "Waiting for MetalLB CRDs to be established..."
sudo kubectl wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io
sudo kubectl wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io

echo "Applying MetalLB configuration..."
sudo kubectl apply -f k3s-configs/metallb/metallb-config.yaml
echo "Setup complete! Please log out and log back in, or run 'source ~/.bashrc' to apply changes to your current session."