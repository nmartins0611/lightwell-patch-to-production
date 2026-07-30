# Lightwell + AAP Patch Demo

3-demo series showing the complete CVE lifecycle across Red Hat Trusted Profile Analyzer (RHTPA), Project Lightwell, and Ansible Automation Platform.

## Narrative

A Python CVE is disclosed (no fix yet). AAP identifies exposure instantly via RHTPA, mitigates with compensating controls. Lightwell resolves it upstream. AAP tests in a container, patches VMs under governance, and proves the loop is closed.

## Infrastructure

| Node | Role | Requirements |
|------|------|--------------|
| AAP Controller | Orchestration + EDA | Already deployed |
| Node 1 (RHEL 9) | Target fleet | RHEL 9.3+, subscription |
| Node 2 (RHEL 9) | RHTPA + Builder | RHEL 9.3+, podman, 4GB+ RAM |

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

### 2. Install collections

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

### 3. Setup environment

```bash
# Deploy RHTPA on Node 2
ansible-playbook setup/deploy_rhtpa.yml -i inventory/hosts.yml --ask-vault-pass

# Prepare target with vulnerable package
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
# Demo 1+2: CVE disclosed, no fix yet
export EDA_HOST=your-eda-host
./demo/trigger_cve_disclosure.sh

# (wait for workflow to complete)

# Demo 3: Lightwell resolves it
./demo/trigger_rhsa_available.sh
```

## Demo Flow

### Demo 1: "Vulnerability Arrives" (~15 min)
CVE notification → EDA → query RHTPA → map to inventory → exposure report

### Demo 2: "Compensate While We Wait" (~15 min)
CME controls → SELinux + firewall + detection → verify → posture report

### Demo 3: "Lightwell Fixes It" (~20 min)
RHSA notification → container test → staged VM patch → verify → RHTPA updated → controls removed → audit trail

## Products Highlighted

- **RHTPA** — SBOM storage + instant CVE correlation
- **Project Lightwell** — Upstream vulnerability resolution
- **AAP** — Orchestration, EDA, governance, compliance evidence

## Repository Structure

```
├── inventory/           Ansible inventory and group vars
├── rulebooks/           EDA rulebook (webhook listener)
├── playbooks/           All demo playbooks
├── setup/               Environment provisioning
├── controller/          Controller configuration as code
├── demo/                Trigger scripts and mock data
├── execution-environment/  EE build definition
└── collections/         Required collections manifest
```
