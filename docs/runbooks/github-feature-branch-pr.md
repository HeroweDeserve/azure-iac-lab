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

**Verified (November 4, 2026):** The feature branch contains the committed `.github/workflows/deploy.yml` changes. The workflow was read back from GitHub and confirmed to have separate `validate` and `deploy` jobs. Execution is not yet tested.

### 3. Create a pull request
1. Open **Pull requests** > **New pull request**.
2. Choose base `main` and compare with the feature branch.
3. Review the diff and enter a descriptive title and summary.
4. Submit the pull request.

**Verified (November 4, 2026):** PR #4 was created against `main` from `feature/separate-validation-deployment`. The required `Validate Azure Infrastructure / validate` check passed. Initial What-If incorrectly predicted creating the existing `nsg-iac-app`; inspection showed the custom IaC Validation Operator role lacked `Microsoft.Network/networkSecurityGroups/read`. After that permission was added, a rerun passed and showed the NSG as `NoChange`. The existing VNet still shows a `privateEndpointVNetPolicies` property difference; merge/deployment remain pending review.

### 4. Validate and merge
1. Wait for required GitHub Actions checks to complete.
2. Review any Azure What-If output; investigate unexpected infrastructure changes.
3. Correct failed checks on the feature branch.
4. Merge only after required checks and reviews succeed.
5. Verify the intended changes appear on `main`.

**Status:** To be verified during the current lab.

### 5. Clean up
1. Delete the feature branch when the pull request is merged and the branch is no longer needed.
2. Confirm `main` contains the expected changes.

**Status:** To be verified during the current lab.

## Troubleshooting
- **Direct commit to `main` rejected:** Create a feature branch and submit a pull request.
- **Validation fails:** Inspect the failed GitHub Actions job, correct the issue, and rerun checks.
- **Unexpected Azure What-If changes:** Investigate the proposed resource changes before approving deployment.

## Maintenance
Update this runbook alongside the workflow changes it documents. Distinguish completed, verified lab steps from planned procedures.
