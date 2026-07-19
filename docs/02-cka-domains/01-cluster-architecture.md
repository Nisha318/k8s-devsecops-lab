# Cluster Architecture, Installation & Configuration (25%)

## Exam Objectives

- Manage role based access control (RBAC)
- Prepare underlying infrastructure for installing a Kubernetes cluster
- Create and manage Kubernetes clusters using kubeadm
- Manage the lifecycle of Kubernetes clusters
- Implement and configure a highly-available control plane
- Use Helm and Kustomize to install cluster components
- Understand extension interfaces (CNI, CSI, CRI, etc.)
- Understand CRDs, install and configure operators

---

## Control Plane Components

| Component | Role | Location |
|---|---|---|
| kube-apiserver | All cluster communication goes through this | kmaster |
| etcd | Key-value store for all cluster state | kmaster |
| kube-scheduler | Assigns pods to nodes | kmaster |
| kube-controller-manager | Reconciles desired vs actual state | kmaster |

## Worker Node Components

| Component | Role |
|---|---|
| kubelet | Agent that runs on every node, executes pod specs |
| kube-proxy | Manages network rules for service routing |
| Container runtime | Runs the actual containers (containerd in this lab) |

---

## Key Commands

### Cluster Info
```bash
kubectl cluster-info
kubectl get nodes
kubectl get nodes -o wide
kubectl describe node kmaster
```

### Control Plane Pods
```bash
kubectl get pods -n kube-system
kubectl describe pod kube-apiserver-kmaster -n kube-system
```

### RBAC
```bash
# Create a role
kubectl create role pod-reader --verb=get,list,watch --resource=pods

# Create a rolebinding
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --user=nisha

# Check permissions
kubectl auth can-i list pods --as=nisha

# View all rolebindings
kubectl get rolebindings -A
kubectl get clusterrolebindings -A
```

### kubeadm Cluster Lifecycle
```bash
# Check upgrade plan
kubeadm upgrade plan

# Apply upgrade (control plane)
kubeadm upgrade apply v1.32.0

# Upgrade worker node
kubeadm upgrade node

# Generate new join command
kubeadm token create --print-join-command
```

### etcd Backup and Restore (Heavily Tested)
```bash
# Backup
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db

# Restore
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restore
```

---

## Extension Interfaces

| Interface | Purpose | Example |
|---|---|---|
| CRI | Container Runtime Interface | containerd, CRI-O |
| CNI | Container Network Interface | Calico, Flannel, Cilium |
| CSI | Container Storage Interface | AWS EBS, NFS |

---

## Lab Notes

- This lab uses containerd as the CRI
- Calico is the CNI plugin (pod CIDR: 10.244.0.0/16, patched from Calico default of 192.168.0.0/16)
- kubeadm version: v1.31.14
- Control plane taint: node-role.kubernetes.io/control-plane:NoSchedule
