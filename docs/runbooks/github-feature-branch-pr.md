# Runbook: Creating a Feature Branch and Pull Request in GitHub

## Purpose
Make changes through a feature branch and pull request while protecting `main`.

## Environment
- Repository: `HeroweDeserve/azure-iac-lab`
- Base branch: `main`
- Example feature branch: `feature/separate-validation-deployment`

## Prerequisites
- GitHub access to the repository
- Permission to create branches and pull requests
- An existing `main` branch and awareness of branch protection rules

## Procedure

### 1. Create a feature branch
1. Open the repository's **Code** tab.
2. Select `main` in the branch selector.
3. Enter a descriptive branch name such as `feature/separate-validation-deployment`.
4. Select **Create branch from main**.
5. Confirm the branch selector displays the new branch.

**Expected result:** A feature branch exists without changing `main`.

**Verified:** `feature/separate-validation-deployment` was confirmed in the repository on November 4, 2026.

### 2. Modify and commit changes
1. Switch to the feature branch.
2. Edit the intended configuration or documentation files.
3. Review the diff.
4. Commit with a descriptive message.
5. Verify the commit appears on the feature branch.

**Verified (November 4, 2026):** The feature branch contains the committed `.github/workflows/deploy.yml` changes. The workflow was read back from GitHub and confirmed to have separate `validate` and `deploy` jobs. Execution was subsequently verified on November 5, 2026.

### 3. Create a pull request
1. Open **Pull requests** > **New pull request**.
2. Choose base `main` and compare with the feature branch.
3. Review the diff and enter a descriptive title and summary.
4. Submit the pull request.

**Verified (November 4, 2026):** PR #4 was created against `main` from `feature/separate-validation-deployment`. The required `Validate Azure Infrastructure / validate` check passed. Initial What-If incorrectly predicted creating the existing `nsg-iac-app`; inspection showed the custom IaC Validation Operator role lacked `Microsoft.Network/networkSecurityGroups/read`. After that permission was added, a rerun passed and showed the NSG as `NoChange`. The existing VNet still shows a `privateEndpointVNetPolicies` property difference. PR #4 was subsequently merged and deployment was verified on November 5, 2026.

### 4. Validate and merge
1. Wait for required GitHub Actions checks to complete.
2. Review any Azure What-If output; investigate unexpected infrastructure changes.
3. Correct failed checks on the feature branch.
4. Merge only after required checks and reviews succeed.
5. Verify the intended changes appear on `main`.

**Verified (November 5, 2026):** PR #4 was merged into `main`. The merged `deploy.yml` workflow ran successfully on attempt #3 (run `41908757879`). The `validate` job completed in 35 seconds. The `deploy` job waited for required `development` environment review, was approved using the normal approval process, and succeeded in 1 minute 16 seconds. The deployment job's Azure login step succeeded (21 seconds), and its infrastructure deployment step succeeded (49 seconds). The GitHub UI truncated individual deployment log details; Azure deployment operation details were not independently inspected.

### 5. Clean up
1. Delete the feature branch when the pull request is merged and the branch is no longer needed.
2. Confirm `main` contains the expected changes.

**Status:** To be verified during the current lab.

## Verified CI/CD pipeline (November 5, 2026)

### Separation of validation and deployment
- `.github/workflows/validate.yml` runs validation on pull requests.
- `.github/workflows/deploy.yml` runs on pushes to `main` and manual `workflow_dispatch` triggers.
- The `validate` job uses GitHub Actions variable `AZURE_VALIDATION_CLIENT_ID` and Azure OIDC authentication, runs Bicep build, Azure deployment group validation, and What-If. It has no GitHub deployment environment.
- The `deploy` job uses `needs: validate`, targets the protected `development` GitHub environment, and authenticates using the separate deployment application through `AZURE_CLIENT_ID`. The environment requires manual reviewer approval before deployment.
- The `development` environment was configured to permit deployments from `main`, with a required reviewer. Use **Review deployments → development → Approve and deploy**. Do not use the administrator **Start all waiting jobs** bypass when testing the protection rule.

### OIDC federation troubleshooting: AADSTS700213
**Observed failure:** After merging PR #4, workflow run `41908757879`, attempts #1 and #2, failed in the validation job's Azure login step with `AADSTS700213: No matching federated identity record found for presented assertion subject`.

**Assertion subject from GitHub:**
```text
repo:HeroweDeserve@346536278/azure-iac-lab@1434715442:ref:refs/heads/main
```

**Root cause:** The validation application's `github-iac-main-validation` federated credential used `:refs:refs/heads/main` (incorrect plural `refs`) instead of `:ref:refs/heads/main` (singular `ref`).

**Resolution:**
1. Open Microsoft Entra ID → App registrations → `Github-Azure-IaC-Validation` → Federated credentials.
2. Edit `github-iac-main-validation`.
3. Set the **Subject identifier** to exactly:
   ```text
   repo:HeroweDeserve@346536278/azure-iac-lab@1434715442:ref:refs/heads/main
   ```
4. Preserve issuer `https://token.actions.githubusercontent.com` and audience `api://AzureADTokenExchange`; save.
5. Rerun the failed GitHub Actions jobs and verify Azure login, validation, What-If, the required environment approval, and deployment.

**Verified:** Attempt #3 on November 5, 2026 succeeded. The What-If showed one modification for `vnet-iac-lab` (removal of `properties.privateEndpointVNetPolicies: "Disabled"`) and no change to `nsg-iac-app`. The GitHub workflow completed successfully after explicit reviewer approval.

## Troubleshooting
- **Direct commit to `main` rejected:** Create a feature branch and submit a pull request.
- **Validation fails:** Inspect the failed GitHub Actions job, correct the issue, and rerun checks.
- **Unexpected Azure What-If changes:** Investigate the proposed resource changes before approving deployment.

## Maintenance
Update this runbook alongside the workflow changes it documents. Distinguish completed, verified lab steps from planned procedures.
