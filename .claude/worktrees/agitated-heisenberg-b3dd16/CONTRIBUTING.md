# Infra Contributing Guide

## Branch Naming
| Type | Pattern | Example |
|---|---|---|
| Terraform | infra/SPC-XX-description | infra/SPC-10-vpc-module |
| Helm | helm/SPC-XX-description | helm/SPC-40-customers-chart |
| Bug fix | fix/SPC-XX-description | fix/SPC-19-rds-sg-rule |
| Docs | docs/SPC-XX-description | docs/SPC-25-runbook |

## Commit Message Format
SPC-XX: Short description in present tense

## Pull Request Rules
- Every PR targets staging first, never directly to main
- Title format: [SPC-XX] What this PR does
- Terraform changes require 2 approvals
- All checks must pass before merge
- Never commit real credentials or tfstate files

## Definition of Done
- Acceptance criteria from Jira ticket is met
- terraform fmt and terraform validate pass
- No credentials or tfstate files committed
- Docs updated if anything changed
