#!/bin/bash
# =============================================================================
# Worker Node Bootstrap Script
# Injected as EC2 user_data via OpenTofu templatefile()
# Variables in $${} are bash; variables in ${} are OpenTofu template vars
# =============================================================================
set -euo pipefail

exec > >(tee /var/log/k8s-worker.log) 2>&1
echo "=== Worker Node Bootstrap Started: $(date) ==="

KUBE_VERSION="${kubernetes_version}"
CLUSTER_NAME="${cluster_name}"
AWS_REGION="${aws_region}"

# =============================================================================
# PHASE 1: System Prerequisites (identical to control plane)
# =============================================================================

echo "--- Phase 1: System prerequisites ---"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  conntrack \
  socat \
  ebtables \
  ipset \
  jq \
  awscli

swapoff -a
sed -i '/\bswap\b/d' /etc/fstab
echo "Swap disabled"

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo "Kernel modules loaded"

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
echo "Sysctl parameters applied"

# =============================================================================
# PHASE 2: containerd
# =============================================================================

echo "--- Phase 2: Install containerd ---"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd
echo "containerd installed (SystemdCgroup = true)"

# =============================================================================
# PHASE 3: kubeadm and kubelet
# Note: kubectl is optional on workers but included for direct node debugging
# =============================================================================

echo "--- Phase 3: Install Kubernetes components v$${KUBE_VERSION} ---"

curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$${KUBE_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v$${KUBE_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
echo "kubelet, kubeadm, kubectl installed"

# =============================================================================
# PHASE 4: Poll SSM for the join command
# The control plane writes this after kubeadm init completes.
# Workers poll every 20 seconds for up to 10 minutes.
# =============================================================================

echo "--- Phase 4: Waiting for join command from control plane ---"

MAX_ATTEMPTS=30
ATTEMPT=0
JOIN_COMMAND=""

while [ $${ATTEMPT} -lt $${MAX_ATTEMPTS} ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $${ATTEMPT}/$${MAX_ATTEMPTS}: checking SSM for join command..."

  JOIN_COMMAND=$(aws ssm get-parameter \
    --name "/$${CLUSTER_NAME}/join-command" \
    --with-decryption \
    --region "$${AWS_REGION}" \
    --query Parameter.Value \
    --output text 2>/dev/null || echo "")

  if [ -n "$${JOIN_COMMAND}" ]; then
    echo "Join command retrieved from SSM"
    break
  fi

  echo "Not available yet. Waiting 20 seconds..."
  sleep 20
done

if [ -z "$${JOIN_COMMAND}" ]; then
  echo "ERROR: Could not retrieve join command after $${MAX_ATTEMPTS} attempts."
  echo "Check control plane bootstrap log: /var/log/k8s-control-plane.log"
  exit 1
fi

# =============================================================================
# PHASE 5: Join the cluster
# =============================================================================

echo "--- Phase 5: Joining cluster ---"

eval $${JOIN_COMMAND}

echo ""
echo "=== Worker Node Bootstrap Complete: $(date) ==="
echo ""
echo "Verify from control plane:"
echo "  kubectl get nodes"
