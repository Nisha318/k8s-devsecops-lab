# Storage (10%)

## Exam Objectives

- Implement storage classes and dynamic volume provisioning
- Configure volume types, access modes and reclaim policies
- Manage persistent volumes and persistent volume claims

---

## Core Concepts

```
StorageClass       > defines HOW storage is provisioned
PersistentVolume   > a piece of storage that exists in the cluster
PersistentVolumeClaim > a request for storage by a pod
```

---

## Access Modes

| Mode | Abbreviation | Meaning |
|---|---|---|
| ReadWriteOnce | RWO | One node can read/write |
| ReadOnlyMany | ROX | Many nodes can read |
| ReadWriteMany | RWX | Many nodes can read/write |

---

## Reclaim Policies

| Policy | Behavior |
|---|---|
| Retain | PV kept after PVC deleted, manual cleanup required |
| Delete | PV and underlying storage deleted with PVC |
| Recycle | Deprecated, basic scrub and reuse |

---

## PersistentVolume (Static Provisioning)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-lab
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data
```

```bash
kubectl apply -f pv.yaml
kubectl get pv
```

---

## PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-lab
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```bash
kubectl apply -f pvc.yaml
kubectl get pvc
```

---

## Mount PVC in a Pod

```yaml
spec:
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: pvc-lab
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: storage
```

---

## StorageClass (Dynamic Provisioning)

```bash
# View available storage classes
kubectl get storageclass

# View default storage class
kubectl get storageclass -o wide
```

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

---

## Key Commands

```bash
# View all storage resources
kubectl get pv,pvc,storageclass

# Describe PVC to see binding status
kubectl describe pvc pvc-lab

# Check why a PVC is pending
kubectl describe pvc <name>    # look at Events section
```

---

## Lab Notes

- This lab uses hostPath volumes for simplicity
- In EKS, AWS EBS CSI driver handles dynamic provisioning
- PVC status of Pending means no matching PV was found
- PVC status of Bound means successfully matched to a PV
