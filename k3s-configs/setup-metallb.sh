#!/bin/bash

echo "Applying MetalLB manifests..."
sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB CRDs to be established..."
sudo kubectl wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io
sudo kubectl wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io

echo "Applying MetalLB configuration..."
sudo kubectl apply -f k3s-configs/metallb/metallb-config.yaml

echo "Applying MetalLB service..."
sudo kubectl apply -f k3s-configs/metallb/metallb-service.yaml

echo "Waiting for LoadBalancer IP to be assigned..."
sudo kubectl wait --namespace=kube-system \
  --for=condition=Ready service/k3s-api-server \
  --timeout=90s

echo "Updating kubeconfig..."
NEW_IP="192.168.1.240"
sudo sed -i "s/server: https:\/\/[0-9.]\+:/server: https:\/\/$NEW_IP:/" /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Updating local DNS..."
HOSTS_ENTRY="$NEW_IP homecluster"
if ! grep -q "$HOSTS_ENTRY" /etc/hosts; then
    echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts > /dev/null
    echo "Added homecluster to /etc/hosts"
else
    echo "homecluster entry already exists in /etc/hosts"
fi

echo "Restarting k3s service..."
sudo systemctl restart k3s

echo "Waiting for k3s to be ready..."
sudo kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Verifying MetalLB deployment..."
sudo kubectl get pods -n metallb-system

echo "Verifying k3s-api-server service..."
sudo kubectl get svc -n kube-system k3s-api-server

echo "Verifying kubeconfig..."
sudo kubectl config view --raw

echo "Setup complete! Please log out and log back in, or run 'source ~/.bashrc' to apply changes to your current session."