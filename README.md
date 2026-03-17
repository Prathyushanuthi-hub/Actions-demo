# Actions-demo – Azure VM CI/CD Pipeline

This repository contains a GitHub Actions CI/CD pipeline that automatically deploys a Linux Virtual Machine on **Azure** using [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview) infrastructure-as-code.

---

## Repository Structure

```
.github/
  workflows/
    deploy-azure-vm.yml   # CI/CD pipeline definition
infra/
  main.bicep              # Azure Bicep template (VM + networking)
  parameters.json         # Default parameter values
README.md
```

---

## Pipeline Overview

| Job | Trigger | Purpose |
|-----|---------|--------|
| **Validate** | Every push / manual | Validates the Bicep template against Azure without deploying |
| **Deploy** | After validate passes | Creates resource group and deploys the full VM stack |
| **Teardown** | Manual (`dev` env only) | Deletes the resource group to avoid idle costs |

### Deployed Azure Resources

- Virtual Network + Subnet
- Network Security Group (SSH / HTTP / HTTPS rules)
- Static Public IP Address
- Network Interface
- Ubuntu 22.04 LTS Virtual Machine (`Standard_B2s`)

---

## Prerequisites

### 1. Create an Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "gh-actions-demo" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth
```

Copy the JSON output – you'll use it as `AZURE_CREDENTIALS`.

### 2. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `AZURE_CREDENTIALS` | Full JSON output from `az ad sp create-for-rbac` |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `VM_ADMIN_USERNAME` | OS admin username for the VM |
| `VM_ADMIN_PASSWORD` | OS admin password (min 12 chars, complexity required) |

### 3. Create GitHub Environments

Create these environments under **Settings → Environments**:

| Environment | Required reviewers | Notes |
|-------------|-------------------|-------|
| `dev` | optional | Used for automatic pushes |
| `staging` | recommended | Gates staging deployments |
| `production` | required | Gates production deployments |
| `teardown` | required | Prevents accidental deletion |

---

## Usage

### Automatic Deployment

Push to `main` — the pipeline validates and deploys to the `dev` environment automatically.

### Manual Deployment

1. Go to **Actions → Deploy Azure VM**
2. Click **Run workflow**
3. Choose an environment (`dev`, `staging`, or `production`)
4. Click **Run workflow**

### Teardown

1. Run the workflow manually with `environment = dev`
2. The **Teardown** job will prompt for approval (if configured)
3. After approval, the resource group and all resources are deleted

---

## Customisation

| Variable / Parameter | Location | Default |
|----------------------|----------|---------|
| `AZURE_RESOURCE_GROUP` | workflow `env` | `rg-actions-demo` |
| `VM_NAME` | workflow `env` | `vm-actions-demo` |
| `LOCATION` | workflow `env` | `eastus` |
| `vmSize` | `infra/parameters.json` | `Standard_B2s` |
| `osDiskType` | `infra/parameters.json` | `Premium_LRS` |

---

## Security Notes

- Passwords and credentials are stored as **GitHub Secrets** and never logged.
- The service principal is scoped to a single subscription with the minimum `Contributor` role.
- SSH, HTTP, and HTTPS NSG rules can be tightened by updating `infra/main.bicep` to use specific source IP ranges.
