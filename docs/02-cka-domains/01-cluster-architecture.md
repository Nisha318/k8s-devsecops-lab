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

---

### etcd Backup and Restore (Heavily Tested)

etcd is the cluster database. All objects (pods, deployments, secrets, RBAC
bindings) live here. Losing etcd means losing all cluster state since the
last backup. Backup and restore appear on every CKA exam.

**Cert paths (memorize these):**

| What | Path |
|---|---|
| CA cert | `/etc/kubernetes/pki/etcd/ca.crt` |
| Server cert | `/etc/kubernetes/pki/etcd/server.crt` |
| Server key | `/etc/kubernetes/pki/etcd/server.key` |
| Endpoint | `https://127.0.0.1:2379` |

Verify cert paths from the static pod manifest if unsure:
```bash
sudo cat /etc/kubernetes/manifests/etcd.yaml | grep -A5 "command:"
```

![cert paths verification](../../assets/etcd-01-cert-paths.png)

---

**Inspect etcd keys directly:**

etcd v3.5+ runs on a distroless image.  Therefore, no shell is available. The `sh -c`
wrapper fails with "executable file not found." Call etcdctl directly without
a shell wrapper.

```bash
kubectl exec etcd-kmaster -n kube-system -- etcdctl get /registry/pods \
  --prefix --keys-only \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  --endpoints=https://127.0.0.1:2379
```

![etcd keys output](../../assets/etcd-02-keys.png)

---

**Backup:**

Always use ETCDCTL_API=3. Inline it per command on the exam to avoid state
issues across terminal tabs.

```bash
sudo etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/backup-20260720-0304.db
```

![snapshot save output](../../assets/etcd-03-snapshot-save.png)

---

**Verify the snapshot:**

```bash
sudo etcdctl snapshot status /opt/etcd-backup.db --write-out=table
```

A valid snapshot shows all four fields populated. A corrupted or incomplete
snapshot either fails this command or shows a size mismatch.

![snapshot status table](../../assets/etcd-04-snapshot-status.png)

---

**Restore (three steps, order matters):**

The restore command creates a new data directory on disk. The manifest update
tells etcd to use it. Order is fixed: build the directory before sending etcd
to live there.

Step 1: restore to a new data directory:
```bash
sudo etcdctl \
  snapshot restore /opt/backup-20260720-0304.db \
  --data-dir=/var/lib/etcd-from-backup
# No certs needed -- reads the snapshot file locally
# Creates and populates the new directory before etcd tries to read it
```

![snapshot restore output](../../assets/etcd-05-snapshot-restore.png)

---

Step 2: update the etcd static pod manifest (TWO places):

```bash
sudo vi /etc/kubernetes/manifests/etcd.yaml
```

Use find and replace in vi to catch both lines at once:
```
:%s/\/var\/lib\/etcd$/\/var\/lib\/etcd-restored/g
```

Place 1: the `--data-dir` flag under `spec.containers.command`:

![manifest data-dir flag](../../assets/etcd-06-manifest-command.png)

Place 2: the `hostPath.path` under `spec.volumes`:

![manifest hostPath volume](../../assets/etcd-07-manifest-volume.png)

Missing the hostPath update is the most common restore failure. etcd starts
but reads from the wrong directory. Symptom: etcd-kmaster absent from pod
list, kube-scheduler shows 0/1.

Save and exit:
```
:wq
```

---

Step 3:  wait for etcd to restart (30-60 seconds):

```bash
watch kubectl get pods -n kube-system
```

The API server will timeout briefly during etcd restart -- this is normal.
Wait for `etcd-kmaster` to show `1/1 Running` before running any kubectl
commands.

![post-restore pod health](../../assets/etcd-08-post-restore-pods.png)

---

**Verify restore succeeded:**

```bash
kubectl get deployments && kubectl get namespaces
```

Objects that existed at snapshot time should be back. Anything created after
the snapshot was taken is permanently lost. This is your RPO boundary.

![restore verification](../../assets/etcd-09-restore-verify.png)

---

**Critical gotchas:**

1. Snapshot order matters. Correct drill sequence:
   `create --> backup --> delete --> restore --> verify`

2. Two-place edit in etcd.yaml, both `--data-dir` flag and
   `volumes.hostPath.path` must point to the new directory.

3. etcd is a distroless image with no shell in etcd v3.5+ containers.
   Drop the `sh -c` wrapper and call etcdctl directly.

4. API version. Always use ETCDCTL_API=3. At start of session or inline per command on the exam:
   `sudo ETCDCTL_API=3 etcdctl snapshot save ...`

5. Restore file naming:  use `ls -lh /opt/backup-*.db` to confirm the
   exact filename before running restore. The `$(date)` pattern in the
   restore command evaluates to the current time, not the backup time.

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
