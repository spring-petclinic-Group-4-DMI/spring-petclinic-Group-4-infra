#!/usr/bin/env bash
#
# setup-github.sh — One-shot configuration of the GitHub side of the petclinic
# pipeline. Idempotent — safe to re-run.
#
# What it does:
#   1. Verifies prerequisites (gh CLI auth, terraform outputs exist)
#   2. Sanity-checks both repos for secrets that should not be committed
#   3. Creates the two GitHub repos if missing
#   4. Adds git remotes and (optionally) pushes
#   5. Sets repository Secrets and Variables
#   6. Creates the 'dev' GitHub Environment in each repo
#   7. Enables "Allow Actions to create + approve PRs" on the infra repo
#
# Prerequisites:
#   - terraform apply has succeeded locally so the role ARN outputs exist
#   - gh CLI installed and `gh auth login` already done
#   - Sufficient gh perms to create repos under the target org
#
# Usage:
#   ./scripts/setup-github.sh
#
# Override defaults via env vars:
#   GITHUB_ORG=my-org \
#   APP_DIR=/path/to/spring-petclinic-microservices \
#   ./scripts/setup-github.sh

set -euo pipefail

# ── Configuration (env-overridable) ─────────────────────────────────────────
GITHUB_ORG="${GITHUB_ORG:-spring-petclinic-Group-4-DMI}"
INFRA_REPO_NAME="${INFRA_REPO_NAME:-spring-petclinic-Group-4-infra}"
APP_REPO_NAME="${APP_REPO_NAME:-spring-petclinic-microservices}"
REPO_VISIBILITY="${REPO_VISIBILITY:-private}"  # private | public | internal
AWS_REGION_VAR="${AWS_REGION_VAR:-us-east-2}"
AWS_ACCOUNT_ID_VAR="${AWS_ACCOUNT_ID_VAR:-428101261622}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${INFRA_DIR}/terraform/environments/dev"
APP_DIR="${APP_DIR:-$(cd "${INFRA_DIR}/../spring-petclinic-microservices" 2>/dev/null && pwd || true)}"

INFRA_FULL="${GITHUB_ORG}/${INFRA_REPO_NAME}"
APP_FULL="${GITHUB_ORG}/${APP_REPO_NAME}"

# ── Helpers ─────────────────────────────────────────────────────────────────
log()   { printf "\n\033[1;34m══ %s ══\033[0m\n" "$*"; }
ok()    { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
warn()  { printf "  \033[1;33m!\033[0m %s\n" "$*"; }
fail()  { printf "  \033[1;31m✗\033[0m %s\n" "$*" >&2; exit 1; }

ask() {
  # Default-no prompt. Returns 0 only on explicit "y" / "Y".
  local answer
  read -r -p "  → $1 [y/N] " answer
  [[ "${answer,,}" == "y" ]]
}

# ── 1. Prerequisites ────────────────────────────────────────────────────────
log "Prerequisites"

command -v gh        >/dev/null || fail "gh CLI not installed (https://cli.github.com)"
command -v terraform >/dev/null || fail "terraform not installed"
command -v git       >/dev/null || fail "git not installed"
gh auth status >/dev/null 2>&1  || fail "gh not authenticated — run: gh auth login"
ok "gh / terraform / git present; gh authenticated"

[[ -d "$TERRAFORM_DIR" ]] || fail "Terraform dir not found: $TERRAFORM_DIR"
[[ -n "$APP_DIR" && -d "$APP_DIR" ]] || fail "App repo dir not found. Set APP_DIR=/path/to/spring-petclinic-microservices"
ok "Repo paths: infra=$INFRA_DIR  app=$APP_DIR"

# ── 2. Read terraform outputs ───────────────────────────────────────────────
log "Terraform outputs"

cd "$TERRAFORM_DIR"
APP_ROLE_ARN="$(terraform output -raw github_actions_app_role_arn   2>/dev/null || echo "")"
INFRA_ROLE_ARN="$(terraform output -raw github_actions_infra_role_arn 2>/dev/null || echo "")"
cd - >/dev/null

[[ -n "$APP_ROLE_ARN"   ]] || fail "Output github_actions_app_role_arn missing — has terraform applied?"
[[ -n "$INFRA_ROLE_ARN" ]] || fail "Output github_actions_infra_role_arn missing"
ok "App   role:  $APP_ROLE_ARN"
ok "Infra role:  $INFRA_ROLE_ARN"

# ── 3. Prompt for sensitive values not stored anywhere ──────────────────────
log "Sensitive values"

OPENAI_API_KEY="${OPENAI_API_KEY:-}"
if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "  OPENAI_API_KEY is needed for the infra repo (CI terraform apply)."
  read -rsp "  Paste OPENAI_API_KEY (input hidden): " OPENAI_API_KEY
  echo
  [[ -n "$OPENAI_API_KEY" ]] || fail "OPENAI_API_KEY is required"
fi

PLATFORM_REPO_TOKEN="${PLATFORM_REPO_TOKEN:-}"
if [[ -z "$PLATFORM_REPO_TOKEN" ]]; then
  echo "  PLATFORM_REPO_TOKEN must be a fine-grained PAT scoped to $INFRA_FULL"
  echo "    Permissions: Contents=Read+Write, Pull-requests=Read+Write, Metadata=Read"
  echo "    Create at:   https://github.com/settings/tokens?type=beta"
  read -rsp "  Paste PLATFORM_REPO_TOKEN (input hidden): " PLATFORM_REPO_TOKEN
  echo
  [[ -n "$PLATFORM_REPO_TOKEN" ]] || fail "PLATFORM_REPO_TOKEN is required"
fi
ok "Values collected"

# ── 4. Create-or-verify repo + remote + push ────────────────────────────────
secret_scan() {
  local dir="$1"
  cd "$dir"
  local leaks
  leaks="$(git ls-files --cached --others --exclude-standard | grep -E '(^|/)(\.env|\.env\..*|terraform\.tfvars)$' || true)"
  cd - >/dev/null
  if [[ -n "$leaks" ]]; then
    warn "Potential secret-bearing files found in $dir:"
    echo "$leaks" | sed 's/^/        /'
    warn "These should be gitignored. Aborting — fix .gitignore first."
    return 1
  fi
  return 0
}

create_and_push() {
  local name="$1" dir="$2"
  local full="${GITHUB_ORG}/${name}"

  log "Repo $full"

  if gh repo view "$full" >/dev/null 2>&1; then
    ok "Repo exists on GitHub"
  else
    if ask "Create $full as $REPO_VISIBILITY?"; then
      gh repo create "$full" "--${REPO_VISIBILITY}" --description "Petclinic — $name" >/dev/null
      ok "Created"
    else
      fail "Aborted"
    fi
  fi

  cd "$dir"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    if ask "Initialise git in $dir?"; then
      git init -b main >/dev/null
      ok "git init done"
    else
      fail "Aborted"
    fi
  fi

  cd - >/dev/null
  secret_scan "$dir" || exit 1

  cd "$dir"
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/${full}.git"
    ok "Added remote 'origin'"
  else
    ok "Remote 'origin' configured"
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    warn "Uncommitted changes present"
    if ask "Stage all + commit?"; then
      git add .
      git commit -m "feat: bootstrap" >/dev/null && ok "Committed" || warn "Nothing to commit"
    fi
  fi

  if git log -1 >/dev/null 2>&1; then
    if ask "Push to $full:main?"; then
      git push -u origin main
      ok "Pushed"
    else
      warn "Skipped push — secrets/vars below will be set, but workflows can't run until you push"
    fi
  else
    warn "No commits yet — make a commit then push manually"
  fi
  cd - >/dev/null
}

create_and_push "$INFRA_REPO_NAME" "$INFRA_DIR"
create_and_push "$APP_REPO_NAME"   "$APP_DIR"

# ── 5. Secrets and Variables ────────────────────────────────────────────────
log "Setting Secrets and Variables"

set_secret()   { gh secret   set "$1" -R "$2" --body "$3" >/dev/null && ok "secret  $1 → $2"; }
set_variable() { gh variable set "$1" -R "$2" --body "$3" >/dev/null && ok "variable $1 → $2"; }

# Infra repo secrets
set_secret AWS_ROLE_ARN   "$INFRA_FULL" "$INFRA_ROLE_ARN"
set_secret OPENAI_API_KEY "$INFRA_FULL" "$OPENAI_API_KEY"

# App repo secrets
set_secret AWS_ROLE_ARN        "$APP_FULL" "$APP_ROLE_ARN"
set_secret PLATFORM_REPO_TOKEN "$APP_FULL" "$PLATFORM_REPO_TOKEN"

# App repo variables
set_variable AWS_ACCOUNT_ID "$APP_FULL" "$AWS_ACCOUNT_ID_VAR"
set_variable AWS_REGION     "$APP_FULL" "$AWS_REGION_VAR"
set_variable PLATFORM_REPO  "$APP_FULL" "$INFRA_FULL"

# ── 6. dev Environment in each repo ─────────────────────────────────────────
log "Creating 'dev' Environment"

gh api -X PUT "/repos/${INFRA_FULL}/environments/dev" --silent
ok "$INFRA_FULL — environment 'dev' present"

gh api -X PUT "/repos/${APP_FULL}/environments/dev" --silent
ok "$APP_FULL — environment 'dev' present"

# ── 7. Infra repo workflow permissions ──────────────────────────────────────
log "Workflow permissions on $INFRA_FULL"

gh api -X PUT "/repos/${INFRA_FULL}/actions/permissions/workflow" \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true \
  --silent
ok "Actions can create + approve PRs (needed by update-image-tags.yml)"

# ── Done ────────────────────────────────────────────────────────────────────
log "Done"

cat <<EOF

Verify:
  gh secret   list -R $INFRA_FULL
  gh secret   list -R $APP_FULL
  gh variable list -R $APP_FULL

Smoke-test the terraform pipeline:
  gh workflow run terraform.yml -R $INFRA_FULL -f action=plan
  gh run watch                  -R $INFRA_FULL

Smoke-test the app pipeline (after a real code change):
  cd $APP_DIR
  git commit --allow-empty -m "chore: trigger first CI run"
  git push

EOF
