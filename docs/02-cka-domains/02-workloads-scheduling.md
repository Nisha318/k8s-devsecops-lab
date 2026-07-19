# Workloads & Scheduling (15%)

## Exam Objectives

- Understand application deployments and how to perform rolling updates and rollbacks
- Use ConfigMaps and Secrets to configure applications
- Configure workload autoscaling
- Understand the primitives used to create robust, self-healing application deployments
- Configure Pod admission and scheduling (limits, node affinity, etc.)

---

## Deployments and Rolling Updates (Heavily Tested)

```bash
# Create deployment
kubectl create deploy nginx-deploy --image=nginx:1.30.4 --replicas=3

# Rolling update
kubectl set image deploy/nginx-deploy nginx=nginx:1.31.3

# Watch rollout progress
kubectl rollout status deploy/nginx-deploy

# View rollout history
kubectl rollout history deploy/nginx-deploy

# Rollback to previous version
kubectl rollout undo deploy/nginx-deploy

# Rollback to specific revision
kubectl rollout undo deploy/nginx-deploy --to-revision=1

# Scale deployment
kubectl scale deploy/nginx-deploy --replicas=5
```

### Deployment Strategy
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1         # max pods above desired count during update
      maxUnavailable: 0   # zero downtime -- no pods removed before new ones ready
```

---

## ConfigMaps

```bash
# Create from literal
kubectl create configmap app-config \
  --from-literal=ENV=production \
  --from-literal=LOG_LEVEL=info

# Create from file
kubectl create configmap app-config --from-file=config.properties

# View
kubectl get configmap app-config -o yaml
```

### Inject ConfigMap into Pod
```yaml
spec:
  containers:
    - name: app
      envFrom:
        - configMapRef:
            name: app-config
```

---

## Secrets

```bash
# Create secret
kubectl create secret generic db-secret \
  --from-literal=DB_PASSWORD=supersecret

# View (base64 encoded)
kubectl get secret db-secret -o yaml

# Decode
kubectl get secret db-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

---

## Resource Limits and Requests

```yaml
spec:
  containers:
    - name: app
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "500m"
```

---

## Node Affinity and Scheduling

```bash
# Label a node
kubectl label node kworker1 disktype=ssd

# Show node labels
kubectl get nodes --show-labels
```

```yaml
# Schedule pod on labeled node
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: disktype
                operator: In
                values:
                  - ssd
```

---

## Horizontal Pod Autoscaler

```bash
# Create HPA
kubectl autoscale deploy nginx-deploy --min=2 --max=10 --cpu-percent=50

# View HPA
kubectl get hpa
```

---

## DaemonSets and StatefulSets

```bash
# DaemonSet -- runs one pod per node (monitoring agents, log collectors)
kubectl get daemonset -n kube-system

# StatefulSet -- stable network identity, ordered deployment (databases)
kubectl get statefulsets
```

---

## Lab Notes

- Rolling update with zero downtime demonstrated: nginx 1.30.4 to 1.31.3
- maxUnavailable: 0 is the key setting for zero-downtime deployments
- kubectl rollout undo is the fastest recovery path on the exam
