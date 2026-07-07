# Ansible Playbooks

This directory contains the **Ansible playbooks**, **inventory files** and **Apollo build scripts** (wrappers that simplify running the playbooks) for configuring and maintaining all the hosts that make up the Australian Apollo Service.

- Group variables live in `group_vars/`.
- Ansible Vaults live under `group_vars/<group>/vault` and contain passwords and credentials required during builds.
- Playbooks under `one-offs/` are rarely required and typically execute one or two tasks.

There are specific playbooks for building each of the host types that make up the Australian Apollo Service:
- **Core infrastructure servers**
    - Backup and deployment server
    - NFS server
    - Monitoring server
- **Web servers**
    - Apollo Portal
    - JBrowse portal
- **Apollo instances**
- **Sandpit VMs** for development and testing

Other non-build related playbooks, such as for running system updates, are documented below.


## Prerequisites

- **SSH access** to target hosts is required using the keypair defined at VM creation time.
- **Ansible installed and configured**: `./ansible.cfg` (defines inventory location, roles path, and vault password script).
- **Inventory**: `./hosts` (FQDNs and internal shortnames only; no public IPs).
- **Secrets**: do not commit. Use environment variables and/or Ansible Vault.


## Configuration

### SSH Configuration

For convenience (and because build scripts do not pass an explicit private key), the Ansible control account (typically `ubuntu` on the deployment server) should have an SSH config like below. This is applied by `playbook-setup-nectar-deployment-server.yml`.

```
# disable ssh agent-loaded identities by default (fixes multi-key auth failures)
Host *
     IdentitiesOnly yes

Host apollo-*
     User ubuntu
     IdentityFile /home/ubuntu/.ssh/apollo-nectar
     IdentitiesOnly yes
     StrictHostKeyChecking no

Host *.genome.edu.au
     User ubuntu
     IdentityFile /home/ubuntu/.ssh/apollo-nectar
     IdentitiesOnly yes
     StrictHostKeyChecking no
```

If running Ansible from a different account, replicate this SSH configuration.


### Ansible Configuration
Ansible is configured with the `ansible.cfg` located in this directory. This currently defines the following locations:
- `inventory`: `./hosts`. The ansible inventory file is located in this directory.
- `roles_path`: `../roles:~/.ansible/roles`. Roles will be searched for in the sibling directory (`ansible/roles`) while the playbooks and ansible configuration are defined in (`ansible/playbooks`).
- `vault_password_file`: `./.vault_pass`. Ansible vault operations run this script which looks for the shell environment variable `VAULT_PASSWORD` to pass to the vault as the requested password. If it is not defined but `VAULT_PASS_ALLOW_NULL` is defined then a dummy password is passed to ansible for those ansible operations that don't require access to the vault.


## Ansible Inventory
The main **ansible inventory**, located in `./hosts` defines managed hosts, host groups and variables. This is primarily used when running playbooks that apply updates across many hosts, or for targetting groups, such as client apollos.

Note: **Host builds do not use `./hosts`**, instead they use **host-based inventory files** (see below).

### Host-based Inventory files
These inventory files are passed to multiple playbooks and are used to configure variables for host builds and for integrating the specified host with other infrastructure servers.

An example is using `changeipvms` with `playbook-set-etc-hosts-ip.yml` to populate `/etc/hosts` on the infrastructure servers:
```
ansible-playbook playbook-set-etc-hosts-ip.yml --inventory-file buildapollo3sandpit.inventory --limit changeipvms
```

The general format of host inventory files is:
```
[GROUPNAME]
HOST.genome.edu.au

[GROUPNAME:vars]
LOCALVAR=SOME_VALUE

# populate host and local IP in these servers /etc/hosts
[changeipvms]
apollo-backup.genome.edu.au ansible_user=ubuntu admin_group=sudo
apollo-user-nfs.genome.edu.au ansible_user=ubuntu admin_group=sudo
apollo-monitor.genome.edu.au ansible_user=ubuntu admin_group=sudo

[changeipvms:vars]
hostname_for_ip=HOST
private_ip=192.168.0.XY

# configure NFS exports for apollo/jbrowse hosts
[nfsservervms]
apollo-user-nfs.genome.edu.au

[nfsservervms:vars]
# use internal hostname
nfs_client=HOST

# add to apollo-specific backups - apollo hosts only
[backupservervms]
apollo-backup.genome.edu.au

[backupservervms:vars]
apollo_instance_number=XYZ
```

The following are the host inventory files and the host associated with them
- `buildapollo3sandpit.inventory`: apollo3-sandpit inventory
- `builddeploy.inventory`: apollo-backup/apollo-deploy inventory
- `buildjbrowse.inventory`: jbrowse-portal (apollo-user-jbrowse) inventory
- `buildmonitor.inventory`: apollo-monitor inventory
- `buildmtsandpit.inventory`: mt-sandpit (jbrowse2 sandpit) inventory
- `buildnewportalvms.inventory`: inventory used by playbook-deploy-portal.yml to deploy django website on apollo-portal
- `buildnfs.inventory`: apollo-user-nfs inventory
- `buildsandpit.inventory`: apollo-sandpit (apollo2 build VM) inventory
- `buildubuntutest.inventory`: test VM inventory
- `buildwebservervms.inventory`: inventory used for web server builds (apollo-portal)

There is also a `buildapollo.template` which is used to create apollo inventories by the Apollo build scripts.


## Group Vars and Vaults
For each of the groups defined in the inventory files there is a corresponding group directory. At a minimum these contain a `vars` file defining some variables that the playbooks will need, while for host groups that need access to secrets, there will also be a `vault` file.

As an example, `group_vars/apollovms/vars` contains:
```
---
ansible_user: ubuntu
admin_group: sudo
allowed_groups: "ubuntu apollo_admin backup_user"
target_environment: prod
```

- `apollovms`: default vars for  playbooks run on apollo hosts.
- `changeipvms`: defines production environment by default for populating `/etc/hosts`.
- `jbrowseportalvms`: jbrowse-portal (apollo-user-jbrowse) settings.
- `monitorservervms`: settings for adding hosts to Grafana/Prometheus on apollo-monitor.
- `newapollovms`: variables needed for building new apollo VMs. Includes a vault.
- `newmonitorservervms`: variables for building new apollo-monitor. Includes a vault.
- `newportalvms`: variables for configuring django web portal on apollo-portal. Includes a vault.
- `newservervms`: default vars for building infrastructure servers.
- `newubuntutestvms`: default vars for building a new test VM.
- `newwebservervms`: default vars for building a new web server,
- `nfsservervms`: default vars for playbooks run on NFS server (apollo-user-nfs).
- `otherubuntuvms`: default vars for other ubuntu VMs.

### Vaults
- `group_vars/newportalvms/vault`: stores secrets needed to build django apollo-portal website.
- `group_vars/newapollovms/vault`: stores secrets needed to build an apollo instance.
- `group_vars/newmonitorservervms/vault`: stores secrets needed to build Grafana monitor.


## Playbooks

For each host build, several playbooks will need to be run. Infrastructure servers, web servers and sandpits utilise a base configuration playbook on top of which a host specific setup playbook is applied. Apollo instances are configured with a single playbook. In addition there a other playbooks that are used to integrate the new host with existing infrastructure (monitoring, backups, NFS exports, etc). Host build playbooks utilise host-specific inventories to define variables for the build host and other infrastructure hosts.

### General Build Playbooks

- **`playbook-base-nectar-server-ubuntu.yml`**,
    Baseline for all infrastructure, web server and sandpit hosts. This performs OS hardening, adding admin users, and common packages. Run this before any role-specific `playbook-setup-nectar-*` playbook.

    **Inventory:** use the **host-based inventory** that matches the target (see below), e.g. `buildnfs.inventory`, `buildnewportalvms.inventory`, `buildjbrowse.inventory`, etc.

### Host Specific Build Playbooks
Host-specific playbooks are used to configure a host with its intended functionality. These are elaborated in the sub sections below.

#### Core infrastructure servers

- **`playbook-set-etc-hosts-ip.yml`**,
    Update `/etc/hosts` on infrastructure servers with internal IP/name mappings.

    **Inventory:** use the **host-based inventory** that matches the target (see below), e.g. `buildapollo3sandpit.inventory`, `buildjbrowse.inventory`, etc. This will be applied to the hosts in the inventory defined in group `changeipvms` using the variables defined in `changeipvms:vars` (`hostname_for_ip` and `private_ip`).

- **Backup and deployment server**
  - Apply base server config to host with **`playbook-base-nectar-server-ubuntu.yml`**,
  - Setup host with **`playbook-setup-nectar-deployment-server.yml`**.
    Install and configure the deployment/backup host with github repo, ansible and terraform deployments, and backup tooling.

    **Inventory:** `builddeploy.inventory`

  - Update backup targets with **`playbook-apollo-add-to-backup-server.yml`**.
    Register Apollo instances on the backup server.

    **Inventory:** use the **host-based inventory** that matches the target (this will be a generated apollo inventory like `buildapollo.999.inventory`). This will be applied to the hosts in the inventory defined in group `backupservervms` using the variables defined in `backupservervms:vars` (`apollo_instance_number`).

- **NFS server**
  - Apply base server config to host with **`playbook-base-nectar-server-ubuntu.yml`**,
  - Setup host with **`playbook-setup-nectar-nfs-server.yml`**.
    Install and configure NFSv4 and user quotas.

    **Inventory:** `buildnfs.inventory`

  - Refresh exports with **`playbook-apollo-ubuntu-nfs-server.yml`**.
    Update client Apollo mounts served from the NFS server.

    **Inventory:** use the **host-based inventory** that matches the target (this will usually be a generated apollo inventory like `buildapollo.999.inventory`). This will be applied to the hosts in the inventory defined in group `nfsservervms` using the variables defined in `nfsservervms:vars` (`apollo_instance_number`, `nfs_apollo_user_gid`)

- **Monitoring server**
  - Apply base server config to host with **`playbook-base-nectar-server-ubuntu.yml`**,
  - Setup host with **`playbook-monitor-install-grafana-server.yml`**.
    Install and configure Nginx TLS/proxy, Grafana with Prometheus and Alertmanager

    **Inventory:** `buildmonitor.inventory`

  - Refresh monitoring targets with **`playbook-monitor-refresh-sources-and-dashboards.yml`**.
    Refresh scrape targets in the apollo network (from ansible `hosts` inventory) and update Grafana dashboards to inventory.

    **Inventory:** `hosts` (default inventory). This will be applied to the hosts in the inventory defined in group `monitorservervms` using the hosts defined in groups `infrastructure` and hosts that belong to groups under `apollovms:children`.

#### Web servers
- **Apollo Portal**
  - Apply base web server config to host with **`playbook-base-nectar-server-ubuntu.yml`**,
  - **`playbook-setup-nectar-portal.yml`**.
    Deploy Django portal application, PostgreSQL init/migrate, Nginx TLS/proxy.

    **Inventory:** `buildnewportalvms.inventory`

- **JBrowse portal**
  - Apply base web server config to host with **`playbook-base-nectar-server-ubuntu.yml`**,
  - **`playbook-setup-nectar-jbrowse.yml`**.
    Install JBrowse software dependencies (includes Nodejs install and config) and configure admin users. Note this doesn't build the JBrowse clients - see the following two playbooks.

    **Inventory:** `buildjbrowse.inventory`

  - Refresh Jbrowse clients with **`playbook-jbrowse-discover-exports-and-mount.yml`**.
    Discover NFS exports for JBrowse instances, mount datasets and JBrowse config for clients.

    **Inventory:** `buildjbrowse.inventory`

  - **`playbook-jbrowse-build-instances-on-portal.yml`**.
    Build/refresh JBrowse1 instances hosted on the portal.

    **Inventory:** `buildjbrowse.inventory`

#### Sandpit hosts for development and testing
- **apollo sandpit (apollo builds)**
  - **`playbook-setup-nectar-sandpit.yml`**.
    Configure host with *all* required components for building, testing and hosting apollo2 software stack.

    **Inventory:** `buildsandpit.inventory`

- **apollo3 sandpit**
  - **`playbook-setup-nectar-apollo3sandpit.yml`**.
    Configure host with *all* required components for building, testing and hosting apollo3 in Docker. This installs Nginx, Docker Compose stack (Apollo3/JBrowse2/MongoDB), Node.js and Yarn 1.x with NVM for apollo3 CLI tools.

    **Inventory:** `buildapollo3sandpit.inventory`

- **mtsandpit (Jbrowse2 sandpit)**
  - **`playbook-setup-nectar-mtsandpit.yml`**.
    Configure host with *all* components required for building and hosting the JBrowse2 web application.

    **Inventory:** `buildmtsandpit.inventory`

#### Apollo instances

- See **Apollo playbooks and build scripts** (wrappers) below. These **generate a per-build inventory** from `buildapollo.template`.

  **Inventory:** generated by `build-newapollo-inventory.sh` (not `./hosts`).


## Apollo Playbooks and build scripts

### Playbooks
- **`playbook-build-nectar-apollo.yml`**
    Build a new Apollo2 instance end-to-end on a fresh VM.

    **Inventory:** generated by `build-newapollo-inventory.sh` in the form `buildapollo.XXX.inventory`, where `XXX` is a number from 001 - 999.

- **`playbook-restore-apollo-db.yml`**
    Restore Apollo2 PostgreSQL database from backup when rebuilding on a fresh VM.

    **Inventory:** generated by `build-newapollo-inventory.sh` in the form `buildapollo.XXX.inventory`, where `XXX` is a number from 001 - 999.

- **`playbook-setup-nectar-jbrowse2-on-apollo.yml`**
    Installs JBrowse2 on an existing Apollo2 instance, including the web application under `/jbrowse2/` and the JBrowse2 CLI in the home directory of `jbrowse_build_user` (derived from `apollo_subdomain_name`). This playbook is intended for cases where JBrowse2 is deployed alongside an existing Apollo2 service.

    **Inventory:** generated by `build-newapollo-inventory.sh` in the form `buildapollo.XXX.inventory`, where `XXX` is a number from 001 - 999.


### Scripts

- **Main script**
  - **`build-newapollo.sh`**. Orchestrates a new Apollo build including generating host inventory, checking if this is a restore of an old apollo (additionally run `playbook-restore-apollo-db.yml`), running apollo build playbook (`playbook-build-nectar-apollo.yml`), and adding apollo to main ansible inventory (`hosts`).

- **Supporting scripts**
  - **`build-newapollo-inventory.sh`**. Generate per-build host inventory from template.
  - **`build-newapollo-runplaybooks.sh`**. Run the canonical playbook sequence for building an Apollo2 instance.
  - **`build-newapollo-groupadd-apollovms.sh`**. Add the new host to the `apollovms` group in the ansible inventory.

### Inventory templates
- **`buildapollo.template`**. Template consumed by the Apollo build scripts.


### Apollo tarball variants (custom JBrowse1 plugins baked in)

Custom JBrowse1 plugins (e.g. bhofmei's [MethylationPlugin](https://github.com/bhofmei/jbplugin-methylation)) must be **baked into the WAR at build time** — the plugin JS is discovered via webpack-compiled `dist/*.bundle.js` bundles inside the WAR, so dropping plugin files into the deployed webapp at runtime does not work. To support this, the deployment server keeps **one or more pre-built Apollo tarball variants** alongside the stock tarball, and the `apollo_copy_war_src_path` used by [apollo-copy-tarred-build](../roles/apollo-copy-tarred-build/) is a symlink that selects which variant is currently active.

On `apollo-deploy`, the tarballs live in `/opt/apollo_files/` with descriptive filenames, and `/opt/apollo_files/deploy/Apollo-<version>.tar.gz` is a symlink:

```
/opt/apollo_files/
├── Apollo-2.8.1-Ubuntu-deploy-YYYYMMDD.tar.gz            # stock build
├── Apollo-2.8.1+methylation-Ubuntu-deploy-YYYYMMDD.tar.gz  # + bhofmei/jbplugin-methylation
├── Apollo-2.8.1-blast+WH-Ubuntu-deploy-YYYYMMDD.tar.gz     # + BLAST + WebApollo extras
└── deploy/
    └── Apollo-2.8.1.tar.gz -> ../Apollo-<active-variant>.tar.gz
```

**To switch which variant Apollo builds/redeploys use**, swap the symlink and get the new tarball onto the target host, then redeploy.

> **Important gotcha:** [apollo-copy-tarred-build](../roles/apollo-copy-tarred-build/) (the role that ships the tarball from the deployment server onto the target and extracts it into `/opt/`) has **no tag**. That means `--tags deploy` on `playbook-build-nectar-apollo.yml` **skips** the tarball copy and only re-runs the WAR-copy → Tomcat restart chain. So a symlink swap on its own is invisible to `--tags deploy`. You have two working recipes:

**Recipe A — full playbook (simplest, ~15 min):**

```
ssh apollo-deploy 'sudo ln -sfn ../Apollo-2.8.1+methylation-Ubuntu-deploy-YYYYMMDD.tar.gz \
                                 /opt/apollo_files/deploy/Apollo-2.8.1.tar.gz'

ansible-playbook playbook-build-nectar-apollo.yml \
  --inventory-file hosts \
  --limit apollo-XXX.genome.edu.au \
  --extra-vars "apollo_instance_number=XX apollo_subdomain_name=<subdomain>"
```

No `--tags deploy` — the whole playbook runs. Nearly all pre-deploy steps are idempotent no-ops (users, packages, certs, etc.), so on an already-provisioned Apollo the effective work is: `apollo-copy-tarred-build` (copies new tarball + extracts) → the deploy chain (war copy → Tomcat restart → nginx restart). The bulk of runtime is Tomcat re-extracting the WAR (~30s).

**Recipe B — manual SCP + `--tags deploy` (faster, ~5 min, matches production practice):**

```
# 1. Update the deploy symlink (source of truth) even if you're bypassing it below
ssh apollo-deploy 'sudo ln -sfn ../Apollo-2.8.1+methylation-Ubuntu-deploy-YYYYMMDD.tar.gz \
                                 /opt/apollo_files/deploy/Apollo-2.8.1.tar.gz'

# 2. Ship the tarball onto the target and extract into /opt/ manually
ssh apollo-deploy 'scp /opt/apollo_files/Apollo-2.8.1+methylation-Ubuntu-deploy-YYYYMMDD.tar.gz \
                       ubuntu@apollo-XXX.genome.edu.au:/tmp/Apollo-2.8.1.tar.gz'
ssh ubuntu@apollo-XXX.genome.edu.au 'sudo mv /tmp/Apollo-2.8.1.tar.gz /opt/Apollo-2.8.1.tar.gz
                                     sudo rm -rf /opt/Apollo-2.8.1
                                     cd /opt && sudo tar -xzf Apollo-2.8.1.tar.gz
                                     sudo chown -R root:root /opt/Apollo-2.8.1'

# 3. Now `--tags deploy` sees a new WAR at /opt/Apollo-2.8.1/target/apollo-2.8.1.war
#    and does the war copy + Tomcat restart + nginx restart
ansible-playbook playbook-build-nectar-apollo.yml \
  --inventory-file hosts \
  --limit apollo-XXX.genome.edu.au \
  --tags deploy \
  --extra-vars "apollo_instance_number=XX apollo_subdomain_name=<subdomain>"
```

Verify (either recipe):

```
ssh ubuntu@apollo-XXX.genome.edu.au \
  'sudo grep -c MethylationPlugin /var/lib/tomcat9/webapps/apollo/jbrowse/dist/main.bundle.js'
# > 0 means the plugin is in the extracted webapp bundles
```

Rollback is symmetric: `ln -sfn` back at the stock tarball, then follow Recipe A (or Recipe B if you'd rather manually SCP).

**Which Apollo VMs get which variant** is a matter of the symlink state at deploy time. Switching the symlink affects **all** subsequent Apollo builds/redeploys until it is switched back. Client-specific plugin needs should either be scheduled with this in mind, or the target host should override `apollo_version` (in a per-host var) so it resolves to a different tarball filename — see `apollo_copy_war_name` in [apollo-copy-tarred-build/defaults/main.yml](../roles/apollo-copy-tarred-build/defaults/main.yml).

**Per-organism activation** is still required. The baked-in plugin is dormant unless the organism's `trackList.json` (on the NFS server under `apollo_data/<Organism>/`) declares it:

```json
"plugins": {
  "MethylationPlugin": {
    "extendedModifications": true
  }
},
```

Omit `location` — JBrowse defaults to `plugins/<Name>/`. Any keys inside the object are passed to the plugin as config; see the plugin's own docs (for MethylationPlugin: `extendedModifications`, `isAnimal`, etc.). This is per-organism data configuration, not infrastructure. No Tomcat restart needed after editing; hard-refresh the browser to bypass `trackList.json` caching.

**Building a new variant tarball** is a manual, one-off procedure (typically done on the sandpit build VM, but can also be done in a scratch dir on `apollo-deploy` if the sandpit is unavailable). At a high level:

1. Extract the current stock tarball to a scratch dir.
2. Unzip `Apollo-<ver>/target/apollo-<ver>.war` (WARs are ZIPs).
3. Under the unzipped `jbrowse/` tree: `git clone <plugin repo> plugins/<PluginID>`, then register it in `jbrowse.conf` (either `[ plugins.<PluginID> ]\nlocation = plugins/<PluginID>` under `[GENERAL]`, or the append form `plugins += <PluginID>`).
4. Bring up node 12 + yarn 1.x via NVM (matches the sandpit toolchain — see [apollo-build-dependencies](../roles/apollo-build-dependencies/tasks/main.yml)), then run `chmod +x setup.sh && ./setup.sh` inside the unzipped `jbrowse/` dir. Sample-data formatting failures in setup.sh output are irrelevant; the webpack step is what matters.
5. Confirm `grep -c MethylationPlugin dist/main.bundle.js` > 0.
6. Strip `node_modules/`, `setup.log`, and any `.git` dirs before re-zipping (the original WAR does not ship node_modules — ~700MB of bloat).
7. Re-zip into `apollo-<ver>.war`, put back in `Apollo-<ver>/target/`, then `tar -czf` the whole `Apollo-<ver>/` dir as a new variant tarball named `Apollo-<ver>+<mods>-Ubuntu-deploy-<date>.tar.gz`.
8. Land the new variant in `/opt/apollo_files/`, then update the symlink as above when ready to use it.

Keep the stock tarball indefinitely so rollback is always possible.


## System Maintenance Playbooks
- **`playbook-system-updates-ubuntu.yml`**. Apply OS updates across selected hosts/groups.

    **Inventory:** typically the default `hosts`, but limited to specific host groups with `--limit otherubuntuvms` for infrastructure, and `--limit apollovms` for apollo instances.


## Typical build flow (high-level)

1. **Provision VM(s)** with Terraform (see `../../terraform-nectar/README.md`),
2. **Select the appropriate host-based inventory** (e.g. `buildapollosandpit.inventory`, `buildwebservervms.inventory`, `buildnewportalvms.inventory`, etc.).
3. **Run playbooks to integrate host with Apollo infrastructure servers**. For example:
    - add local IP to hosts: `ansible-playbook playbook-set-etc-hosts-ip.yml --inventory-file buildapollosandpit.inventory --limit changeipvms`
    - add export for apollo to NFS: `ansible-playbook playbook-apollo-ubuntu-nfs-server.yml --inventory-file buildapollosandpit.inventory --limit nfsservervms`
4.  For infrastructure servers *only*. **Run the base playbook** for baseline OS hardening, adding admins, installing standard sofware, etc.  For example:
    - base build (apollo-portal):  `ansible-playbook playbook-base-nectar-server-ubuntu.yml --inventory-file buildwebservervms.inventory --limit apollo-portal.genome.edu.au`
5. **Run the host-specific setup playbook(s)** for the target role. For example:
    - setup host (apollo-sandpit): `ansible-playbook playbook-setup-nectar-apollosandpit.yml --inventory-file buildapollosandpit.inventory --limit newapollovms`
    - setup host (apollo-portal): `ansible-playbook playbook-setup-nectar-portal.yml --inventory-file buildnewportalvms.inventory --limit apollo-portal.genome.edu.au`
6. **Apply post-build tasks** (backups, monitoring, mounts). For example:
    - add to monitoring (uses `hosts` inventory: `ansible-playbook playbook-monitor-refresh-sources-and-dashboards.yml --limit monitorservervms`
    - add to apollo2 backups: `ansible-playbook playbook-apollo-add-to-backup-server.yml --inventory-file buildsandpit.inventory --limit backupservervms`
7. **Verify**: service reachability, certificates, systemd services, backups and Prometheus targets.


