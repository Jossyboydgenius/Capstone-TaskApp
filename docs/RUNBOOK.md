# Runbook — Phoenix TaskApp Cluster Management

This runbook contains the step-by-step instructions to bring up the infrastructure, deploy the application, and manage Day-2 cluster operations.

---

## 1. Provision from Zero

### Step 1: Provision Infrastructure
1. Go to the terraform directory:
   ```bash
   cd infra/terraform
   ```
2. Copy the example tfvars file and update it with your SSH key and public IP address:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration values
   ```
3. Initialize and apply the configuration:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
4. Note the outputs containing your instance public and private IPs.

### Step 2: Provision Cluster via Ansible
1. Go to the ansible directory:
   ```bash
   cd ../ansible
   ```
2. Create an `inventory.ini` file using the example template and populate it with the IPs from your Terraform outputs:
   ```bash
   cp inventory.ini.example inventory.ini
   # Edit inventory.ini with your actual server and agent IPs
   ```
3. Run the playbook to harden the nodes and configure k3s:
   ```bash
   ansible-playbook -i inventory.ini site.yml
   ```
4. Verify the kubeconfig is downloaded to your repository root. Set your environment variable:
   ```bash
   export KUBECONFIG=$(pwd)/../../kubeconfig
   kubectl get nodes -o wide
   # Output should display: 1 control-plane and 2 worker agents in "Ready" status
   ```

### Step 3: Install Platform Infrastructure
Install the required platform operators and controllers:

1. **Ingress-Nginx Controller:**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
   ```
2. **Cert-Manager:**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
   ```
3. **Metrics Server:**
   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```
4. **Argo CD:**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

### Step 4: Out-of-band Secret Setup
To ensure credentials are never stored in git:
1. Create a `manifests/secrets.yaml` (which is gitignored).
2. Base64-encode your database password and flask key and write them to the file.
3. Apply the secret manually:
   ```bash
   kubectl apply -f manifests/secrets.yaml
   ```

### Step 5: Bootstrapping GitOps
Apply the Argo CD Application configuration to initialize the GitOps sync loop:
```bash
kubectl apply -f gitops/application.yaml
```
Argo CD will automatically create the `taskapp` namespace (if not exists) and deploy the remaining manifests.

---

## 2. Day-2 Operations

### Scaling a Tier
To scale the frontend or backend deployment, do **NOT** run `kubectl scale`. Update the `replicas` field in the manifest files (e.g., `manifests/backend-deploy.yaml`), commit, and push. Argo CD will automatically synchronize the change.
If you need to scale immediately, sync via the Argo CD UI/CLI or run:
```bash
argocd app sync taskapp
```

### Rollback a Bad Deploy
Revert the bad commit in Git and push the change to your repository:
```bash
git revert <commit_sha>
git push origin main
```
Argo CD will immediately detect the git diff and deploy the previous stable image/configuration.

### Run a Database Migration
Database migrations are automatically run as a `Job` during deployment. If you need to trigger a manual migration:
1. Delete the existing migration job:
   ```bash
   kubectl delete job db-migration -n taskapp
   ```
2. Commit your new migration code and the GitOps agent will re-create the job to trigger the migration.

### Rotate a Secret
1. Update the base64-encoded values in your local, gitignored `manifests/secrets.yaml`.
2. Apply the update:
   ```bash
   kubectl apply -f manifests/secrets.yaml
   ```
3. Perform a rolling restart of the backend deployment to load the new credentials:
   ```bash
   kubectl rollout restart deployment/backend -n taskapp
   ```

---

## 3. Failure Recovery

### A Worker Node Dies / is Drained (Live Demo Failover)
If a worker node experiences hardware failure or needs maintenance:
1. Drain the node to migrate active pods to the remaining healthy worker node:
   ```bash
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   ```
2. Verify that all pods reschedule onto the remaining node:
   ```bash
   kubectl get pods -n taskapp -o wide
   ```
3. The ingress controller and service endpoints routing will continue to resolve successfully, ensuring zero downtime.
4. Once maintenance is done, uncordon the node:
   ```bash
   kubectl uncordon <node-name>
   ```

### A Backend Pod Crashloops
If a backend pod fails to start or continuously crashes:
1. Check the pod logs for runtime exceptions:
   ```bash
   kubectl logs <pod-name> -n taskapp --previous
   ```
2. Inspect the pod specifications and lifecycle events:
   ```bash
   kubectl describe pod <pod-name> -n taskapp
   ```
3. Look for configuration errors (e.g., database connection timeout or missing credentials in environment vars).

### A Bad Migration Recovery
If a migration fails or corrupts the schema:
1. Scale the backend deployments to `0` to halt database read/write actions:
   ```bash
   kubectl scale deployment/backend --replicas=0 -n taskapp
   ```
2. Restore the database using your Postgres backup or manually rollback using Flask CLI:
   ```bash
   kubectl exec -it postgres-0 -n taskapp -- pg_restore -U taskuser -d taskdb < backup.dump
   ```
3. Revert the migration code commit in Git, push, and scale backend replicas back to `2`.

### Postgres Pod Rescheduling / PVC Re-attachment
If the Postgres pod is killed:
1. Kubernetes StatefulSet will automatically reschedule `postgres-0` to a healthy node.
2. The cloud persistent storage provider will detach the EBS volume from the old node and re-attach it to the new node holding `postgres-0`.
3. Run `kubectl describe pvc/postgres-data-postgres-0 -n taskapp` to monitor attachment status.
4. Once the pod changes to `Running`, verify data integrity.
