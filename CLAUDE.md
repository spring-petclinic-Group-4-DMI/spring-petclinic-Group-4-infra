# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure-only repo for the **Spring PetClinic** microservices project (Group 4 capstone). The application source lives in a sibling repo (`spring-petclinic-Group-4-DMI/spring-petclinic-microservices` — referenced by `var.github_app_repo` in IAM trust). This repo contains four independent stacks that ship the platform:

- `terraform/` — AWS infrastructure (VPC, EKS, RDS, ECR, ALB, DNS, IAM, Secrets Manager)
- `helm/` — One chart per microservice, deployed by ArgoCD (not by `helm install` directly)
- `argocd/` — Application + AppProject manifests; ArgoCD watches the `staging` branch of this repo
- `db/migrations/` — Flyway-versioned SQL applied to RDS MySQL at deploy time

These stacks reference each other indirectly through AWS resource names and Kubernetes service names, not through code imports. A change to a Helm chart's image tag or service name has implications for the ArgoCD app and the ALB TargetGroupBinding — verify all three when renaming.

## Commands

Terraform (run from `terraform/environments/staging/`):
```bash
terraform init      # uses S3 backend "spc-staging-ue1-tfstate", key "dns/terraform.tfstate"
terraform fmt -recursive  # required before PR; CONTRIBUTING enforces this
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

`terraform.tfvars` is gitignored. Copy `terraform.tfvars.example` and fill in `mysql_username`, `mysql_password`, `openai_api_key`, `domain_name`, `staging_alb_name`. CI/CD should inject these via GitHub Actions secrets — never commit real values.

ArgoCD (apps live in cluster, manifests in this repo):
```bash
kubectl apply -f argocd/projects/      # create AppProject first
kubectl apply -f argocd/applications/  # then the 9 Application manifests
kubectl get applications -n argocd
```

Helm charts in this repo are **not** installed manually. ArgoCD reads them from this repo's `staging` branch and syncs into the `petclinic-staging` namespace. To validate a chart locally without deploying:
```bash
helm lint helm/<service-name>
helm template helm/<service-name> -f helm/<service-name>/values-staging.yaml
```

## Architecture

### Terraform composition (staging environment)

`terraform/environments/staging/main.tf` is the only entry point — it composes modules from `terraform/modules/` plus a small root-level metrics-server add-on. Module inputs are wired through outputs, so the implicit dependency order matters:

1. `iam` → creates EKS cluster role, EKS node role, ALB controller role (IRSA), GitHub Actions CI role, Terraform role. The OIDC provider for GitHub Actions trusts both the app repo and this infra repo.
2. `vpc` → 2 public + 2 private subnets across `us-east-1a/b`, NAT gateway, ALB SG, EKS node SG. Subnets are tagged for EKS auto-discovery (`kubernetes.io/role/elb`, `karpenter.sh/discovery`).
3. `ecr` → repositories for the microservice images plus `db-migrations`, with lifecycle policy (untagged expire after 14 days, keep last N tagged).
4. `secrets` → single Secrets Manager entry following the naming standard `spc-stg-ue1-app-secret-01`. Bundles MySQL creds + OpenAI key + extras into one JSON blob.
5. `eks` → EKS cluster `spc-stg-ue1-eks-main`, managed node group, OIDC provider, access entries (Terraform role gets cluster-admin via `EKSClusterAdminPolicy`).
6. `karpenter` → controller/node IAM roles, SQS interruption queue, EventBridge rules.
7. `metrics_server` → cluster metrics API for HPAs.
8. `alb` → Terraform-managed ALB + HTTP→HTTPS redirect + HTTPS listener + AWS Load Balancer Controller + TargetGroupBinding for `api-gateway`. Terraform owns the ALB and target group; the controller only registers pod IP targets.
9. `dns` → Route53 zone, ACM cert with DNS validation, A/AAAA records for `staging.<domain>` and (gated by `create_prod_records`) prod apex + www.
10. `rds` → MySQL 8.0 in private subnets, ingress restricted to EKS node SG only.

**State backend:** all components share `bucket=spc-staging-ue1-tfstate`, `key=staging/terraform.tfstate`. Locking uses the DynamoDB table `spc-staging-ue1-tfstate-lock`.

### Naming standard

Every AWS resource follows `spc-<env>-<region>-<resource>[-<qualifier>]`:
- `spc` = project code (Spring PetClinic)
- `stg` / `prod` = environment code (note: `var.environment = "staging"` for IAM, but `environment_code = "stg"` for resource names — these are different on purpose)
- `ue1` = us-east-1
- examples: `spc-stg-ue1-eks-main`, `spc-stg-ue1-rds-db`, `spc-stg-ue1-alb-external`, `spc-staging-ue1-iam-ro-eks-cluster`

When introducing a new resource, follow this exact pattern. Karpenter discovery tags (`karpenter.sh/discovery = "spc-stg-ue1-eks-main"`) and ALB controller subnet selectors depend on it.

### Helm + ArgoCD wiring

Each `helm/<service>/` chart has three values files:
- `values.yaml` — defaults (full image repo URL `338593158888.dkr.ecr.us-east-1.amazonaws.com/<service>`)
- `values-staging.yaml` — staging overrides (referenced by ArgoCD)
- `values-prod.yaml` — prod overrides (referenced by future prod ArgoCD apps)

ArgoCD applications in `argocd/applications/*.yaml` all point to:
- `repoURL`: this repo
- `targetRevision: staging`
- `path: helm/<service>`
- `helm.valueFiles: [values-staging.yaml]`
- `destination.namespace: petclinic-staging`
- Sync policy: automated, prune, selfHeal, retry 3× with exponential backoff

So merging to `staging` is the deploy trigger. Do **not** add a separate `kubectl apply` step.

### The 9 microservices

`config-server`, `discovery-server`, `api-gateway`, `customers-service`, `vets-service`, `visits-service`, `genai-service`, `admin-server`, `frontend`, plus the `db-migrations` image. The ECR module, the ArgoCD applications directory, and the Helm charts directory must all stay in sync when adding runtime services.

The ALB TargetGroupBinding (in `terraform/modules/alb/main.tf`) routes external traffic only to `api-gateway` on port 8080; internal services are reached via Spring Cloud service discovery, not via the ALB.

## Workflow conventions (from CONTRIBUTING.md)

- Branches: `infra/SPC-XX-...`, `helm/SPC-XX-...`, `fix/SPC-XX-...`, `docs/SPC-XX-...`
- Commits: `SPC-XX: present-tense description`
- PRs always target `staging`, never `main`. Terraform changes need 2 approvals.
- Definition of done: `terraform fmt` + `terraform validate` pass, no credentials/tfstate committed, Jira AC met.

## Things that look wrong but aren't

- `.github/workflows/ci.yml` runs `./mvnw clean install` — this workflow is for the **app** repo and will fail here (no `mvnw`, no `src/`). It was added in commit `5566255` (SPC-47); leave it alone unless explicitly asked to fix.
- `terraform/modules/dns/` exists in working tree as untracked; the old `terraform/modules/dns.bak/` files appear deleted in `git status`. The DNS module was refactored in PR #31 (`feat: refactor terraform modules`) — the `.bak` deletions and the new module are part of the same logical change and should be committed together.
- All modules have hardcoded `spc-stg-ue1-*` names rather than using `var.environment_code`. This is technical debt — when the prod environment is added, these will need parameterizing. Don't pre-emptively refactor unless the task is to add prod.
