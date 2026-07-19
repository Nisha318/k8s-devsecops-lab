# Troubleshooting (30%)

Highest weighted domain on the CKA exam. Every topic below is fair game.

## Exam Objectives

- Troubleshoot clusters and nodes
- Troubleshoot cluster components
- Monitor cluster and application resource usage
- Manage and evaluate container output streams
- Troubleshoot services and networking

---

## Systematic Diagnosis Approach

Always work top-down:

```
1. kubectl get <resource>        -- is it there? what state?
2. kubectl describe <resource>   -- events section shows what went wrong
3. kubectl logs <pod>            -- application-level errors
4. kubectl exec -it <pod> -- sh  -- get inside the container
5. node-level checks             -- systemctl, journalctl, df, free
```

---

## Pod Troubleshooting

```bash
# Check pod status
kubectl get pods
kubectl get pods -o wide          # shows which node pod is on
kubectl get pods -A               # all namespaces

# Detailed pod info including events
kubectl describe pod <pod-name>

# Container logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>   # multi-container pods
kubectl logs <pod-name> --previous            # logs from crashed container

# Get inside a running container
kubectl exec -it <pod-name> -- bash
kubectl exec -it <pod-name> -- sh             # if bash not available

# Run a debug pod
kubectl run debug --image=busybox --rm -it -- sh
```

### Common Pod Failure States

| Status | Likely Cause |
|---|---|
| Pending | No node has enough resources, or PVC not bound |
| CrashLoopBackOff | Container keeps crashing, check logs --previous |
| ImagePullBackOff | Wrong image name, registry auth issue |
| OOMKilled | Container exceeded memory limit |
| Error | Container exited with non-zero code |

---

## Node Troubleshooting

```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>   # check Conditions and Events

# SSH into the node, then:
sudo systemctl status kubelet
sudo journalctl -u kubelet -f       # follow kubelet logs
sudo journalctl -u kubelet --since "10 minutes ago"

# Check disk and memory
df -h
free -h

# Check containerd
sudo systemctl status containerd
sudo crictl ps                      # list running containers
sudo crictl logs <container-id>
```

### Node Not Ready Checklist

```
1. Is kubelet running?             systemctl status kubelet
2. Is containerd running?          systemctl status containerd
3. Is swap disabled?               free -h
4. Is disk full?                   df -h
5. Is the CNI plugin working?      kubectl get pods -n kube-system
6. Are kernel modules loaded?      lsmod | grep br_netfilter
```

---

## Control Plane Troubleshooting

```bash
# Check control plane pods
kubectl get pods -n kube-system

# Logs for specific control plane component
kubectl logs kube-apiserver-kmaster -n kube-system
kubectl logs kube-scheduler-kmaster -n kube-system
kubectl logs kube-controller-manager-kmaster -n kube-system
kubectl logs etcd-kmaster -n kube-system

# Static pod manifests (control plane defined here)
ls /etc/kubernetes/manifests/
```

---

## Service and Networking Troubleshooting

```bash
# Check service exists and has correct ports
kubectl get svc
kubectl describe svc <service-name>

# Check endpoints -- if empty, label selector is wrong
kubectl get endpoints <service-name>

# Test DNS resolution from inside a pod
kubectl exec -it <pod> -- nslookup <service-name>
kubectl exec -it <pod> -- nslookup kubernetes.default

# Test service connectivity
kubectl exec -it <pod> -- curl <service-name>:<port>
kubectl exec -it <pod> -- curl <cluster-ip>:<port>

# Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

---

## Resource Monitoring

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods
kubectl top pods -A
kubectl top pods --sort-by=memory

# Note: requires metrics-server to be installed
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## Useful One-Liners

```bash
# Get all events sorted by time
kubectl get events --sort-by=.metadata.creationTimestamp

# Get events for a specific namespace
kubectl get events -n default

# Watch pods in real time
kubectl get pods -w

# Get pod logs with timestamps
kubectl logs <pod> --timestamps

# Find which node a pod is running on
kubectl get pod <pod> -o wide

# Force delete a stuck pod
kubectl delete pod <pod> --grace-period=0 --force

# Check resource quotas
kubectl get resourcequota -A
```
