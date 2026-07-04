# Cost Analysis — Phoenix TaskApp Cluster

This document outlines the monthly operational costs associated with running a multi-node, highly available k3s Kubernetes cluster on AWS.

---

## 1. Monthly Itemized Cost

| Item | Spec | Qty | $/mo (Approx) |
|---|---|---:|---:|
| **Control-plane VM** | EC2 `t3.small` (2 vCPU, 2GB RAM) | 1 | $15.00 |
| **Worker VM** | EC2 `t3.small` (2 vCPU, 2GB RAM) | 2 | $30.00 |
| **Root Block Storage** | 20GB gp3 EBS volume per node | 3 (60GB total) | $4.80 |
| **Persistent Volume (Postgres PVC)** | 5GB gp3 EBS volume | 1 | $0.40 |
| **AWS Application Load Balancer** | ALB Ingress controller frontend | 1 | $22.50 |
| **DNS / Hosted Zone** | Route 53 Hosted Zone | 1 | $0.50 |
| **Elastic IP Address** | Associated with instances / ALB | 3 | $0.00 (Free when attached) |
| **Total** | | | **$73.20 / mo** |

---

## 2. Compared to the Single-Server Compose & Portainer Deploy

- **Single-Server Compose Deployment:** ~$15.00/month (1 single `t2.micro` or `t3.small` instance containing all components + local docker volumes).
- **Multi-Node Kubernetes Deployment:** ~$73.20/month.

### What the Extra Spend Buys
The ~5x increase in monthly expenditure provides:
1. **High Availability & Fault Tolerance:** If a worker node crashes, Kubernetes immediately schedules frontend and backend replicas to the remaining worker node with zero downtime. In Compose, if the node dies, the app is completely offline.
2. **Zero-Downtime Rolling Updates:** With `maxUnavailable: 0` and replicas >2, deployments swap pods incrementally. A single server Compose setup drops connections during image pull and container recreation.
3. **Horizontal Autoscaling (HPA):** The cluster dynamically spawns backend pods in response to CPU/memory load, absorbing traffic spikes.
4. **GitOps & Declarative Reconciliation:** Argo CD automatically fixes configuration drift, ensuring the live cluster exactly matches the code in Git.

---

## 3. How to Halve the Cost

To reduce the monthly cost of this cluster by 50% or more:
1. **Skip the AWS ALB ($22.50 savings):** Instead of using a dedicated AWS Load Balancer, we can route DNS directly to the Elastic IP of the Control-Plane Node. The internal `ingress-nginx` controller binds to ports 80/443 on the control plane VM, bypassing ALB costs.
2. **Use EC2 Spot Instances ($21.00 savings):** AWS Spot instances for the two worker nodes offer up to a 70% discount compared to On-Demand pricing. Since the app is highly available and replicas are spread, if a Spot instance is reclaimed, Kubernetes automatically reschedules the container to the other node without breaking the service.
3. **Storage Tiering ($2.00 savings):** Minimize root volume sizes from 20GB to 10GB for workers, which is more than enough for lightweight k3s node workloads.

By applying these optimizations, the monthly cost is reduced to **~$29.70**, representing a **59% savings**.
