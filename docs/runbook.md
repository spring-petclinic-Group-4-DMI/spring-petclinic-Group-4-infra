# Petclinic Platform — Runbook

Operational guide for the dev environment. Covers one-time bootstrap, day-1 deploy, day-2 operations, and known failure modes from this project's setup history.

**Scope:** dev only. There is no prod environment.

---

## Table of contents

1. [Quick reference](#1-quick-reference)
2. [One-time bootstrap](#2-one-time-bootstrap)
3. [Day-1 deployment](#3-day-1-deployment)
4. [Day-2 operations](#4-day-2-operations)
5. [Verification — is it working?](#5-verification)
6. [Troubleshooting / known issues](#6-troubleshooting)
7. [Rollback and cleanup](#7-rollback-and-cleanup)

---

## 1. Quick reference

### Identities and locations

| | Value |
|---|---|
| AWS account | `428101261622` |
| AWS region | `us-east-2` |
| Domain | `pawscare.online` (registered at Spaceship, NS delegated to Route 53) |
| EKS cluster | `petclinic-dev` |
| K8s namespaces | `petclinic-dev` (apps), `monitoring` (Prom/Grafana/Loki/Zipkin), `argocd`, `kube-system` (Karpenter, EBS CSI) |
| Terraform state | local file (or S3 `petclinic-terraform-state-428101261622/petclinic/dev/terraform.tfstate` once bootstrap-state.sh has run) |
| GitHub org | `spring-petclinic-Group-4-DMI` |

### Port-forward cheat sheet

```bash
# ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8443:443
# https://localhost:8443  user: admin
# password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# http://localhost:3000  user: admin
# password: kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# http://localhost:9090

# Zipkin
kubectl port-forward -n monitoring svc/zipkin 9411:9411
# http://localhost:9411

# Petclinic API Gateway
kubectl port-forward -n petclinic-dev svc/api-gateway 8080:8080
# http://localhost:8080
```

---

## 2. One-time bootstrap

These steps run **once** when first standing up the environment. Skip any that are already done.

### 2.1 — Prerequisites on your workstation

```bash
# Required tools
aws --version          # AWS CLI v2
terraform version      # >= 1.6.0
kubectl version --client
helm version
git --version
```

AWS credentials must be configured (`aws configure` or env vars) with admin-equivalent rights in account `428101261622`.

### 2.2 — Bootstrap the Terraform state backend (optional but recommended)

Creates the S3 bucket + DynamoDB lock table so terraform state lives remotely. **Skip if you're happy with local state on one machine.**

```bash
cd petclinic-platform
./scripts/bootstrap-state.sh
```

The script is idempotent. After it succeeds, migrate existing local state:

```bash
cd terraform/environments/dev
terraform init -migrate-state    # answer "yes" when prompted
```

### 2.3 — Set GitHub Actions OIDC role values in tfvars

Already in [terraform.tfvars](../terraform/environments/dev/terraform.tfvars). Verify:

```bash
grep -E "github_org|create_github_oidc_provider|domain_name|openai_api_key" \
  terraform/environments/dev/terraform.tfvars
```

Expected:
- `github_org = "spring-petclinic-Group-4-DMI"`
- `create_github_oidc_provider = false`  (the provider already exists in this account)
- `domain_name = "pawscare.online"` **or** `""` (see [§6.3](#63-acm-cert-validation-hangs))
- `openai_api_key = "sk-proj-..."` (real value, gitignored)

### 2.4 — Initial Terraform apply

```bash
cd terraform/environments/dev
terraform init -upgrade           # picks up helm + kubernetes providers
terraform plan -out plan.out
terraform apply plan.out
```

**Expect ~15-20 min.** Resources created:
- VPC + subnets + 4 security groups
- EKS cluster + managed node group + OIDC provider + 4 add-ons (coredns, kube-proxy, vpc-cni, ebs-csi with IRSA)
- ECR repos × 8
- RDS MySQL + Secrets Manager entries (RDS creds + OpenAI key)
- Karpenter IAM/SQS/EventBridge
- GitHub OIDC IAM roles × 2 (app, infra)
- **External Secrets Operator** (Helm release + IRSA role bound to `external-secrets:external-secrets` SA)
- Route 53 zone + ACM cert (if `domain_name` is set)

**If apply hangs on ACM cert validation**, see [§6.3](#63-acm-cert-validation-hangs).
**If the Helm provider auth token expires mid-apply**, just re-run — the token lasts 15 min.

After apply, save the role ARNs:

```bash
terraform output github_actions_app_role_arn
terraform output github_actions_infra_role_arn
terraform output route53_name_servers     # 4 NS records for Spaceship
```

### 2.4b — Re-applying an existing environment

If you've applied before and are picking up new module changes (e.g. the recent `external-secrets` addition), the sequence is:

```bash
cd terraform/environments/dev
terraform init -upgrade       # pulls new providers

# If a previously-used module has been removed from code, clean its state:
terraform state list | grep <module-name>
terraform state rm 'module.<module-name>'

terraform plan -out plan.out
terraform apply plan.out
```

### 2.5 — Delegate the domain at Spaceship

1. Log into Spaceship.com → Domains → `pawscare.online` → Manage
2. Nameservers section → switch to **Custom nameservers**
3. Paste the 4 NS records from `terraform output route53_name_servers`
4. Save

Verify propagation:

```bash
dig NS pawscare.online +short
# should return the AWS NS records, not Spaceship's defaults (5-60 min)
```

Once propagated, the `aws_acm_certificate_validation` resource (if it was waiting) will complete.

### 2.6 — Configure GitHub repos

**App repo `spring-petclinic-microservices`:**

Settings → Secrets and variables → Actions → **Secrets**:
| Name | Value |
|---|---|
| `AWS_ROLE_ARN` | value of `terraform output github_actions_app_role_arn` |
| `PLATFORM_REPO_TOKEN` | a fine-grained PAT with `Contents: Write` + `Metadata: Read` on the infra repo (generate at github.com/settings/personal-access-tokens) |

**Variables** tab:
| Name | Value |
|---|---|
| `AWS_ACCOUNT_ID` | `428101261622` |
| `AWS_REGION` | `us-east-2` (optional — workflow falls back to this) |
| `PLATFORM_REPO` | `spring-petclinic-Group-4-DMI/spring-petclinic-Group-4-infra` |

**Infra repo `petclinic-platform`:**

Settings → Secrets:
| Name | Value | Required for |
|---|---|---|
| `AWS_ROLE_ARN` | value of `terraform output github_actions_infra_role_arn` | All workflows |
| `OPENAI_API_KEY` | The OpenAI key (same one in your local `terraform.tfvars`) | [terraform.yml](../.github/workflows/terraform.yml) — passed as `TF_VAR_openai_api_key` so CI apply doesn't clobber the value in AWS Secrets Manager. The plan + apply jobs **refuse to run** if this is unset. |

Non-secret terraform inputs (`github_org`, `domain_name`, `create_github_oidc_provider`) are hardcoded in [terraform.yml](../.github/workflows/terraform.yml)'s `env:` block — change them there if they ever vary. The local `terraform.tfvars` file is **gitignored and not used by CI**; values from the workflow env take its place.

Settings → Actions → General → Workflow permissions → **enable** "Allow GitHub Actions to create and approve pull requests".

**Both repos:** Settings → Environments → New environment named `dev` (no protection rules needed for solo dev; add reviewers if you want a human gate on apply).

### 2.7 — Create the Grafana admin secret

The monitoring stack's Helm values reference an existing K8s secret rather than baking the password into git.

```bash
aws eks update-kubeconfig --name petclinic-dev --region us-east-2

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"
```

Retrieve later with:
```bash
kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## 3. Day-1 deployment

After bootstrap, deploying the application stack:

### 3.1 — Install ArgoCD + apply Applications

Trigger the workflow:

1. GitHub → infra repo → Actions → **Install ArgoCD** → Run workflow → branch `main` → Run
2. Wait ~10 min. The workflow:
   - Installs ArgoCD via Helm into namespace `argocd`
   - Applies the 11 ArgoCD Applications under [k8s/argocd/applications/dev/](../k8s/argocd/applications/dev/) in dependency order
   - Waits for config-server, discovery-server, and the core 4 to become Synced+Healthy

If you'd rather do it locally:

```bash
aws eks update-kubeconfig --name petclinic-dev --region us-east-2

kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --version 7.3.4 \
  -f k8s/argocd/install/values.yaml \
  --wait --timeout 10m

kubectl apply -f k8s/argocd/applications/dev/
```

### 3.2 — First image build from the app repo

The petclinic services need at least one image push before pods can come up. From the app repo:

```bash
cd ../spring-petclinic-microservices
git commit --allow-empty -m "chore: trigger first build"
git push
```

Watch GitHub Actions in the app repo:
- `Java CI with Maven` runs unit tests
- `Build and Push Docker Images` detects all 8 services as "changed" (first run), builds ARM64 images, pushes to ECR, fires `app-image-built` dispatch to infra repo

### 3.3 — Merge the auto-generated tag PR

The dispatch triggers `Update Helm image tags` in the infra repo, which opens a PR titled `ci: bump image tags → <sha>`.

1. Review the PR — should show updates to all 8 `helm-values/{service}.yaml` files setting `image.tag`
2. Merge

ArgoCD detects the merge and syncs the 8 Applications. Pods come up over 2-5 min in dependency order: config-server → discovery-server → core 4 → api-gateway + admin-server.

### 3.4 — ESO and ServiceMonitor status

**ESO is installed by terraform** (the [external-secrets module](../terraform/modules/external-secrets/main.tf)) and the `ClusterSecretStore` is applied by ArgoCD from [k8s/base/external-secrets/](../k8s/base/external-secrets/) at sync wave -11 (before everything else). So by the time petclinic services sync, `secrets.rdsCredentials` / `secrets.openaiApiKey` work end-to-end.

**ServiceMonitors** are emitted by the chart when `metrics.enabled: true` (which is set in all 5 business services' helm-values). Prometheus will scrape `/actuator/prometheus` if the Spring app has `micrometer-registry-prometheus` on the classpath and `management.endpoints.web.exposure.include` lists `prometheus`. Check upstream config if metrics don't show up.

---

## 4. Day-2 operations

### Procedure: Pause the environment overnight to save cost

**When:** End of working day.
**Who:** Anyone with AWS credentials for the account.
**Time:** ~3 min.

**Steps:**
```bash
./scripts/stop-env.sh
```

**Verify:**
```bash
./scripts/env-status.sh
# RDS: stopped
# Node group: desiredCapacity = 0
```

**Rollback:**
```bash
./scripts/start-env.sh
```

### Procedure: Deploy a single service change

**When:** You've changed code in one service in the app repo.
**Who:** Any developer with push access.
**Time:** ~5-8 min end to end.

**Steps:**
1. Push to `main` in the app repo
2. Wait for the build-push workflow to succeed
3. Merge the auto-generated PR in the infra repo
4. Watch ArgoCD sync the changed Application

**Verify:**
```bash
kubectl -n petclinic-dev get pods -l app.kubernetes.io/name=<service>
# READY 1/1, AGE within last few minutes
```

**Rollback:**
- Revert the image-tag PR in the infra repo. ArgoCD will sync back to the old tag automatically.

### Procedure: Roll back a specific service to an earlier tag

**When:** A deployed version broke prod and you want to revert without rebuilding.
**Who:** Developer.
**Time:** ~2 min.

**Steps:**
```
GitHub → infra repo → Actions → Update Helm image tags →
  Run workflow with inputs:
    service: customers-service
    tag:     <previous SHA>
```

This opens a PR with just the one service's tag rolled back. Merge it.

**Verify:**
```bash
kubectl -n petclinic-dev describe deployment <service> | grep Image:
```

**Rollback:** Re-run the workflow with the new SHA.

### Procedure: Rotate the OpenAI API key

**When:** Quarterly or after suspected leak.
**Who:** Whoever owns the OpenAI account.
**Time:** ~5 min.

**Steps:**
1. Create new key at platform.openai.com/api-keys
2. Update `openai_api_key` in [terraform.tfvars](../terraform/environments/dev/terraform.tfvars)
3. `terraform apply` — Secrets Manager value updates
4. ExternalSecret refreshInterval (1h) auto-rolls the K8s Secret; force immediately with:
   ```bash
   kubectl -n petclinic-dev annotate externalsecret openai-api-key force-sync=$(date +%s) --overwrite
   ```
5. Rolling-restart genai-service to pick up the env:
   ```bash
   kubectl -n petclinic-dev rollout restart deployment genai-service
   ```
6. Revoke the old key in OpenAI dashboard.

**Verify:**
```bash
kubectl -n petclinic-dev exec deploy/genai-service -- env | grep OPENAI_API_KEY | cut -c1-20
# should show the prefix of the new key
```

### Procedure: Rotate the Grafana admin password

```bash
NEW_PASSWORD=$(openssl rand -base64 24)
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring rollout restart deployment monitoring-grafana
echo "New password: $NEW_PASSWORD"
```

### Procedure: Scale a service

```bash
# Manual:
kubectl -n petclinic-dev scale deployment <service> --replicas=3

# Persistent (via Git):
# Edit helm-values/dev.yaml or the per-service file, set replicaCount:
# Commit + push → ArgoCD picks it up.
```

---

## 5. Verification

After day-1 deployment, run through this checklist:

```bash
# Cluster nodes
kubectl get nodes
# Expect: 2+ nodes Ready

# All Applications Synced + Healthy in ArgoCD
kubectl -n argocd get applications
# Expect: every entry Synced / Healthy

# Petclinic pods up
kubectl -n petclinic-dev get pods
# Expect: 8 services × 1 replica each, all Running 1/1

# Monitoring stack up
kubectl -n monitoring get pods
# Expect: prometheus, grafana, kube-state-metrics, node-exporter (x2), operator, loki, promtail (x2), zipkin

# External Secrets Operator up + ClusterSecretStore Healthy
kubectl -n external-secrets get pods
# Expect: external-secrets, external-secrets-cert-controller, external-secrets-webhook — all Running 1/1

kubectl get clustersecretstore aws-secrets-manager
# Expect STATUS: Valid (means ESO successfully called AWS Secrets Manager)

# Materialised K8s secrets (created by ExternalSecret CRs after sync)
kubectl -n petclinic-dev get secrets
# Expect: rds-credentials, openai-api-key (alongside default tokens)

# RDS reachable from cluster
kubectl -n petclinic-dev run mysql-probe --rm -it --restart=Never \
  --image=mysql:8.0 -- \
  mysql -h "$(terraform -chdir=../terraform/environments/dev output -raw rds_endpoint)" \
  -upetclinic -p"$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d)" \
  -e "SHOW DATABASES;"

# Functional check — list owners through the gateway
kubectl -n petclinic-dev port-forward svc/api-gateway 8080:8080 &
curl http://localhost:8080/api/customer/owners
```

In the Grafana UI:
- Datasources → Prometheus, Loki, Zipkin all listed and "Working"
- Dashboards → "Kubernetes / Compute Resources / Cluster" shows live data
- Explore → switch to Loki → query `{namespace="petclinic-dev"}` → see pod logs
- Explore → switch to Zipkin → service names appear after a few API calls

---

## 6. Troubleshooting

### 6.1 — `EntityAlreadyExists: Provider with url ... already exists`

The GitHub OIDC provider already exists in the AWS account. The terraform module supports this — set `create_github_oidc_provider = false` in [terraform.tfvars](../terraform/environments/dev/terraform.tfvars) and the module will look it up via data source.

### 6.2 — `Member must satisfy regular expression pattern: [\p{L}\p{Z}\p{N}_.:/=+\-@]*`

A resource tag value contains a character outside AWS's allowed set (commonly `*` or em-dash `—`). Find the tag with:

```bash
grep -rE 'Name\s*=\s*"[^"]*[^a-zA-Z0-9_./:=+@\\-]' terraform/
```

Replace with ASCII equivalents.

### 6.3 — ACM cert validation hangs

`aws_acm_certificate_validation` blocks `terraform apply` until DNS validation succeeds, which requires Route 53 to be authoritative for the domain. If Spaceship hasn't been updated yet, the apply hangs ~75 min then fails.

**Resolution path A (recommended):**
1. Set `domain_name = ""` in [terraform.tfvars](../terraform/environments/dev/terraform.tfvars)
2. Apply — everything except DNS comes up
3. Delegate Spaceship NS to Route 53 (see [§2.5](#25-delegate-the-domain-at-spaceship))
4. Set `domain_name = "pawscare.online"` and apply again

**Resolution path B:** Start the apply with `domain_name` set, copy the NS records within 5 min, paste into Spaceship before the timeout.

### 6.4 — Helm provider: `Kubernetes cluster unreachable: the server has asked for the client to provide credentials`

The IAM principal running terraform doesn't have an EKS access entry, so the K8s API server returns 401 when the Helm provider tries to install a chart.

EKS clusters created with `authentication_mode = API_AND_CONFIG_MAP` (this project's setting) **do not** automatically grant cluster-admin to the role that created them — unlike legacy `CONFIG_MAP` mode.

**Codified fix:** [terraform/environments/dev/main.tf](../terraform/environments/dev/main.tf) creates an `aws_eks_access_entry` + `aws_eks_access_policy_association` for `aws_caller_identity.current.arn` (auto-resolved, handles assumed-role ARNs). On every `terraform apply`, the caller is associated with `AmazonEKSClusterAdminPolicy`.

**Manual one-time unblock** if you need to fix it right now without re-running terraform:

```bash
# Resolve your principal ARN
ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
if [[ "$ARN" == arn:aws:sts::* ]]; then
  ROLE_NAME=$(echo "$ARN" | cut -d/ -f2)
  PRINCIPAL_ARN="arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}"
else
  PRINCIPAL_ARN="$ARN"
fi
echo "Principal: $PRINCIPAL_ARN"

# Add access entry + admin policy
aws eks create-access-entry \
  --cluster-name petclinic-dev --region us-east-2 \
  --principal-arn "$PRINCIPAL_ARN"

aws eks associate-access-policy \
  --cluster-name petclinic-dev --region us-east-2 \
  --principal-arn "$PRINCIPAL_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

Then verify:
```bash
aws eks update-kubeconfig --name petclinic-dev --region us-east-2
kubectl get nodes   # should now succeed
```

### 6.5 — `Unsupported Kubernetes minor version update from X.Y to X.Z`

AWS auto-upgrades EKS minor versions as they approach end-of-life. When the live cluster moves ahead of `var.cluster_version` in tfvars, terraform sees the drift, plans a "version update" back to the older number, and EKS refuses (downgrades aren't allowed).

**Codified fix:** the `aws_eks_cluster.this` resource has `lifecycle { ignore_changes = [version] }` so terraform never tries to manage version changes after creation. You bump versions intentionally via AWS console or `aws eks update-cluster-version`, then update `cluster_version` in tfvars for documentation.

**If you hit this on an existing apply**, simply update `cluster_version` to match what AWS shows:

```bash
# What version does AWS say the cluster is at?
aws eks describe-cluster --name petclinic-dev --region us-east-2 \
  --query 'cluster.version' --output text
```

Then edit [terraform.tfvars](../terraform/environments/dev/terraform.tfvars) → set `cluster_version` to that value, re-plan, re-apply.

### 6.6 — EBS CSI add-on stuck in `CREATING`

The aws-ebs-csi-driver add-on times out unless its IRSA role with `AmazonEBSCSIDriverPolicy` is wired up. The `eks` module creates this role at [terraform/modules/eks/main.tf:168-225](../terraform/modules/eks/main.tf#L168). If you see this error on a fresh apply:

```bash
aws eks delete-addon --cluster-name petclinic-dev --addon-name aws-ebs-csi-driver --region us-east-2
terraform state rm module.eks.aws_eks_addon.ebs_csi
terraform apply
```

### 6.7 — Pod stuck in `Pending` with `FailedScheduling`: insufficient memory

The dev cluster's 2× t4g.small nodes are tight (~3.5 GiB usable total). Adding observability + 8 services + ArgoCD can push it over.

```bash
kubectl describe pod <name> -n <ns> | tail -20
# Look for "0/2 nodes are available: 2 Insufficient memory"
```

Fixes:
- Karpenter should add a 3rd node automatically — check with `kubectl get nodes` after a minute
- Or scale down a non-critical service: `kubectl -n petclinic-dev scale deployment admin-server --replicas=0`
- Or upgrade base nodes to `t4g.medium` (edit `node_instance_types` in [dev/main.tf](../terraform/environments/dev/main.tf), re-apply)

### 6.8 — ArgoCD app stuck `OutOfSync` after merging the tag PR

Most common cause: the chart's `releaseName` was changed. Less common: ArgoCD hasn't polled yet (default 3-min polling interval).

Force a refresh:
```bash
kubectl -n argocd patch application <service> --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### 6.9 — Grafana shows "Loki: Datasource is not working"

Loki pod isn't ready or the service name resolution is off.

```bash
kubectl -n monitoring get pods -l app=loki
# Expect: 1/1 Running

kubectl -n monitoring run net-test --rm -it --restart=Never \
  --image=busybox:1.36 -- wget -qO- http://loki:3100/ready
# Expect: "ready"
```

If Loki is up but Grafana still can't reach it, the datasource URL in [helm-values/monitoring.yaml](../helm-values/monitoring.yaml) may have drifted from the chart's actual service name. Default service name is `loki` in namespace `monitoring`.

### 6.10 — ESO ClusterSecretStore status `Invalid` / `NotReady`

Symptoms: `kubectl get clustersecretstore aws-secrets-manager` shows STATUS = Invalid, and `ExternalSecret` resources never materialise K8s Secrets.

```bash
# Show the failure reason
kubectl describe clustersecretstore aws-secrets-manager | tail -20
```

Common causes:

| Symptom | Fix |
|---|---|
| `webIdentityErr ... AccessDenied` | IRSA trust policy doesn't match. Check the role's trust policy in IAM — sub claim must equal `system:serviceaccount:external-secrets:external-secrets`. |
| `AccessDeniedException ... not authorized to perform secretsmanager:GetSecretValue` | The IRSA role's inline policy is too narrow. Confirm the resource ARN pattern is `arn:aws:secretsmanager:us-east-2:*:secret:petclinic/dev/*` |
| `service account "external-secrets" not found` | The ESO Helm release failed; check `kubectl -n external-secrets get pods` |

After fixing, kick a reconcile:
```bash
kubectl -n petclinic-dev annotate externalsecret rds-credentials force-sync=$(date +%s) --overwrite
```

### 6.11 — `ExternalSecret` materialises empty `Secret` (zero data keys)

Usually means the AWS Secrets Manager value isn't shaped the way the chart's `data:` block expects.

For `rds-credentials`: AWS SM stores a JSON object `{username,password,host,port,dbname}`. The chart's [externalsecret.yaml](../helm/petclinic-service/templates/externalsecret.yaml) references each field by `property:`. If terraform's [rds module](../terraform/modules/rds/main.tf) wrote a non-JSON value (e.g. just the password string), the property lookup fails.

```bash
aws secretsmanager get-secret-value --secret-id petclinic/dev/rds-credentials --region us-east-2 \
  --query SecretString --output text | jq .
# Should print JSON with all 5 keys
```

### 6.12 — Flyway db-migrations Job fails

The migration Job runs in `petclinic-dev` namespace at ArgoCD sync wave -5, before config-server. Common failures and recovery:

#### 6.12a — `Connection refused` or `Communications link failure`

Flyway tries to connect and fails. Either RDS isn't reachable from the cluster, or the `rds-credentials` Secret doesn't exist yet.

```bash
# Check the Secret exists and has the right keys
kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data}' | jq 'keys'
# Expect: ["SPRING_DATASOURCE_PASSWORD","SPRING_DATASOURCE_URL","SPRING_DATASOURCE_USERNAME"]

# Verify connectivity from a temp pod in the cluster
RDS_HOST=$(kubectl -n petclinic-dev get secret rds-credentials \
  -o jsonpath='{.data.SPRING_DATASOURCE_URL}' | base64 -d | sed 's|jdbc:mysql://||; s|:3306.*||')
kubectl -n petclinic-dev run net-test --rm -it --restart=Never \
  --image=busybox:1.36 -- nc -vz "$RDS_HOST" 3306
# Expect: "open"
```

If `net-test` fails: the RDS security group blocks the node SG. Check [terraform/modules/vpc/main.tf](../terraform/modules/vpc/main.tf) — the `rds_mysql_from_nodes` rule should allow TCP 3306 from the node SG.

If the Secret is missing: ESO hasn't materialised it yet. See §6.10 + §6.11.

#### 6.12b — `Migration checksum mismatch for migration version <N>`

You edited a `V<N>__*.sql` file that was already applied to MySQL. Flyway records SHA-256 checksums in the `flyway_schema_history` table and refuses to re-apply a version with a different checksum.

**Don't** edit applied migrations. Add a new `V<N+1>__fix.sql` instead.

If you must (dev only), run `flyway repair` ad-hoc to recompute checksums, then re-sync the Application:

```bash
kubectl -n petclinic-dev run flyway-repair --rm -it --restart=Never \
  --image=428101261622.dkr.ecr.us-east-2.amazonaws.com/petclinic-dev/db-migrations:latest \
  --env="FLYWAY_URL=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_URL}' | base64 -d)" \
  --env="FLYWAY_USER=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_USERNAME}' | base64 -d)" \
  --env="FLYWAY_PASSWORD=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d)" \
  -- repair
```

#### 6.12c — `No database found to handle jdbc:mysql://...`

The MySQL JDBC driver isn't in the image. The current [db/migrations/Dockerfile](../../spring-petclinic-microservices/db/migrations/Dockerfile) explicitly adds it from a builder stage; if a regenerated Dockerfile drops that step, the error fires on first run.

Confirm the Dockerfile contains:
```
FROM alpine:3.20 AS mysql-driver
ADD https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar /mysql-connector-j.jar
FROM flyway/flyway:10.22.0-alpine
COPY --from=mysql-driver /mysql-connector-j.jar /flyway/drivers/mysql-connector-j.jar
```

Rebuild + push by re-running the `Build DB Migration Image` workflow (`gh workflow run db-migrations-image.yml` from the app repo).

#### 6.12d — Job stuck `Pending`

```bash
kubectl -n petclinic-dev describe pod -l app.kubernetes.io/name=db-migrations | tail -20
```

Likely causes:
- `Insufficient memory` on the cluster → see §6.7
- `ImagePullBackOff` → the ECR repo `petclinic-dev/db-migrations` doesn't exist, or nodes can't read it. Confirm `terraform/environments/dev/main.tf` includes `"db-migrations"` in `local.services`.

#### 6.12e — Re-running migrations ad-hoc

You changed nothing in `db/migrations/` but want Flyway to run again (e.g. after manual schema cleanup):

```bash
# Trigger an ArgoCD re-sync — the Job is treated as a sync hook so it gets recreated
kubectl -n argocd patch application db-migrations --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

Or one-shot pod (bypasses ArgoCD entirely, useful when troubleshooting):

```bash
kubectl -n petclinic-dev run flyway-once --rm -it --restart=Never \
  --image=428101261622.dkr.ecr.us-east-2.amazonaws.com/petclinic-dev/db-migrations:<your-sha> \
  --env="FLYWAY_URL=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_URL}' | base64 -d)" \
  --env="FLYWAY_USER=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_USERNAME}' | base64 -d)" \
  --env="FLYWAY_PASSWORD=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d)" \
  -- migrate
```

#### 6.12f — Inspect Flyway's record of what's been applied

```bash
RDS_HOST=$(kubectl -n petclinic-dev get secret rds-credentials \
  -o jsonpath='{.data.SPRING_DATASOURCE_URL}' | base64 -d | sed 's|jdbc:mysql://||; s|:3306.*||')
PASS=$(kubectl -n petclinic-dev get secret rds-credentials \
  -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d)
kubectl -n petclinic-dev run mysql-probe --rm -it --restart=Never \
  --image=mysql:8.0 -- mysql -h "$RDS_HOST" -upetclinic -p"$PASS" petclinic \
  -e "SELECT version, description, success, installed_on FROM flyway_schema_history ORDER BY installed_rank;"
# Expect 6 rows (V1 → V6) with success = 1
```

### 6.13 — Zipkin shows no spans

Three checks in order:

```bash
# 1. Zipkin pod up?
kubectl -n monitoring get pods -l app.kubernetes.io/name=zipkin

# 2. Services have ZIPKIN_ENDPOINT env?
kubectl -n petclinic-dev exec deploy/customers-service -- env | grep ZIPKIN_ENDPOINT
# Expect: http://zipkin.monitoring.svc.cluster.local:9411/api/v2/spans

# 3. Generate a trace then check
curl http://<api-gateway-port-forward>/api/customer/owners
# Wait 10 sec, then in Zipkin UI: select service name → Run Query
```

If no spans appear, the service is probably missing `management.tracing.sampling.probability` config — check [§5](#5-verification) earlier and [application.yml](../../spring-petclinic-microservices/spring-petclinic-customers-service/src/main/resources/application.yml) of the affected service.

---

## 7. Rollback and cleanup

### Roll back the last app deploy

Revert the most recent merged commit in the infra repo's main branch. ArgoCD detects the revert and syncs back to the prior image tag.

### Delete a single service from the cluster

```bash
kubectl -n argocd patch application <service> --type merge \
  -p '{"metadata":{"deletionTimestamp":null}}'
kubectl -n argocd delete application <service>
# Optionally also remove from k8s/argocd/applications/dev/ in git
```

### Tear down the entire dev environment

**Destructive — destroys ALL infrastructure including the EKS cluster, RDS data, and ECR images.**

```bash
# 1. Delete ArgoCD Applications first so their finalizers don't block resource deletion
kubectl -n argocd delete application --all

# 2. Wait for K8s workloads to terminate
kubectl -n petclinic-dev get pods    # should show no resources
kubectl -n monitoring get pods       # should show no resources

# 3. Terraform destroy
cd terraform/environments/dev
terraform destroy
```

The `block-destroy.sh` hook will warn before running `terraform destroy` via Claude Code. If you really want to destroy, run it from your shell directly.

### Reset just the database

```bash
kubectl -n petclinic-dev rollout restart deployment customers-service visits-service vets-service
# Spring auto-reinitialises the schema on startup (spring.sql.init.mode=always)
```

To truly wipe the data, drop the schema in RDS:
```bash
# Get the RDS endpoint + password from terraform/k8s
ENDPOINT=$(terraform -chdir=terraform/environments/dev output -raw rds_endpoint)
PASS=$(kubectl -n petclinic-dev get secret rds-credentials -o jsonpath='{.data.SPRING_DATASOURCE_PASSWORD}' | base64 -d)
mysql -h "$ENDPOINT" -upetclinic -p"$PASS" -e "DROP DATABASE petclinic; CREATE DATABASE petclinic;"
```

---

## Related documents

- [README.md](../README.md) — repo overview and tech stack
- [CLAUDE.md](../CLAUDE.md) — conventions for AI-assisted edits
- [docs/technical-spec.md](./technical-spec.md) — authoritative resource specifications (CIDRs, ports, SG rules, …)
