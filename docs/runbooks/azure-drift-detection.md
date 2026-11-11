# Azure Infrastructure Drift Detection Runbook

**Repository:** HeroweDeserve/azure-iac-lab  
**Resource group:** RG-IaC-Lab  
**Bicep source:** `infra/main.bicep`  
**Workflow:** `.github/workflows/drift-detection.yml`  
**Last verified:** November 11, 2026

## Purpose and scope

Detect configuration differences between deployed Azure infrastructure and the desired configuration defined in Bicep. The checks use Azure What-If and are **read-only**: they do not deploy or remediate resources.

Managed lab resources:
- `vnet-iac-lab` (address space `10.10.0.0/16`)
- `subnet-app` (`10.10.1.0/24`), associated with `nsg-iac-app`
- `subnet-data` (`10.10.2.0/24`)
- `nsg-iac-app`

## Prerequisites

- Access to the Azure subscription and `RG-IaC-Lab`
- Azure CLI with Bicep support (Azure Cloud Shell Bash is sufficient)
- GitHub Actions enabled for this repository
- Existing Entra app registration `Github-Azure-IaC-Validation` with least-privilege RBAC sufficient for What-If
- GitHub repository variables `AZURE_VALIDATION_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`
- GitHub OIDC federated credentials supporting pull requests **and** the `main` branch

## Part A — Manually introduce and detect drift

### 1. Introduce a controlled change

1. In Azure portal, open `RG-IaC-Lab` → `vnet-iac-lab` → **Tags**.
2. Add `DriftTest=ManualChange` and save.
3. Verify the tag appears on the virtual network.

This tag is not specified in `infra/main.bicep`.

### 2. Retrieve the desired configuration

In Azure Cloud Shell (Bash):

```bash
curl -fL \
  https://raw.githubusercontent.com/HeroweDeserve/azure-iac-lab/main/infra/main.bicep \
  -o main.bicep
```

**Verify:** `ls -l main.bicep` confirms that the file was downloaded.

### 3. Run What-If

```bash
az deployment group what-if \
  --resource-group RG-IaC-Lab \
  --template-file main.bicep
```

**Observed result:** What-If showed the `DriftTest` tag being removed, demonstrating that it detected the manual difference. It also showed a separate, persistent `privateEndpointVNetPolicies` difference described below.

## Part B — Remediate the controlled change

1. In Azure portal, return to `vnet-iac-lab` → **Tags**.
2. Remove only `DriftTest=ManualChange` and save.
3. Run the same `az deployment group what-if` command again.

**Verified result:** The `DriftTest` tag no longer appeared in What-If. No IaC deployment was executed. This lab used direct portal remediation solely to reverse the deliberately introduced test change; in managed environments, use the approved IaC/change-control process.

## Part C — Automate a manual What-If check in GitHub Actions

### 1. Feature branch and workflow

Created feature branch `feature/automated-drift-detection` and added `.github/workflows/drift-detection.yml`:

```yaml
name: Azure Infrastructure Drift Detection

on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  drift-detection:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Login to Azure
        uses: azure/login@v3
        with:
          client-id: ${{ vars.AZURE_VALIDATION_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      - name: Check infrastructure drift
        run: |
          az deployment group what-if \
            --resource-group RG-IaC-Lab \
            --template-file infra/main.bicep
```

The workflow uses the validation identity, not the deployment identity. It has no `az deployment group create` step.

### 2. Commit, validate, and merge

- Commit: `Add manual Azure infrastructure drift detection workflow`
- Pull request: [#6 — Add Azure infrastructure drift detection workflow](https://github.com/HeroweDeserve/azure-iac-lab/pull/6)
- Required PR validation: **passed** (38 seconds)
- Pull request: **merged** into `main`

### 3. Verify federated authentication

In Azure portal:

**Microsoft Entra ID → App registrations → Github-Azure-IaC-Validation → Certificates & secrets → Federated credentials**

Verified that the application has credentials for both **Pull request** and **Branch: main**. The configured credential uses the newer GitHub OIDC subject format with immutable organization/repository IDs. No new app registration or credential was required.

### 4. Run the workflow manually

1. Open the repository **Actions** tab.
2. Select **Azure Infrastructure Drift Detection**.
3. Choose **Run workflow**, select `main`, and run.
4. Open the job and expand **Check infrastructure drift** to inspect the What-If output.

**Verified run:** [Azure Infrastructure Drift Detection #1](https://github.com/HeroweDeserve/azure-iac-lab/actions/runs/43082208826)  
**Date:** November 11, 2026  
**Trigger:** `workflow_dispatch`  
**Branch:** `main`  
**Status:** Success  
**Duration:** 41 seconds

**What-If summary:** 1 resource to modify, 1 resource with no change. The temporary `DriftTest` tag was absent.

## Known What-If difference — investigation pending

Both manual and GitHub Actions runs reported a difference involving:

```text
~ vnet-iac-lab
  - properties.privateEndpointVNetPolicies: "Disabled"

= nsg-iac-app

Resource changes: 1 to modify, 1 no change.
```

The Bicep source does not explicitly set `privateEndpointVNetPolicies` on the application subnet, while Azure exposes the value `Disabled`. This may be a resource-provider default or What-If false positive; the root cause is **not confirmed**.

**Do not automatically label this as manual drift or deploy changes solely to suppress it.** Investigate the resource provider's behavior before implementing classification or alerts.

## Interpretation and safety

- **What-If does not deploy.** It previews changes only.
- **A successful GitHub Actions job does not mean drift-free.** What-If can report differences and still exit successfully.
- A reported modification is a **potential difference**, not automatically a confirmed unauthorized change.
- Use the least-privileged validation identity; do not substitute the deployment identity to bypass authorization errors.
- Review unexpected differences before any remediation.

## Troubleshooting

### OIDC login fails

Verify the repository variables, `id-token: write`, and the federated credential subject for the actual trigger context. A pull-request credential alone does not authenticate a workflow manually run on `main`.

### What-If fails with authorization errors

Check the validation application's resource-group-scoped RBAC role. Earlier lab troubleshooting required additional read permissions for virtual networks and network security groups.

### What-If shows an unexpected modification

Compare the Bicep template, deployed resource properties, and provider defaults. Check for false positives before deciding on remediation.

### GitHub runtime warning

The initial run succeeded but GitHub warned that `actions/checkout@v4` targets deprecated Node.js 20. Upgrade to a supported checkout version during the next workflow revision.

## Next enhancements — not yet implemented

- [ ] Update `actions/checkout` to a supported version
- [ ] Add scheduled execution against `main`
- [ ] Capture What-If output as a retained report
- [ ] Distinguish known provider-related noise from newly introduced differences
- [ ] Add actionable reporting/alerts without automatically deploying
- [ ] Validate scheduled/reporting behavior and update this runbook with actual results

## Lessons learned

1. Portal changes can introduce configuration differences outside IaC.
2. What-If detects differences but may include provider-related false positives.
3. Reversing a controlled manual change provides a safe test of detection.
4. GitHub Actions can run read-only checks using an existing OIDC validation identity.
5. A green workflow run proves execution succeeded, not that no differences exist.
6. Feature branches, pull requests, and required checks protect automation changes.
