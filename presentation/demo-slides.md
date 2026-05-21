# Petclinic Platform — Team Demo Deck

**Total runtime:** 20 minutes
**Format:** 15 slides + live technical walkthrough
**Project:** Spring Petclinic Microservices on AWS (EKS + GitOps)

---

## Time budget (20:00)

| # | Slide | Presenter | Time |
|---|---|---|---|
| 1 | Team Introduction | Amarachi Ezeonyekwere | 0:45 |
| 2 | Agenda & Protocols | Amarachi Ezeonyekwere | 0:30 |
| 3 | Business Context & Project Charter | Hemlal Bhattari | 1:30 |
| 4 | How We Delivered — Sprint Planning | Ahmed Ibrahim | 1:00 |
| 5 | How We Delivered — Ceremonies & Flow | Mustapha Nurudeen | 1:00 |
| 6 | Cloud Foundation — Network & State | Derek Owusu Bekoe | 1:30 |
| 7 | Cloud Foundation — EKS, RDS, Secrets | Yassin Ait Quabbou | 1:30 |
| 8 | DevOps — CI Pipeline (Build & Push) | Godwin Chinedu | 1:15 |
| 9 | DevOps — CD with ArgoCD & Helm | Sofia EL Maftah | 1:15 |
| 10 | SRE — Observability & SLOs | Amarachi Ezeonyekwere | 1:15 |
| 11 | SRE — Resilience & Incident Response | Yaa Kesewaa Yeboah | 1:15 |
| 12 | Documentation — Architecture & ADRs | Adaeze | 0:45 |
| 13 | Documentation — Runbooks & Onboarding | Obianuju | 0:45 |
| 14 | Live Technical Walkthrough | Amarachi & Derek | 5:00 |
| 15 | Closing Remarks & Q&A | Amarachi Ezeonyekwere | 0:45 |
| | **Total** | | **20:00** |

---

# SLIDE 1 — Team Introduction

**Presenter:** Amarachi Ezeonyekwere — 45 sec

### Title
**Petclinic Platform — A Production-Grade AWS DevOps Project**

### Visual layout
- 11 headshots in a grid, each with **Name + Role** caption underneath.
- Course name + group name in the header.
- Date in the footer.

### Headshot grid (suggested layout — 4 columns × 3 rows)

| | | | |
|---|---|---|---|
| 📷 **Amarachi Ezeonyekwere** — Intro & Protocols / SRE | 📷 **Hemlal Bhattari** — Project Manager | 📷 **Ahmed Ibrahim** — Scrum Master | 📷 **Mustapha Nurudeen** — Scrum Master |
| 📷 **Derek Owusu Bekoe** — Cloud Infrastructure Engineer | 📷 **Yassin Ait Quabbou** — Cloud Infrastructure Engineer | 📷 **Godwin Chinedu** — DevOps Engineer | 📷 **Sofia EL Maftah** — DevOps Engineer |
| 📷 **Yaa Kesewaa Yeboah** — SRE | 📷 **Adaeze** — Documentation Lead | 📷 **Obianuju** — Documentation Lead | |

### Speaker notes (Amarachi)
> "Good [morning/afternoon] everyone. We are the Petclinic Platform team. Over the next 20 minutes we'll walk you through how 11 of us — split across project management, cloud, DevOps, SRE and documentation — designed, built and operated a production-grade AWS platform for the Spring Petclinic microservices application. I'm Amarachi and I'll be your host for the session."

---

# SLIDE 2 — Agenda & Protocols

**Presenter:** Amarachi Ezeonyekwere — 30 sec

### Agenda

1. **Why we built this** — business context (Hemlal)
2. **How we worked** — Scrum delivery (Ahmed + Mustapha)
3. **What we built** — Cloud + DevOps (Derek, Yassin, Godwin, Sofia)
4. **How we keep it up** — SRE (Amarachi + Yaa Kesewaa)
5. **How we capture knowledge** — Docs (Adaeze + Obianuju)
6. **Live walkthrough** (Amarachi + Derek)
7. **Q&A**

### Protocols
- **Questions** → hold to the end (Q&A slot)
- **Mics muted** during presentation
- **Chat open** for written questions any time

### Screenshot placeholder
`[📷 Agenda banner / clock graphic — optional]`

---

# SLIDE 3 — Business Context & Project Charter

**Presenter:** Hemlal Bhattari (Project Manager) — 1 min 30 sec

### The business problem
Spring Petclinic is an 8-service Spring Boot microservices application. It needs an AWS platform that is:
1. **Highly Available** — survives node, AZ and service failures
2. **Resilient** — auto-recovers, self-heals, rolls back safely
3. **Secure** — no public secrets, least-privilege IAM, encrypted at rest

### Project scope (what we committed to)
- **17 epics**, dependency-chained: Bootstrap → VPC → EKS → RDS → Secrets → K8s → Helm → ArgoCD → Observability → Docs
- **1 deployed environment** (dev) — designed so prod is a `terraform.tfvars` change away
- **8 microservices** deployed via GitOps, image promotion via Git commit

### Why these decisions (PM view)
| Decision | Why | Trade-off |
|---|---|---|
| Single dev env first | De-risk the architecture before duplicating | Prod parity deferred to next sprint |
| GitOps over push-CD | Auditable, declarative, self-healing | Steeper team learning curve |
| Free-tier sizing (t4g.small, db.t4g.micro) | Course budget = $0 | Not load-tested at scale |

### Screenshot placeholders
- `[📷 Jira backlog overview — 17 epics, dependency chart]`
- `[📷 Sprint burndown or velocity chart]`

### Speaker notes (Hemlal)
> "Our charter was simple to say and hard to deliver: take an 8-service Spring app and put it on AWS in a way a real business would accept. That means **High Availability, Resilience and Security** are not nice-to-haves — they are the acceptance criteria. We scoped 17 epics in a strict dependency chain so the team always knew what unblocked what. We optimised for learning velocity and cost, which is why you'll see a single dev environment and free-tier sizing — but every decision was made so that scaling to prod is a configuration change, not a re-architecture."

---

# SLIDE 4 — How We Delivered: Sprint Planning

**Presenter:** Ahmed Ibrahim (Scrum Master) — 1 min

### What
- **2-week sprints**, story-pointed backlog in Jira
- Every story references a section of `docs/technical-spec.md` — the **single source of truth** for CIDRs, ports, sizes, thresholds
- Definition of Done includes: code in Git, `terraform plan` clean, peer review, runbook updated

### How (sprint planning ritual)
1. Refinement on Monday — break epics into stories sized ≤ 5 SP
2. Planning on Tuesday — pull stories that respect the dependency chain (VPC before EKS, EKS before Helm…)
3. Spike stories carved out for unknowns (e.g. Karpenter, External Secrets)

### Why this worked
- The dependency chain stopped two engineers from blocking each other.
- The spec-first approach meant **no ambiguity at implementation time** — engineers didn't argue about CIDR ranges; they read the spec.

### Trade-off
- Heavy upfront spec writing slowed Sprint 1, but cut rework in Sprints 2–4.

### Screenshot placeholders
- `[📷 Jira sprint board — columns To Do / In Progress / Review / Done]`
- `[📷 Technical spec table of contents]`

---

# SLIDE 5 — How We Delivered: Ceremonies & Flow

**Presenter:** Mustapha Nurudeen (Scrum Master) — 1 min

### Ceremonies we ran
- **Daily standups** (15 min, async on busy days via Slack)
- **Mid-sprint check-in** — re-baseline if scope drifted
- **Sprint review** — demo to PO + cross-team
- **Retro** — kept a "stop / start / continue" log

### How impediments were handled
- Logged in Jira as `Impediment` issues, owned by us (the SMs)
- Escalated to the PM if unresolved in 24 h
- Common ones we cleared: AWS quota raises, ECR auth issues, Helm value collisions

### Why ceremonies stayed lightweight
- We replaced status-meeting time with **written async updates** so engineers kept flow state
- Retros directly fed the next sprint's process changes (e.g. introducing pre-commit `terraform fmt` hook)

### Trade-off
- Async-first risks silent blockers — mitigated by SMs proactively pinging quiet team members on Day 3 of every sprint.

### Screenshot placeholders
- `[📷 Slack standup thread]`
- `[📷 Retro board — Stop / Start / Continue]`

---

# SLIDE 6 — Cloud Foundation: Network & State

**Presenter:** Derek Owusu Bekoe (Cloud Infrastructure Engineer) — 1 min 30 sec

### What we built
- **VPC module** — `petclinic-dev-vpc`, multi-AZ public subnets, IGW, security groups
- **Remote state** — S3 bucket + DynamoDB table for state locking (`scripts/bootstrap-state.sh`)
- **Tagging standard** enforced on every resource: `Project=petclinic`, `Environment=dev`, `ManagedBy=terraform`

### How (key technical choices)
- **Multi-AZ subnets** across `us-east-2a/b/c` → satisfies EKS minimum and gives node spread
- **State key pattern** `petclinic/dev/terraform.tfstate` → cleanly scales to `petclinic/prod/...`
- **Security groups as the perimeter** — no `0.0.0.0/0` ingress except ALB on 80/443

### Why these decisions
| Need | How we addressed it |
|---|---|
| **High Availability** | Subnets in 3 AZs so EKS can spread pods across failure domains |
| **Resilience** | State locking prevents two engineers from corrupting state |
| **Security** | Default-deny SGs, encryption-at-rest required by org policy in `CLAUDE.md` |

### Trade-off we documented (ADR-0001)
- **All-public subnets, no NAT gateway** — saves ~$32/month per AZ, suitable for learning/dev.
- The compensating control is strict security groups; we explicitly called this out as **NOT prod-ready** in the ADR.

### Screenshot placeholders
- `[📷 AWS console — VPC topology with subnets across 3 AZs]`
- `[📷 terraform/modules/vpc directory tree]`
- `[📷 S3 bucket showing terraform state object]`

---

# SLIDE 7 — Cloud Foundation: EKS, RDS & Secrets

**Presenter:** Yassin Ait Quabbou (Cloud Infrastructure Engineer) — 1 min 30 sec

### What we built
- **EKS module** — managed control plane, 2× `t4g.small` Graviton nodes, OIDC enabled for IRSA
- **RDS module** — MySQL `db.t4g.micro`, encryption at rest, subnet group, parameter group
- **Secrets module** + **External Secrets Operator** — secrets live in AWS Secrets Manager, synced into K8s as native `Secret` objects
- **Karpenter module** scaffolded — IAM, SQS, EventBridge ready for node-level autoscaling
- **ALB Controller + DNS modules** — Route 53 + ACM-issued TLS at the ALB

### How (the resilience story)
- **EKS Managed Node Group** auto-replaces unhealthy nodes
- **IRSA (IAM Roles for Service Accounts)** — pods get AWS creds via OIDC, no static keys
- **External Secrets Operator** — secret rotation in AWS auto-propagates to pods; no redeploys
- **TLS terminated at the ALB** with ACM cert; HTTP → HTTPS redirect

### Why (HA / Resilience / Security mapping)
| Business need | Implementation |
|---|---|
| **High Availability** | Managed node group, multi-AZ subnets, ALB across AZs |
| **Resilience** | Self-healing nodes, ESO auto-resync, RDS automated backups |
| **Security** | IRSA (zero static creds), Secrets Manager, encryption-at-rest, ACM TLS |

### Trade-offs
- **Single-AZ RDS** in dev — saves ~50% of RDS cost; **prod will be Multi-AZ** (one variable flip).
- **ARM/Graviton nodes** — 20% cheaper but required `docker buildx + QEMU` in CI for ARM image builds.

### Screenshot placeholders
- `[📷 AWS EKS console — cluster + node group healthy]`
- `[📷 terraform/modules/ — eks, rds, secrets, karpenter folders]`
- `[📷 External Secrets — ExternalSecret CR + synced K8s Secret]`

---

# SLIDE 8 — DevOps: CI Pipeline (Build & Push)

**Presenter:** Godwin Chinedu (DevOps Engineer) — 1 min 15 sec

### What we built
- **GitHub Actions** workflows in `.github/workflows/`:
  - `terraform.yml` — fmt → validate → plan → apply (gated)
  - `update-image-tags.yml` — build → scan → push → commit new tag back to Git
  - `argocd-install.yml` — bootstraps ArgoCD
- **GitHub OIDC** federation to AWS via `terraform/modules/github-oidc` — **no long-lived AWS keys** in GitHub

### How (the CI flow per service)
1. PR merged to `main` → workflow triggers
2. `docker buildx` builds **ARM64** image (for Graviton nodes)
3. **Trivy** scans; build fails on CRITICAL CVEs
4. Image tagged with `${GITHUB_SHA::7}` (never `latest`) and pushed to ECR
5. Workflow **commits the new tag** to `helm-values/{service}.yaml`
6. ArgoCD picks up the commit → deploys (covered in next slide)

### Why these decisions
| Decision | Why |
|---|---|
| OIDC, not access keys | **Security** — no leaked credentials risk |
| SHA tags, not `latest` | **Resilience** — deterministic deploys, easy rollbacks |
| Trivy scan in CI | **Security** — shift-left vulnerability gating |
| ECR scan-on-push | **Security** — second layer of defence |

### Trade-off
- ARM image builds need `docker buildx + QEMU` → ~30% longer build time vs native x86. Worth it for the Graviton cost saving.

### Screenshot placeholders
- `[📷 GitHub Actions run — green build + Trivy stage passing]`
- `[📷 ECR console — repos with SHA-tagged images]`
- `[📷 Auto-commit PR updating helm-values/{service}.yaml]`

---

# SLIDE 9 — DevOps: CD with ArgoCD & Helm

**Presenter:** Sofia EL Maftah (DevOps Engineer) — 1 min 15 sec

### What we built
- **One generic Helm chart** (`helm/petclinic-service/`) shared by all 8 services
- **Per-service values** in `helm-values/{service}.yaml` (ports, env vars, init containers)
- **Per-env values** in `helm-values/dev.yaml` (replicas, HPA, PDB, resource quotas)
- **ArgoCD** with 8 `Application` CRDs, **auto-sync + prune + self-heal**

### How (the GitOps flow)
```
Git commit (new SHA tag)  →  ArgoCD detects drift  →  Helm template renders
   →  kubectl apply to cluster  →  rolling update with probes  →  healthy
```

### Why we picked GitOps over push-CD
| Business need | How GitOps delivers it |
|---|---|
| **Resilience** | `self-heal` reverses out-of-band changes automatically |
| **High Availability** | Helm rolling updates respect PDBs → no all-pod outage |
| **Security** | CI has **zero** `kubectl` permissions; cluster only trusts Git |
| **Auditability** | Every deploy = a Git commit. Rollback = `git revert` |

### Trade-offs
- **One chart for 8 services** — saves massive duplication, but every service must conform to the chart's shape. We accepted that constraint.
- **Auto-sync** can deploy a bad commit faster — mitigated by Trivy + PR review gates upstream.

### Screenshot placeholders
- `[📷 ArgoCD UI — 8 applications all green/synced]`
- `[📷 helm/petclinic-service/ chart tree + helm-values/ folder]`
- `[📷 helm template output for one service rendering successfully]`

---

# SLIDE 10 — SRE: Observability & SLOs

**Presenter:** Amarachi Ezeonyekwere (SRE) — 1 min 15 sec

### What we built
- **Prometheus + Grafana** stack via Helm (`helm-values/monitoring.yaml`)
- **Loki** for log aggregation (`helm-values/loki.yaml`) + FluentBit → CloudWatch
- **Zipkin** for distributed tracing across the 8 services (`k8s/base/zipkin/`)
- **Spring Boot Actuator** `/actuator/health/{readiness,liveness}` wired into every Deployment

### How (the SLO framing)
| SLI | Target SLO |
|---|---|
| API Gateway availability | 99.5% over 30 days |
| p95 request latency (gateway → backend) | < 500 ms |
| Deploy success rate | > 95% (ArgoCD sync) |

### Why this matters to the business
- **High Availability** — readiness probes mean traffic is never sent to a starting pod
- **Resilience** — liveness probes restart hung containers automatically
- **Security observability** — CloudWatch logs are centralized and audit-grade

### Trade-off
- Full observability stack adds ~15% to cluster memory footprint. We accepted it; you cannot operate what you cannot see.

### Screenshot placeholders
- `[📷 Grafana dashboard — petclinic service overview]`
- `[📷 Zipkin trace — request flow gateway → customers → visits]`
- `[📷 CloudWatch log group with FluentBit-shipped logs]`

---

# SLIDE 11 — SRE: Resilience & Incident Response

**Presenter:** Yaa Kesewaa Yeboah (SRE) — 1 min 15 sec

### What we built
- **Runbook** (`docs/runbook.md`) for the top 10 day-2 ops: restart, scale, rollback, RDS failover, ArgoCD re-sync
- **Cost-saving lifecycle scripts** (`scripts/`):
  - `env-status.sh` — what's running right now?
  - `stop-env.sh` — stop RDS, scale EKS nodes to 0 overnight
  - `start-env.sh` — bring it back
- **Safety hooks** (`.claude/hooks/`) — block `terraform destroy`, `rm -rf` on infra dirs, secret commits, MCP destroy calls

### How (the resilience design)
| Failure mode | Auto-recovery mechanism |
|---|---|
| Pod crash | livenessProbe → kubelet restart |
| Node failure | Managed node group + Karpenter scaffolding |
| Bad deploy | ArgoCD self-heal + `git revert` for rollback |
| Lost AWS credentials | IRSA — re-issued automatically |
| Engineer typo | Pre-commit hooks block destructive ops |

### Why we invested in hooks before incidents
- A blocked `terraform destroy` costs 5 seconds of friction.
- An accidental `terraform destroy` costs 4 hours of rebuild.

### Trade-off
- Hooks can frustrate engineers ("why is this blocked?") — mitigated by clear error messages pointing to `docs/runbook.md`.

### Screenshot placeholders
- `[📷 docs/runbook.md table of contents]`
- `[📷 Terminal — block-destroy.sh refusing a terraform destroy]`
- `[📷 stop-env.sh / start-env.sh in action]`

---

# SLIDE 12 — Documentation: Architecture & ADRs

**Presenter:** Adaeze (Documentation Lead) — 45 sec

### What we built
- **Technical specification** (`docs/technical-spec.md`) — authoritative for **every** value (CIDRs, ports, instance sizes, probe timings, alert thresholds)
- **Architecture Decision Records** — e.g. `0001-public-subnets.md` documenting the trade-off Derek mentioned
- Every Jira story **references a spec section** — no ambiguity at implementation time

### Why this matters
- New engineers can answer "why did we do it this way?" without asking the original author
- ADRs prevent us from re-litigating decisions in future sprints
- The spec doubles as the **acceptance criteria** for PRs

### Screenshot placeholders
- `[📷 docs/technical-spec.md TOC]`
- `[📷 docs/adr/0001-public-subnets.md preview]`

---

# SLIDE 13 — Documentation: Runbooks & Onboarding

**Presenter:** Obianuju (Documentation Lead) — 45 sec

### What we built
- **Runbook** (`docs/runbook.md`) — day-2 ops, indexed by symptom
- **Incident playbook** — common failures and their fixes
- **Onboarding guide** — new engineer can deploy a service end-to-end on day 1
- **Jira backlog** doc — links epics to spec sections to PRs

### Why
- **Resilience** is not just code — it's people knowing what to do at 2 AM
- Docs live in the same repo as the code → reviewed in the same PRs → never go stale

### Screenshot placeholders
- `[📷 docs/runbook.md — "Rollback a service" section]`
- `[📷 docs/onboarding.md "Day 1" checklist]`

---

# SLIDE 14 — Live Technical Walkthrough

**Presenters:** Amarachi & Derek — 5 min total (split ~2:30 each)

### Walkthrough script (rehearsed in this order)

**Part A — Derek (2:30)**
1. **(30s)** Repo tour — `terraform/`, `k8s/`, `helm/`, `helm-values/`, `docs/`
2. **(45s)** Show `terraform plan` output for the VPC module — point out tags, multi-AZ subnets, SGs
3. **(45s)** AWS console — VPC topology + EKS cluster healthy + RDS instance
4. **(30s)** Hand off: "Amarachi will show how deploys flow into this cluster"

**Part B — Amarachi (2:30)**
5. **(45s)** Trigger / show a GitHub Actions run — Trivy scan, image push to ECR, auto-commit
6. **(45s)** ArgoCD UI — 8 apps green; click into one to show synced manifests
7. **(30s)** Grafana dashboard + Zipkin trace of a live request
8. **(30s)** Demonstrate a hook block: `terraform destroy` → blocked → point to runbook

### Backup if live demo fails
- Pre-recorded 90-second screen capture saved at `presentation/assets/walkthrough-fallback.mp4`
- Screenshots in slides 6–11 are the visual fallback

### Screenshot placeholders (in case demo fails)
- `[📷 Repo tree in VS Code]`
- `[📷 terraform plan output snippet]`
- `[📷 ArgoCD app tree — all green]`
- `[📷 Grafana service dashboard]`

---

# SLIDE 15 — Closing Remarks & Q&A

**Presenter:** Amarachi Ezeonyekwere — 45 sec

### What we delivered (in one breath)
> "An 8-service production-shaped AWS platform: Terraform-managed, GitOps-deployed, observability-instrumented, runbook-supported, and built by 11 people working off a single source of truth."

### How we addressed the three business needs

| Need | Where it shows up |
|---|---|
| **High Availability** | Multi-AZ VPC • EKS managed node group • ALB across AZs • Helm PDBs |
| **Resilience** | ArgoCD self-heal • livenessProbes • Karpenter • backups • safety hooks |
| **Security** | OIDC (no static keys) • IRSA • Secrets Manager + ESO • Trivy + ECR scan • encryption at rest • ACM TLS |

### What's next (transparently)
- Promote to a `prod` environment (variable change, not re-architecture)
- Multi-AZ RDS + private subnets + NAT (the ADR-0001 follow-up)
- Chaos engineering + DR game days

### Thank you
- Thanks to our PM, Scrum Masters, and Documentation team for the runway
- Thanks to the course leads
- **Questions?** 🙋

### Screenshot placeholder
`[📷 Team photo or composite of all 11 headshots — "Thank you" overlay]`

---

# Appendix A — Production-ready slide-format checklist

Before exporting to PowerPoint / Google Slides / Keynote:

- [ ] Replace every `📷 [...]` block with an actual screenshot
- [ ] Add each presenter's name in the slide footer (consistent font)
- [ ] Add slide number `(N / 15)` in the footer
- [ ] Use a **single colour palette** (suggest: AWS-style navy + Spring green)
- [ ] Keep ≤ 30 words of visible text per slide — speakers expand verbally
- [ ] Rehearse the full deck once end-to-end with a stopwatch
- [ ] Verify the walkthrough demo works on the **presentation laptop's network**
- [ ] Have the fallback recording loaded and ready

# Appendix B — Speaking timing tips

- Most slides land between **45 and 90 seconds**. Watch the clock for slides 3, 6, 7 — they have the most content.
- Hand-offs between presenters should be **one sentence**: "Over to Yassin to cover the compute layer."
- If you fall behind, the safest cuts are: slide 4 → 30s, slide 12 → 30s, slide 13 → 30s. Never cut the walkthrough.
