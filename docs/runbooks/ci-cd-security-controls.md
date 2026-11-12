# Azure IaC CI/CD — Security Controls and Deployment Safeguards

**Repository:** `HeroweDeserve/azure-iac-lab`  
**Scope:** GitHub Actions, Bicep, Azure identity, protected branches and deployment approvals  
**Reviewed:** November 12, 2026  
**Sources:** `.github/workflows/validate.yml` and `.github/workflows/deploy.yml` on `main`.

> This runbook distinguishes controls verified in workflow YAML from GitHub/Azure settings that must be checked separately. It is a reference, not an assertion that every repository or cloud-side protection is currently enabled.

## 1. Why these safeguards matter

The goal is to prevent unreviewed changes from reaching `main`, detect invalid or unexpected infrastructure changes before deployment, limit pipeline credentials, and gate production-like changes with approvals. **Validation and What-If do not deploy resources.** Actual Azure changes occur only at the deployment command.

## 2. Pull-request and branch protections

**Verified in YAML:** `validate.yml` triggers on pull requests targeting `main`:

```yaml
on:
  pull_request:
    branches:
      - main
```

The validation job checks out code, installs Bicep, runs `az bicep build --file infra/main.bicep`, signs into Azure using the validation identity, and runs `az deployment group what-if` against `RG-IaC-Lab`. This is a read-only preview, not an apply operation.

**Configured outside YAML — verify in repository settings:**
- Branch protection or ruleset covers `main`.
- Required status check is the actual **Validate Azure Infrastructure** check/job name currently emitted by GitHub.
- Direct pushes, bypass permissions, review requirements and force-push/deletion restrictions are set as intended.
- Required checks must complete successfully before merge; a stuck or missing check is not a reason to bypass protection.

**Where to verify:** GitHub repository → Settings → Rules → Rulesets, or Settings → Branches, depending on configuration. Check the effective rules, not just the workflow definition.

## 3. Separation of validation and deployment

In `deploy.yml`, the deployment job declares:

```yaml
deploy:
  needs: validate
  runs-on: ubuntu-latest
  environment: development
```

`needs: validate` prevents the deployment job from starting unless validation succeeds. The validation job builds the Bicep template, runs `az deployment group validate`, and generates a What-If preview. The deploy job separately runs `az deployment group create` **only after** validation and applicable environment gates.

**Important limitation:** A successful What-If is a preview, not a cryptographically locked deployment plan. Azure state can change between validation and deployment. Approval of a preview should not be mistaken for approval of an immutable artifact.

## 4. Controlled triggers and serialization

`deploy.yml` is triggered by:
- A push to `main` **only** when `infra/**` or `.github/workflows/deploy.yml` changes.
- An explicit `workflow_dispatch` manual run.

```yaml
concurrency:
  group: azure-deployment-development
  cancel-in-progress: false
```

This concurrency group prevents overlapping runs in the same group from executing simultaneously. It does **not** guarantee FIFO order or prevent every queued-run replacement; verify ordering before deploying critical changes. The manual trigger is not, by itself, an approval mechanism.

## 5. Least-privilege GitHub permissions and Azure OIDC

Both workflows specify:

```yaml
permissions:
  contents: read
  id-token: write
```

`contents: read` limits the workflow's GitHub token repository access; `id-token: write` allows requesting an OIDC identity token. Azure login uses `azure/login@v3` with client, tenant and subscription IDs from GitHub variables, avoiding a long-lived Azure client secret in the workflow.

**Identity separation verified in YAML:**
- Validation uses `vars.AZURE_VALIDATION_CLIENT_ID`.
- Deployment uses `vars.AZURE_CLIENT_ID`.

**Verify separately in Azure:** each identity's federated credential subject/audience, subscription or resource-group RBAC assignments, and whether validation has only the read/validation permissions it needs. Different client IDs do not automatically prove least privilege. OIDC is authentication; Azure RBAC determines authorization.

## 6. Environment approvals

The deployment job references `environment: development`. This allows GitHub environment protection rules, including required reviewers, to gate the job **if those rules are enabled**.

**Verify in GitHub:** Settings → Environments → `development` → required reviewers, deployment branch restrictions, wait timers, and whether self-approval is permitted. Environment naming alone does not require approval. For test/production environments, use their own identities, permissions, and gates rather than assuming development controls carry over.

## 7. Verification checklist

- [ ] Open a feature-branch PR targeting `main`; confirm the required validation check starts.
- [ ] Confirm Bicep build and What-If succeed without deployment.
- [ ] Confirm branch protection blocks merging while a required check is pending or failed.
- [ ] Confirm the deployment job depends on successful validation.
- [ ] Confirm `development` environment reviewer rules are actually enabled and approval is required when expected.
- [ ] Confirm validation and deployment use different Azure client IDs and appropriate Azure RBAC scopes.
- [ ] Confirm `main` push path filters and manual deployment triggers match policy.
- [ ] Confirm no client secrets, passwords or private keys are committed.
- [ ] Confirm successful deployments can be traced to a commit, workflow run, identity and approval.
- [ ] Confirm teardown is documented and resource costs are monitored.

## 8. Troubleshooting and guardrails

| Symptom | First checks | Avoid |
| --- | --- | --- |
| Required PR check remains queued | Actions run status, workflow triggers, runner capacity, new commit/run | Disabling branch protection merely to merge |
| Azure login fails | Federated subject, tenant/subscription IDs, OIDC permission, identity | Adding broad permissions or long-lived credentials without need |
| Validation succeeds but deployment is blocked | `needs`, environment approval status and branch restrictions | Bypassing approvals |
| What-If reports changes | Compare desired Bicep with live Azure configuration | Blindly deploying to suppress differences |
| Deployments overlap or appear out of order | Concurrency group, pending runs, commit SHA | Assuming strict FIFO scheduling |

## 9. Azure DevOps translation (future lab)

| GitHub Actions concept | Azure DevOps counterpart |
| --- | --- |
| Protected `main` + required PR checks | Azure Repos branch policies and build validation |
| GitHub Actions YAML workflow | Azure Pipelines YAML pipeline |
| GitHub environment required reviewers | Azure DevOps environment approvals/checks |
| GitHub OIDC to Azure | Azure Resource Manager service connection using workload identity federation |
| `needs: validate` | Stage/job dependencies with conditions |
| GitHub workflow permissions | Azure DevOps pipeline permissions and service connection authorization |

The future Terraform/Ansible lab should preserve these principles: PR validation, review before apply, least-privilege identities, approval before deployment, post-deployment verification, and a safe destroy path.

## 10. Key reference files

- [Pull-request validation workflow](../../.github/workflows/validate.yml)
- [Deployment workflow](../../.github/workflows/deploy.yml)
- [Drift detection runbook](azure-drift-detection.md)
