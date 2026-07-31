# Lightwell + AAP Patch Demo

3-demo series showing the complete CVE lifecycle across Red Hat Trusted Profile Analyzer (RHTPA), Project Lightwell, and Ansible Automation Platform.

## Narrative

A Python CVE is disclosed (no fix yet). AAP identifies exposure instantly via RHTPA, mitigates with compensating controls. Lightwell resolves it upstream. AAP tests in a container, patches VMs under governance, and proves the loop is closed.

**Demo 4** extends this with the *application dependency* scenario — where the vulnerable library is baked into an application (not installed via RPM on a host). The fix goes through CI/CD rebuild, not `dnf update`.

## Two Remediation Models

| | OS Package (Demo 1-3) | App Dependency (Demo 4) |
|---|---|---|
| **Where the vuln lives** | RPM on the host filesystem | Library inside application artifact |
| **How Lightwell publishes fix** | RHSA → dnf repository | Fixed package → internal PyPI/Maven |
| **How you apply it** | `dnf update` on live system | Rebuild application via CI/CD |
| **Ansible's role** | Orchestrate patch + verify | Trigger rebuild pipeline + deploy + verify |
| **When it's fixed** | After package install | After application redeploy |

## Infrastructure

| Node | Role | Services | Requirements |
|------|------|----------|--------------|
| AAP Controller | Orchestration + EDA | Controller, EDA | Already deployed |
| Node 1, 3, 4 (RHEL 9) | Target fleet | config-service app | RHEL 9.3+, subscription, podman |
| Node 2 (RHEL 9) | RHTPA + Builder + DevOps | RHTPA, Keycloak, Gitea, pypiserver, nginx | RHEL 9.3+, podman, 8GB+ RAM |

### Node 2 port map

| Port | Service | Purpose |
|------|---------|---------|
| 3000 | Gitea | Git forge + CI/CD (Gitea Actions) |
| 8080 | nginx | Report server |
| 8081 | pypiserver | Lightwell PyPI index |
| 8180 | Keycloak | OIDC for RHTPA |
| 8443 | RHTPA | SBOM storage + CVE correlation |

## Quick Start

### 1. Configure inventory

Edit `inventory/hosts.yml` — provide actual hostnames/IPs via vault:

```bash
ansible-vault create inventory/group_vars/vault.yml
```

Required vault variables:
- `vault_ansible_user`
- `vault_ssh_key_path`
- `vault_node1_host`
- `vault_node2_host`
- `vault_controller_host`
- `vault_controller_username`
- `vault_controller_password`
- `vault_registry_username`
- `vault_registry_password`
- `vault_gitea_admin_password` (Demo 4 — Gitea admin)
- `vault_gitea_api_token` (Demo 4 — created by deploy_gitea.yml, save to vault after)

### 2. Install collections

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

### 3. Setup environment

```bash
# Deploy Keycloak + RHTPA on Node 2
ansible-playbook setup/deploy_keycloak.yml -i inventory/hosts.yml --ask-vault-pass
ansible-playbook setup/deploy_rhtpa.yml -i inventory/hosts.yml --ask-vault-pass

# Deploy Gitea + act_runner on Node 2 (Demo 4)
ansible-playbook setup/deploy_gitea.yml -i inventory/hosts.yml --ask-vault-pass

# Deploy Lightwell PyPI index on Node 2 (Demo 4)
ansible-playbook setup/deploy_pypiserver.yml -i inventory/hosts.yml --ask-vault-pass

# Seed Gitea with the config-service demo app (Demo 4)
ansible-playbook setup/seed_gitea.yml -i inventory/hosts.yml --ask-vault-pass

# Prepare targets with vulnerable OS package
ansible-playbook setup/prepare_target.yml -i inventory/hosts.yml --ask-vault-pass

# Install scanning tools on builder
ansible-playbook setup/prepare_builder.yml -i inventory/hosts.yml --ask-vault-pass
```

### 4. Configure Controller

```bash
ansible-playbook controller/configure.yml --ask-vault-pass
```

### 5. Initial SBOM baseline

```bash
ansible-playbook playbooks/sbom_scan_upload.yml -i inventory/hosts.yml --ask-vault-pass
```

### 6. Run the demos

```bash
# Demo 1+2: CVE disclosed, no fix yet (OS package)
export EDA_HOST=your-eda-host
./demo/trigger_cve_disclosure.sh

# (wait for workflow to complete)

# Demo 3: Lightwell resolves it (OS package — dnf update)
./demo/trigger_rhsa_available.sh

# Demo 4: Lightwell resolves app dependency (CI/CD rebuild)
./demo/trigger_app_dependency_fix.sh cicd    # Direct CI/CD path
./demo/trigger_app_dependency_fix.sh gitops  # GitOps PR path
```

## Demo Flow

### Demo 1: "Vulnerability Arrives" (~15 min)
CVE notification → EDA → query RHTPA → map to inventory → exposure report

### Demo 2: "Compensate While We Wait" (~15 min)
CME controls → SELinux + firewall + detection → verify → posture report

### Demo 3: "Lightwell Fixes It — OS Package" (~20 min)
RHSA notification → container test → staged VM patch → verify → RHTPA updated → controls removed → audit trail

**Remediation:** `dnf update` installs the fixed RPM directly on the host.

### Demo 4: "Lightwell Fixes It — App Dependency" (~25 min)

Lightwell publishes the fixed library to an internal package index. The application must be **rebuilt** with the fixed dependency and **redeployed**.

Three workflow variants:

#### 4a: CI/CD Direct
```
Lightwell publishes fix to internal PyPI
  → Controller updates dependency pin in requirements.txt
  → Triggers CI/CD pipeline rebuild
  → Waits for build artifact
  → Deploys rebuilt application to targets
  → Validates service health
```

#### 4b: GitOps PR
```
Lightwell publishes fix to internal PyPI
  → Controller opens PR updating dependency version
  → CI runs automatically (build + test + scan)
  → PR merged (auto or manual)
  → CD deploys the rebuilt application
  → Ansible validates post-deploy health
```

#### 4c: Container Image Rebuild
```
Lightwell publishes fix to internal PyPI
  → Controller triggers container image rebuild
  → Image built with Lightwell-fixed dependency
  → Pushed to Quay registry
  → Rolling update deployed to targets
  → Health check per host
```

**Key distinction:** No `dnf update` happens. The fix is *built into* the application artifact via CI/CD. Ansible orchestrates the pipeline, not the package manager.

## Resetting the Demo

Run between demo sessions to revert everything to pre-demo state:

```bash
# Full reset (all demos)
ansible-playbook setup/reset_demo.yml -i inventory/hosts.yml --ask-vault-pass

# Reset only OS package demos (1-3)
ansible-playbook setup/reset_demo.yml -i inventory/hosts.yml --ask-vault-pass --tags os_package

# Reset only app dependency demo (4)
ansible-playbook setup/reset_demo.yml -i inventory/hosts.yml --ask-vault-pass --tags app_dependency

# Clear reports only
ansible-playbook setup/reset_demo.yml -i inventory/hosts.yml --ask-vault-pass --tags reports
```

The reset playbook:
- Downgrades `python3-cryptography` to the vulnerable version
- Removes all CME compensating controls
- Stops and removes `config-service` containers from targets
- Closes open PRs and deletes `security/*` branches in Gitea
- Reverts `requirements.txt` to `pyyaml==6.0.1`
- Clears all SBOM artifacts, reports, and build images

## Products Highlighted

- **RHTPA** — SBOM storage + instant CVE correlation
- **Project Lightwell** — Upstream vulnerability resolution (OS packages AND application libraries)
- **AAP** — Orchestration, EDA, governance, compliance evidence
- **Gitea** — Git forge with built-in CI/CD (Gitea Actions) for Demo 4

## Repository Structure

```
├── inventory/               Ansible inventory and group vars
├── rulebooks/               EDA rulebook (webhook listener)
├── playbooks/               All demo playbooks
│   ├── sbom_scan_upload.yml           Demo 1 — SBOM baseline
│   ├── correlate_cve.yml              Demo 1 — CVE correlation
│   ├── cme_mitigate.yml               Demo 2 — Compensating controls
│   ├── cme_verify.yml                 Demo 2 — Verify controls
│   ├── container_test.yml             Demo 3 — Container patch test
│   ├── patch_and_verify.yml           Demo 3 — VM patching (dnf)
│   ├── close_loop.yml                 Demo 3 — Audit trail
│   ├── app_dependency_remediate.yml   Demo 4a — CI/CD direct (Gitea)
│   ├── app_gitops_remediate.yml       Demo 4b — GitOps PR (Gitea)
│   └── app_container_rebuild.yml      Demo 4c — Container rebuild
├── setup/                   Environment provisioning
│   ├── deploy_keycloak.yml            Keycloak OIDC
│   ├── deploy_rhtpa.yml               RHTPA server
│   ├── deploy_gitea.yml               Gitea + act_runner
│   ├── deploy_pypiserver.yml          Lightwell PyPI index
│   ├── seed_gitea.yml                 Push config-service to Gitea
│   ├── deploy_report_server.yml       nginx report server
│   ├── prepare_target.yml             Target node prep
│   ├── prepare_builder.yml            Builder node prep
│   └── reset_demo.yml                 Full demo reset
├── controller/              Controller configuration as code
├── demo/                    Trigger scripts and mock data
│   ├── config-service/                Sample app (pushed to Gitea)
│   ├── mock_cve_data.json             OS CVE scenario
│   ├── mock_app_dependency_cve.json   App dependency scenario
│   ├── trigger_cve_disclosure.sh      Demo 1+2 trigger
│   ├── trigger_rhsa_available.sh      Demo 3 trigger
│   └── trigger_app_dependency_fix.sh  Demo 4 trigger (cicd|gitops)
├── execution-environment/   EE build definition
└── collections/             Required collections manifest
```

## Presenter Notes: OS vs App Dependencies

When presenting Demo 4, emphasize this distinction:

> **OS-level vulnerability (Demos 1-3):**
> Lightwell produces a fixed RPM → Red Hat publishes RHSA → you run `dnf update` on the host → done.
> The package manager handles it at deploy-time on the live system.
>
> **Application dependency (Demo 4):**
> Lightwell produces a fixed library (e.g., PyPI package) → you update the version pin in your source code → CI/CD rebuilds the entire application → you deploy the new build.
> The fix goes through the build pipeline. You can't just `pip install` on a running container.
>
> **Why it matters:**
> Most real-world vulnerabilities today are in application dependencies (Log4j, Spring4Shell, etc.), not OS packages. Showing that Lightwell + AAP handles *both* models — host patching AND application rebuild pipelines — demonstrates complete coverage.
