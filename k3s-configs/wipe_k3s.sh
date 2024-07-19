#!/bin/bash

# Function to check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

# Function to stop K3s and remove processes
stop_k3s() {
    echo "Stopping K3s service..."
    systemctl stop k3s

    echo "Killing any remaining K3s processes..."
    killall k3s-server 2>/dev/null
    killall k3s-agent 2>/dev/null
    killall k3s 2>/dev/null
}

# Function to uninstall K3s
uninstall_k3s() {
    echo "Uninstalling K3s..."
    if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
        /usr/local/bin/k3s-uninstall.sh
    else
        echo "K3s uninstall script not found. K3s may not be installed."
    fi
}

# Function to remove Rancher directories
remove_rancher_dirs() {
    echo "Removing Rancher directories..."
    rm -rf /etc/rancher
    rm -rf /var/lib/rancher
}

# Function to remove K3s binaries
remove_k3s_binaries() {
    echo "Removing K3s binaries..."
    rm -f /usr/local/bin/k3s
    rm -f /usr/local/bin/k3s-killall.sh
    rm -f /usr/local/bin/k3s-uninstall.sh
}

# Function to remove kubeconfig
remove_kubeconfig() {
    echo "Removing kubeconfig..."
    rm -rf ~/.kube
    rm -rf /root/.kube
}

# Function to unset KUBECONFIG
unset_kubeconfig() {
    echo "Unsetting KUBECONFIG environment variable..."
    unset KUBECONFIG

    # Get the real user's home directory
    REAL_HOME=$(eval echo ~${SUDO_USER})

    # Remove KUBECONFIG from user's shell configuration files
    for file in "${REAL_HOME}/.bashrc" "${REAL_HOME}/.bash_profile" "${REAL_HOME}/.profile"; do
        if [ -f "$file" ]; then
            sed -i '/export KUBECONFIG/d' "$file"
        fi
    done

    # Also remove from root's bash configuration, just in case
    for file in /root/.bashrc /root/.bash_profile /root/.profile; do
        if [ -f "$file" ]; then
            sed -i '/export KUBECONFIG/d' "$file"
        fi
    done

    echo "KUBECONFIG environment variable has been unset and removed from shell configuration files."
}

# Main execution
main() {
    check_root
    stop_k3s
    uninstall_k3s
    remove_rancher_dirs
    remove_k3s_binaries
    remove_kubeconfig
    unset_kubeconfig
    echo "K3s clean wipe completed."
}

# Run the main function
main