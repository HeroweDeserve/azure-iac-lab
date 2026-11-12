# Azure Infrastructure Drift Detection Runbook

**Repository:** HeroweDeserve/azure-iac-lab  
**Resource group:** RG-IaC-Lab  
**Bicep source:** `infra/main.bicep`  
**Workflow:** `.github/workflows/drift-detection.yml`  
**Last verified:** November 11, 2026.

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

- [x] Update `actions/checkout` to v6 in feature branch (pending PR validation and merge)
- [x] Add weekly schedule in feature branch (pending PR validation and merge)
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

## Part D — Weekly scheduling enhancement (pending verification)

**Feature branch:** `feature/drift-detection-enhancements`  
**Workflow commit:** `30194ec`

Added a `schedule` trigger while retaining `workflow_dispatch` (subsequently adjusted to the requested 9:15 AM Central):

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: '15 9 * * 1'
      timezone: 'America/Chicago'
```

The cron expression runs every Monday at **9:15 AM America/Chicago**, automatically accounting for CST/CDT. GitHub schedules may be delayed. The checkout action was changed from `actions/checkout@v4` to `actions/checkout@v6`.

**Status:** Changes committed to feature branch, **not yet merged**. GitHub's scheduled workflow will use the default branch (`main`) only after merging. A manual workflow run and subsequent scheduled execution still need verification; no scheduled run has yet been observed.

## Part E — Verification after merge

On November 11, 2026, the user verified the weekly schedule and `actions/checkout@v6` on `main`, and manually ran the updated workflow successfully. The scheduled trigger itself remains unverified until a Monday scheduled run occurs. The successful manual execution confirms the updated workflow runs, not that What-If reported zero differences.

## Next phase — Structured reporting and annotations

Work will proceed in branch `feature/drift-reporting-annotations`. Planned changes are not yet implemented or tested. The goal is to retain What-If results and display useful GitHub Actions annotations while distinguishing execution failures, potential differences, and known provider-related noise. No automatic remediation will be introduced.

## Part F — Structured reporting verification (November 11, 2026)

After merging PR #8, manually triggered **Azure Infrastructure Drift Detection #3** on `main`:

- [Workflow run](https://github.com/HeroweDeserve/azure-iac-lab/actions/runs/43087297261)
- **Result:** Success, 39 seconds
- **What-If step:** Success
- **Job summary:** Generated and displayed structured What-If JSON
- **Artifact:** One downloadable `azure-what-if-report` archive, containing `what-if.txt`; contents verified by the user
- **Observed resources:** `nsg-iac-app` — `NoChange`; `vnet-iac-lab` — `Modify` with a `Delete` delta for `properties.privateEndpointVNetPolicies` (before: `Disabled`, after: `null`)

The existing VNet property difference remains unexplained. It must not be automatically labeled confirmed drift. The reporting enhancements are verified. Annotation behavior was subsequently implemented and verified in Part G.

## Part G — GitHub Actions annotation verification (November 11, 2026)

- **Change:** PR #9 added an `Annotate potential infrastructure changes` step that parses structured What-If JSON and emits GitHub Actions notices/warnings. The step runs only after a successful What-If check.
- **Required PR validation:** Passed; PR #9 merged to `main`.
- **Manual verification:** [Azure Infrastructure Drift Detection #4](https://github.com/HeroweDeserve/azure-iac-lab/actions/runs/43088656780) on `main`, triggered manually, **Success** (42 seconds).
- **Observed annotations:** 3 warnings and 1 notice. The custom warnings were **Azure What-If** (`1 resource(s) with potential changes; review the saved What-If report`) and **Potential infrastructure difference** (resource path shown in the annotation). The third warning concerned Node.js 20 deprecation in a GitHub Actions dependency; the notice concerned GitHub's Ubuntu 26 runner migration. These runtime notices are separate from Azure configuration differences.
- **Interpretation:** The workflow completed successfully even with a reported potential resource change, as designed. The existing `vnet-iac-lab` / `privateEndpointVNetPolicies` difference is still **not confirmed drift**. The screenshot verified the annotation titles and counts; the full resource-path annotation was truncated in the screenshot.
- **Outstanding:** Observe the first actual Monday scheduled run; investigate the persistent provider-property difference and the Node.js deprecation warning independently. No automatic remediation is enabled.

## Part H — Resolve persistent VNet What-If difference (November 11, 2026)

**Investigation:** Azure portal showed subnet-level `privateEndpointNetworkPolicies = Disabled` on `subnet-app`. Azure CLI `az network vnet show` showed the same value for both subnets, and VNet-level `privateEndpointVNetPolicies = Disabled`. A direct ARM REST GET with API version `2024-05-01` independently returned `"Disabled"` for the VNet-level property. The original `infra/main.bicep` omitted that VNet property.

**Controlled template-only fix:** In branch `feature/explicit-vnet-private-endpoint-policy`, added `privateEndpointVNetPolicies: 'Disabled'` to the VNet `properties` block. Required PR validation passed. A read-only Azure Cloud Shell What-If against the feature-branch Bicep reported **2 no change** (VNet and NSG). No Azure deployment was performed. [PR #11](https://github.com/HeroweDeserve/azure-iac-lab/pull/11) was merged into `main`.

**Automated verification:** [Azure Infrastructure Drift Detection #5](https://github.com/HeroweDeserve/azure-iac-lab/actions/runs/43092598245) ran manually on `main` on November 11, 2026 and **succeeded** (38 seconds). The What-If JSON listed both `nsg-iac-app` and `vnet-iac-lab` as `NoChange`. The annotations showed **Azure What-If: No resource changes reported**, with no custom potential-difference warning. One unrelated Node.js 20 deprecation warning and one Ubuntu 26 migration notice remained.

**Conclusion:** Explicitly specifying the deployed VNet policy value resolved this recurring What-If comparison difference without modifying Azure resources. This establishes a template-comparison cause for this instance; it does not prove that every omitted/default property difference is harmless. The first actual scheduled Monday run is still pending verification.

## Part I — Node.js 20 deprecation warning resolved (November 11, 2026)

**Cause:** The expanded warning in [Azure Infrastructure Drift Detection #5](https://github.com/HeroweDeserve/azure-iac-lab/actions/runs/43092598245) explicitly identified `actions/upload-artifact@v4` as targeting deprecated Node.js 20 and being forced to run on Node.js 24. Other workflow actions were not identified by that warning.

**Controlled workflow fix:** In branch `feature/upgrade-upload-artifact-node24`, changed only the artifact upload step from `actions/upload-artifact@v4` to `actions/upload-artifact@v6` in `.github/workflows/drift-detection.yml`. Artifact name `azure-what-if-report`, path `reports/what-if.txt`, and 14-day retention were preserved. Required PR validation passed; [PR #13](https://github.com/HeroweDeserve/azure-iac-lab/pull/13) was merged to `main`. No Azure deployment was performed.

**Automated verification:** Manually triggered [Azure Infrastructure Drift Detection #6](https://github.com/HeroweDeserve/azure-iac-lab/actions/runs/43094559686) on `main` on November 11, 2026. **Result: Success (56 seconds)**; **0 warnings, 2 notices, 1 artifact**. Structured What-If output showed `nsg-iac-app` and `vnet-iac-lab` both `NoChange`. The Node.js 20 deprecation warning no longer appeared. The notices were the expected `Azure What-If: No resource changes reported` and GitHub's Ubuntu 26 runner migration announcement.

**Conclusion:** Upgrading the artifact upload action to v6 eliminated the observed Node.js 20 warning while retaining successful report generation and artifact upload. The Ubuntu runner migration notice is informational. The first actual scheduled Monday run remains unverified.
