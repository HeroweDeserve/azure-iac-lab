# Azure Infrastructure as Code (IaC) Lab

A hands-on Azure Infrastructure as Code project using **Bicep and GitHub Actions** to automate infrastructure validation and deployment.

## Project Overview

This project demonstrates how Azure infrastructure can be defined, validated, reviewed, and deployed through a GitHub-based CI/CD pipeline.

The lab focuses on infrastructure automation, secure authentication, and deployment safeguards using Azure-native tools.

## Technologies Used

- Microsoft Azure
- Azure Bicep
- GitHub Actions
- Microsoft Entra ID
- OpenID Connect (OIDC)
- Azure RBAC
- Azure CLI

## Azure Infrastructure

The Bicep template provisions:

- An Azure Virtual Network (VNet)
- Application and data subnets
- A Network Security Group (NSG) associated with the application subnet

The infrastructure is defined in `infra/main.bicep`.

## CI/CD Workflows

### Pull Request Validation

The `validate.yml` workflow runs when infrastructure or validation workflow changes are submitted through a pull request targeting `main`.

It performs Bicep compilation and Azure What-If analysis to preview proposed infrastructure changes without deploying them.

### Infrastructure Deployment

The `deploy.yml` workflow supports deployment following changes merged into `main`, as well as manual execution.

The workflow performs:

1. Bicep compilation
2. Azure deployment validation
3. Azure What-If analysis
4. Infrastructure deployment

## Authentication and Security

GitHub Actions authenticates to Azure using OIDC federation with Microsoft Entra ID, eliminating the need to store Azure client secrets in the repository.

Separate identities are used for validation and deployment to support separation of responsibilities.

Additional safeguards include:

- GitHub Actions permission scoping
- A dedicated `development` deployment environment
- Deployment concurrency controls
- Infrastructure validation and What-If before deployment
- GitHub secret scanning

## Project Scope

This repository is a personal hands-on lab for developing and demonstrating Azure Infrastructure as Code and CI/CD practices.

It is intended for learning and technical demonstration rather than production use.
