# 09 — Ansible Server Hardening & Configuration Management

**Tier:** Foundational | **Skills:** Ansible, roles, idempotent config, CIS benchmarks, vault

## Problem Statement

Manually configured servers drift from their intended state and fail audits. This project uses Ansible to converge a fleet of Linux servers to a CIS-benchmarked, hardened baseline — idempotently and consistently, whether run once or a hundred times.

## Architecture

```
Control Node (CI/CD runner or admin workstation)
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  ansible-playbook site.yml -i inventories/production/    │
│                │                                         │
│  ┌─────────────▼─────────────────────────────────────┐   │
│  │              Playbook: site.yml                   │   │
│  │                                                   │   │
│  │  hosts: all                                       │   │
│  │    roles:                                         │   │
│  │      - common          ← base packages, timezone  │   │
│  │      - security        ← CIS hardening, SSH, UFW  │   │
│  │      - users           ← service accounts, sudoers│   │
│  │      - monitoring      ← node_exporter, filebeat  │   │
│  │                                                   │   │
│  │  hosts: webservers                                │   │
│  │    roles:                                         │   │
│  │      - nginx                                      │   │
│  │      - certbot                                    │   │
│  │                                                   │   │
│  │  hosts: dbservers                                 │   │
│  │    roles:                                         │   │
│  │      - postgresql                                 │   │
│  └───────────────────────────────────────────────────┘   │
│                                                          │
│  Ansible Vault (encrypted secrets)                       │
│    group_vars/all/vault.yml  ← DB passwords, API keys    │
└──────────────────────────────────────────────────────────┘
           │ SSH (key-based, no password)
           │
     ┌─────┴──────────────────────────────────┐
     ▼               ▼                    ▼
┌─────────┐    ┌─────────┐           ┌─────────┐
│  web-01 │    │  web-02 │   ...     │  db-01  │
│ Ubuntu  │    │ Ubuntu  │           │ Ubuntu  │
│ 22.04   │    │ 22.04   │           │ 22.04   │
└─────────┘    └─────────┘           └─────────┘

Idempotency: running the playbook N times produces
the same result as running it once.
```

## Usage

```bash
# Test connectivity to all hosts
ansible all -i inventories/production/ -m ping

# Dry run (check mode — shows changes without applying)
ansible-playbook site.yml -i inventories/production/ --check --diff

# Apply to all hosts
ansible-playbook site.yml -i inventories/production/ --ask-vault-pass

# Apply only security role to webservers
ansible-playbook site.yml -i inventories/production/ \
  --limit webservers --tags security

# Rotate SSH keys across fleet
ansible-playbook playbooks/rotate-ssh-keys.yml -i inventories/production/

# Encrypt a secret
ansible-vault encrypt_string 'supersecret' --name 'db_password'
```

## Role Structure

```
roles/
├── common/
│   ├── tasks/main.yml      ← Install base packages, set timezone, NTP
│   ├── handlers/main.yml   ← Restart services on config change
│   ├── templates/          ← Jinja2 config file templates
│   └── defaults/main.yml   ← Default variable values
├── security/
│   ├── tasks/
│   │   ├── main.yml
│   │   ├── ssh.yml         ← Disable root login, password auth
│   │   ├── firewall.yml    ← UFW rules
│   │   ├── sysctl.yml      ← Kernel hardening params
│   │   └── cis.yml         ← CIS Level 1 benchmark tasks
│   └── ...
└── users/
    └── tasks/main.yml      ← Create service accounts, manage sudoers
```

## Key Decisions

- **Ansible Vault for secrets** — never store plaintext passwords in inventory or vars
- **`--check --diff` before every production run** — review changes before applying
- **Handlers for service restarts** — services only restart if their config actually changed
- **Tags on every task** — allows surgical targeting without running the full playbook

## Production Considerations

- Use AWX / Ansible Tower for a web UI, RBAC, and audit trails on who ran what when
- Replace static inventory with dynamic inventory (AWS EC2 plugin, Terraform outputs)
- Run in CI on a schedule to detect and remediate configuration drift
- Test roles with Molecule + Docker before applying to production

## Metrics for Success

- CIS benchmark score > 80% on all managed hosts
- Playbook run time < 5 minutes for a 10-host fleet
- Zero manual changes detected by drift monitoring
