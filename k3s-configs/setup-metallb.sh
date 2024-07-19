#!/bin/bash

echo "Applying MetalLB manifests..."
sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

echo "Waiting for CRDs to be established..."
sudo kubectl wait --for=condition=Established --all crd

echo "Applying MetalLB configuration..."
sudo kubectl apply -f k3s-configs/metallb/metallb-config.yaml
