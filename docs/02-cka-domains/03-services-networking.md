# Services & Networking (20%)

## Exam Objectives

- Understand connectivity between Pods
- Define and enforce Network Policies
- Use ClusterIP, NodePort, LoadBalancer service types and endpoints
- Use the Gateway API to manage Ingress traffic
- Know how to use Ingress controllers and Ingress resources
- Understand and use CoreDNS

---

## Service Types

| Type | Use Case | Accessible From |
|---|---|---|
| ClusterIP | Internal pod-to-pod communication | Inside cluster only |
| NodePort | Expose service on each node's IP | Outside cluster via NodeIP:Port |
| LoadBalancer | Cloud load balancer integration | Outside cluster via LB IP |

```bash
# Expose a deployment as ClusterIP
kubectl expose deploy nginx-deploy --port=80 --target-port=80

# Expose as NodePort
kubectl expose deploy nginx-deploy --port=80 --target-port=80 --type=NodePort

# Get service details
kubectl get svc
kubectl describe svc nginx-deploy
```

---

## Network Policies (Security Critical)

Without a network policy, all pods can communicate with all other pods.
Network policies restrict traffic using label selectors.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: default
spec:
  podSelector: {}       # applies to all pods in namespace
  policyTypes:
    - Ingress
```

```yaml
# Allow only frontend pods to reach backend pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

```bash
# Apply network policy
kubectl apply -f network-policy.yaml

# View network policies
kubectl get networkpolicy
kubectl describe networkpolicy backend-allow-frontend
```

---

## CoreDNS

Every service gets a DNS name inside the cluster:

```
<service-name>.<namespace>.svc.cluster.local
```

```bash
# Test DNS resolution from a pod
kubectl run test-pod --image=busybox --rm -it -- nslookup kubernetes.default

# View CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

## Ingress

```bash
# View ingress resources
kubectl get ingress -A

# Describe ingress
kubectl describe ingress <name>
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-deploy
                port:
                  number: 80
```

---

## Pod-to-Pod Connectivity

```bash
# Get pod IP addresses
kubectl get pods -o wide

# Test connectivity between pods
kubectl exec -it <pod-name> -- curl <other-pod-ip>:80

# Check endpoints for a service
kubectl get endpoints <service-name>
```

---

## Lab Notes

- Calico CNI enforces network policies in this lab
- Pod CIDR: 10.244.0.0/16 (set during kubeadm init, Calico manifest patched to match)
- Service CIDR: 10.96.0.0/12 (kubeadm default)
- CoreDNS installed automatically by kubeadm as an addon
