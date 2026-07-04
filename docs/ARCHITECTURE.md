# Architecture — Phoenix TaskApp

This document details the multi-node Kubernetes architecture designed for the highly available, secure, and GitOps-reconciled deployment of **TaskApp**.

---

## 1. Topology Diagram

```
                              Internet
                                 │
                                 ▼ (Public Traffic - Ports 80/443)
                      DNS (taskapp / api.yourdomain.dev)
                                 │
                                 ▼
                     AWS Application Load Balancer
                                 │
   ┌─────────────────────────────┴─────────────────────────────┐
   ▼ (Node: aws_instance.server - Control Plane)               ▼ (Nodes: aws_instance.agent[0,1] - Worker VMs)
 ┌───────────────────────────────────────────────┐           ┌───────────────────────────────────────────────┐
 │   Ingress Controller (ingress-nginx Pod)      │           │                                               │
 │                     │                         │           │                                               │
 │         TLS Terminated by cert-manager        │           │                                               │
 └─────────────────────┬─────────────────────────┘           └───────────────────────────────────────────────┘
                       │
         ┌─────────────┴───────────────────────────────────────────────────────┐
         │ (Internal Router / ClusterIP Services)                              │
         ▼                                                                     ▼
   frontend Service (Port 80)                                            backend Service (Port 5000)
         │                                                                     │
   ┌─────┴─────────────────────┐                                         ┌─────┴─────────────────────┐
   ▼                           ▼                                         ▼                           ▼
 frontend Pod (Agent 0)      frontend Pod (Agent 1)                    backend Pod (Agent 0)       backend Pod (Agent 1)
                                                                         │                           │
                                                                         └─────────────┬─────────────┘
                                                                                       ▼
                                                                                postgres-service (Port 5432)
                                                                                       │
                                                                                       ▼
                                                                                postgres-0 Pod (StatefulSet)
                                                                                       │
                                                                                       ▼
                                                                                PVC (AWS EBS Block Storage)
```

---

## 2. Node & Network Configuration

### Node Topology
- **1 Control Plane Node:** `t3.small` instance in AWS (`us-east-1a`). Runs the k3s server API, controller manager, scheduler, and hosts the ingress-nginx controller.
- **2 Worker Agent Nodes:** `t3.small` instances in AWS. Hosts the application replicas (frontend, backend, Postgres) and dynamically scales backend pods based on demand.

### CIDR & Subnetting
- **VPC Range:** `10.0.0.0/16`
- **Public Subnet:** `10.0.1.0/24`. All VMs reside here and receive public IPs to allow administrative SSH and ingress traffic routing.
- **Internal Cluster Pod CIDR:** Managed automatically by k3s (`10.42.0.0/16`).
- **Internal Cluster Service CIDR:** Managed automatically by k3s (`10.43.0.0/16`).

### Security & Firewall Hardening (AWS SGs & UFW)
- **Port 6443 (Kubernetes API):** Strictly restricted in the AWS Security Group to the administrator's local machine IP (`admin_ip`). Any external port scan on 6443 will timeout.
- **Port 22 (SSH):** Strictly restricted to the administrator's local machine IP. Password authentication is disabled in SSH configuration; only SSH key authentication is allowed.
- **Ports 80/443 (HTTP/HTTPS):** Publicly accessible (`0.0.0.0/0`) to allow web clients to reach the Nginx ingress controller.
- **Node-to-Node Traffic:** All ports are allowed within the VPC range `10.0.0.0/16` and the security group itself to allow Flannel VXLAN overlay communication, kubelet metrics collection, and cluster DNS resolution.

---

## 3. Request Flow

1. **DNS Resolution:** The client requests `https://taskapp.yourdomain.dev` or `https://api.yourdomain.dev`. DNS resolves to the Elastic IP of the ingress controller node.
2. **Ingress Inbound:** The request reaches the `ingress-nginx` controller on ports 80/443.
3. **TLS Termination:** The Ingress controller uses the TLS certificate provisioned automatically by `cert-manager` via Let's Encrypt, validating the connection and terminating TLS.
4. **Service Proxying:**
   - Traffic targeting `taskapp.yourdomain.dev` is routed to the `frontend` ClusterIP service, which load balances it across the active `frontend` Pods (running on port 80).
   - Traffic targeting `api.yourdomain.dev` (or `/api` prefix) is routed to the `backend` ClusterIP service, which load balances it across the active `backend` Pods (running on port 5000).
5. **Database Querying:** The backend pods communicate internally with the `postgres-service` on port 5432, which forwards requests to the active `postgres-0` pod in the StatefulSet.

---

## 4. Single-Server Assumptions Fixed

| Single-Server Assumption | Why it breaks at scale | How you fixed it |
|---|---|---|
| **Migrate-on-boot in the entrypoint** | In a multi-replica deployment, booting multiple pods simultaneously results in a race condition on `alembic upgrade head`, corrupting database schema states. | Decoupled migrations into a one-time **Kubernetes Job** (`db-migration-job.yaml`) that completes execution prior to app replica rollout. |
| **Named volume on the host** | Pods scheduled on node A cannot access host-local volumes if they are killed and rescheduled on node B. | Deployed PostgreSQL as a **StatefulSet** with a **PersistentVolumeClaim (PVC)** using the cluster's cloud storage provisioner (AWS EBS gp3). |
| **`ports:` published on host** | Host-port binding prevents scaling container replicas beyond the number of nodes (due to port collisions) and lacks unified routing. | Used internal **ClusterIP Services** for frontend and backend, exposed via a single, shared **Ingress Controller** acting as the cluster's front door. |
| **Local status / state tracking** | Multiple frontend/backend replicas cannot share local filesystem caches or memory states without inconsistency. | Configured the app as stateless replicas, offloading all session and persistent state to the centralized Postgres database. |
| **Secrets committed to Git** | Exposes private credentials to anyone who has access to the codebase repository. | Removed environment files from git history, and created a `secrets.example.yaml` template file. Real credentials are created out-of-band. |
| **Self-healing and scaling** | Process crashes or traffic spikes require manual intervention to restart/scale containers. | Configured **Liveness/Readiness/Startup Probes** for automated container restarts, and a **Horizontal Pod Autoscaler (HPA)** for dynamic scaling. |

---

## 5. Choices & Trade-offs

### Raw YAML manifests vs Helm or Kustomize
We selected **Raw YAML manifests** to maximize transparency, readability, and compatibility with Argo CD sync engines. This ensures that every resource's specifications are clearly laid out without abstracting values.

### ingress-nginx vs k3s Traefik
We disabled the default k3s Traefik controller and installed **ingress-nginx**. Ingress-Nginx provides a robust set of standard annotations, advanced rewrite rules, and is the industry-standard controller with extensive Let's Encrypt integration.

### CNI & NetworkPolicy Enforcement
We used **Flannel (with Canal)** to enable NetworkPolicy enforcement in the k3s cluster. NetworkPolicies enforce namespace isolation by preventing database egress/ingress compromise.

### Secrets Approach (Out-of-band)
To respect rule #6 and prevent secrets in git history, we configure secrets **out-of-band** (manually applied to the namespace). This separates infrastructure code from security credentials.
