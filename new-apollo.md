# Deploying a New Apollo VM for a Client

## Context

The Australian Apollo Service runs on Nectar Research Cloud. Infrastructure is provisioned with Terraform and configured with Ansible. This guide covers deploying a fresh client-facing Apollo 2 VM end-to-end — from Nectar VM creation through to a live, monitored, backed-up Apollo instance.

**Let's assume the following:**
- Apollo number: **`XXX`** (next available number not already in `client_apollo_numbers` — current highest is `036`)
- Custom hostname: **`<CUSTOM-HOSTNAME>`** (e.g. `griffith-lab` → `griffith-lab.genome.edu.au`)
- VM flavor: **r3.medium** (default — 4 vCPU / 16 GB RAM; use `r3.large` for high-load clients)
- Deployment type: **Fresh** (no DB restore; see note at end for migration/restore path)
- Creation date: **`YYYYMMDD`** (today's date)

---

## Phase 1: Provision the VM with Terraform

**Working directory:** `terraform-nectar/` on the `apollo-backup` deployment server (where Terraform state lives).

**Prerequisites:**
```bash
source apollo-openrc.sh   # export Nectar OpenStack credentials
```

**Step 1a — Edit [`terraform-nectar/apollo-varsanddata.tf`](terraform-nectar/apollo-varsanddata.tf)**

Add one line to `client_apollo_numbers`:
```hcl
"XXX" = "YYYYMMDD",
```

If the client needs more resources than the default, also add an entry to `apollo_flavors`:
```hcl
"XXX" = "r3.large",
```

Available flavors:
- `r3.small` — 2 vCPU / 8 GB RAM (testing only)
- `r3.medium` — 4 vCPU / 16 GB RAM (default)
- `r3.large` — 8 vCPU / 32 GB RAM (high load / large genomes)
- `m3.large` — 8 vCPU / 16 GB RAM (CPU-intensive builds)

**Step 1b — Validate and apply:**
```bash
terraform plan
terraform apply
```
This creates a VM named `tfc_apollo_XXX_YYYYMMDD`.

**Step 1c — Record VM details:**
```bash
openstack server list | grep YYYYMMDD
openstack server show tfc_apollo_XXX_YYYYMMDD
```
Record:
- **Floating IP** (public — used for DNS A record)
- **Internal IP** (private `192.168.0.X` — used by Ansible)

**Step 1d — Commit the Terraform change** (definition only, NOT state files) to GitHub.

---

## Phase 2: DNS

In **Cloudflare** (`Proxy status: DNS only` for both records):
1. **A record**: `apollo-XXX.genome.edu.au` → floating IP from Step 1c
2. **CNAME**: `<CUSTOM-HOSTNAME>.genome.edu.au` → `apollo-XXX.genome.edu.au`

Allow DNS to propagate before proceeding.

---

## Phase 3: Configure with Ansible

**Working directory:** `ansible/playbooks/` on the `apollo-backup` deployment server.

**Prerequisite:** `VAULT_PASSWORD` environment variable must be set.

**Step 3a — Test SSH access:**
```bash
ssh ubuntu@apollo-XXX.genome.edu.au
```
The SSH config on `apollo-backup` handles key selection automatically (via the `apollo-nectar` keypair).

**Step 3b — Add the host to [`ansible/playbooks/hosts`](ansible/playbooks/hosts)**

In the `[clientapollos]` section, add:
```
apollo-XXX.genome.edu.au ansible_host=apollo-XXX
```
The build script will automatically add it to `[apollovms]` at the end of the build.

**Step 3c — Run the main build script:**

This is the single orchestration command. It:
1. Generates `buildapollo.XXX.inventory` from [`buildapollo.template`](ansible/playbooks/buildapollo.template)
2. Runs the canonical playbook sequence:
   - `playbook-set-etc-hosts-ip.yml` — updates `/etc/hosts` on infrastructure servers (backup, NFS, monitor)
   - `playbook-apollo-ubuntu-nfs-server.yml` — creates NFS export for this apollo
   - `playbook-build-nectar-apollo.yml` — full Apollo 2 build (Java 8, Tomcat 9, PostgreSQL in Docker, Nginx, Let's Encrypt TLS)
3. Adds `apollo-XXX` to the `[apollovms]` group in `hosts`

```bash
./build-newapollo.sh XXX <CUSTOM-HOSTNAME> 192.168.0.X
```

Optional flags:
- `-r /dev/vdb2` — if root disk differs from default `/dev/vda2` (verify with `lsblk` on the new VM first)
- `-u 22.04` — if the VM was provisioned with Ubuntu 22.04 rather than 24.04
- `-d` — dry-run (generate inventory and print commands without executing)

**Step 3d — Add to backups:**
```bash
ansible-playbook playbook-apollo-add-to-backup-server.yml \
  --inventory-file buildapollo.XXX.inventory \
  --limit backupservervms
```

**Step 3e — Refresh monitoring:**
```bash
ansible-playbook playbook-monitor-refresh-sources-and-dashboards.yml \
  --limit monitorservervms
```
Adds `apollo-XXX` as a Prometheus scrape target and updates Grafana dashboards.

---

## Phase 4: Verification

- **Web:** `https://apollo-XXX.genome.edu.au` and `https://<CUSTOM-HOSTNAME>.genome.edu.au` respond (200/302)
- **TLS:** Certificate valid (issued by Let's Encrypt via Certbot)
- **Services on the Apollo VM:**
  ```bash
  ssh ubuntu@apollo-XXX.genome.edu.au
  systemctl status nginx tomcat9
  mount | grep nfs
  ```
- **Monitoring:** Grafana at `https://grafana.genome.edu.au` — `apollo-XXX` targets show green
- **Backups:** Confirm next cron window on `apollo-backup` includes `apollo-XXX`

---

## Key Files

| File | Purpose |
|---|---|
| [`terraform-nectar/apollo-varsanddata.tf`](terraform-nectar/apollo-varsanddata.tf) | Add apollo number + optional custom flavor |
| [`ansible/playbooks/build-newapollo.sh`](ansible/playbooks/build-newapollo.sh) | Main orchestration script — runs all playbooks |
| [`ansible/playbooks/buildapollo.template`](ansible/playbooks/buildapollo.template) | Inventory template (auto-consumed by build script) |
| [`ansible/playbooks/hosts`](ansible/playbooks/hosts) | Main inventory — add FQDN to `[clientapollos]` |
| `ansible/playbooks/group_vars/newapollovms/vault` | Apollo secrets (postgres, admin passwords) — pre-configured, no changes needed |

---

## Migration / Restore path

If a PostgreSQL backup for this apollo already exists in `/opt/apollo_files/restore/` on `apollo-backup`, the build script detects it automatically and skips the initial deploy steps. After the build completes:

1. Restore the database:
   ```bash
   ansible-playbook playbook-restore-apollo-db.yml \
     --inventory-file buildapollo.XXX.inventory \
     --limit newapollovms
   ```
2. Move migrated `apollo_data` and `sourcedata` onto `apollo-user-nfs` with correct group ownership.
3. Remove the backup file from `/opt/apollo_files/restore/`.
4. Re-run the build script to complete the final deploy steps:
   ```bash
   ./build-newapollo.sh XXX <CUSTOM-HOSTNAME> 192.168.0.X
   ```
