# Installing bhofmei/jbplugin-methylation on apollo-037

## Context

Client `mtan_user` on apollo-037 needed the [MethylationPlugin](https://github.com/bhofmei/jbplugin-methylation) (`bhofmei/jbplugin-methylation`) in Apollo's embedded JBrowse1 for methylation-track visualisation. The same plugin runs on apollo-021 (installed manually years ago by a previous sysadmin). This doc records the sequence that actually got it working on 037 on **2026-07-07**, including the false starts, so future occurrences can skip them.

Result: plugin baked into the WAR shipped from apollo-deploy, extracted onto apollo-037 by Tomcat, verified visible in the analytics ping's `plugins=` list, and rendering methylation tracks (WT HTML Methylation, etc.) on the "Test OK (Methylation)" organism.

## TL;DR — the recipe that worked

1. Confirmed a pre-baked variant tarball already existed on the deployment server:
   `/opt/apollo_files/Apollo-2.8.1+methylation-Ubuntu-deploy-20250606.tar.gz`
   (~238MB, plugin verified inside `Apollo-2.8.1/target/apollo-2.8.1.war` → `jbrowse/dist/main.bundle.js` grep MethylationPlugin > 0).
2. Pointed the deploy symlink at it:
   ```
   ssh apollo-deploy 'sudo ln -sfn ../Apollo-2.8.1+methylation-Ubuntu-deploy-20250606.tar.gz \
                                    /opt/apollo_files/deploy/Apollo-2.8.1.tar.gz'
   ```
3. Shipped the tarball to apollo-037 manually and extracted it (a `--tags deploy` playbook run *cannot* do this — see the [ansible/playbooks/README.md tarball-variant section](ansible/playbooks/README.md#apollo-tarball-variants-custom-jbrowse1-plugins-baked-in) for the reasoning):
   ```
   ssh apollo-deploy 'scp /opt/apollo_files/Apollo-2.8.1+methylation-Ubuntu-deploy-20250606.tar.gz \
                          ubuntu@apollo-037.genome.edu.au:/tmp/Apollo-2.8.1.tar.gz'
   ssh ubuntu@apollo-037.genome.edu.au 'sudo mv /tmp/Apollo-2.8.1.tar.gz /opt/Apollo-2.8.1.tar.gz
                                        sudo rm -rf /opt/Apollo-2.8.1
                                        cd /opt && sudo tar -xzf Apollo-2.8.1.tar.gz
                                        sudo chown -R root:root /opt/Apollo-2.8.1'
   ```
4. Ran the ansible deploy chain:
   ```
   ansible-playbook playbook-build-nectar-apollo.yml \
     --inventory-file hosts --limit apollo-037.genome.edu.au \
     --tags deploy \
     --extra-vars "apollo_instance_number=37 apollo_subdomain_name=mtan"
   ```
5. Verified:
   ```
   ssh ubuntu@apollo-037.genome.edu.au \
     'sudo grep -c MethylationPlugin /var/lib/tomcat9/webapps/apollo/jbrowse/dist/main.bundle.js'
   # > 0 = plugin baked into the extracted webapp
   ```
6. In the browser, hard-refresh, use the organism switcher, click a methylation track. The jbrowse analytics ping (`jbrowse.org/analytics/clientReport?...`) should list `MethylationPlugin` in its `plugins=` query param.

## Rollback

Symlink swap back to the stock tarball, then rerun steps 3 + 4:

```
ssh apollo-deploy 'sudo ln -sfn ../Apollo-2.8.1-Ubuntu-deploy-20250528.tar.gz \
                                 /opt/apollo_files/deploy/Apollo-2.8.1.tar.gz'
```

## Per-organism activation

Registering the plugin in the WAR is not enough for it to become active — each organism whose `trackList.json` uses `MethylationPlugin/*` track types must **also** declare the plugin at the top level. Apollo-021 uses this shape (verified on `methylation_test_bk/trackList.json`) and it works on 037 with the same:

```json
"plugins": {
  "MethylationPlugin": {
    "extendedModifications": true
  }
},
```

`location` is deliberately omitted — JBrowse defaults to `plugins/MethylationPlugin/` (relative to the JBrowse root). `extendedModifications: true` enables 4mC/5hmC/6mA support per the plugin README; drop it if only 5mC (CG/CHG/CHH) is needed. Files live on the NFS server: `/mnt/user-data/nectar/apollo-037/apollo_data/<Organism>/trackList.json`. No Tomcat restart needed after editing; hard-refresh the browser to bypass client-side caching.

Without this block, clicking a methylation track produces:

```
Failed to load resource: MethylationPlugin/Store/SeqFeature/MethylBigWig
```

— because Apollo's per-organism JBrowse launches from a session-scoped URL (`/apollo/<sessionid>/jbrowse/…`) and doesn't inherit plugin registrations from the global `jbrowse.conf` inside the WAR the way stock JBrowse does. The per-organism `plugins` block is what registers the Dojo AMD package.

---

## Appendix — what didn't work, and why (retain this to save the next person time)

We tried several approaches before landing on the recipe above. Each is documented here with the specific failure signal that ruled it out.

### 1. New Ansible role that dropped the plugin into the deployed webapp

We built `apollo-install-jbrowse1-plugins`, a role that:
- Cloned the plugin repo into `/var/lib/tomcat9/webapps/apollo/jbrowse/plugins/MethylationPlugin/`.
- Added `[plugins.MethylationPlugin]` to `webapps/apollo/jbrowse/jbrowse.conf`.
- Restarted Tomcat.

Symptom: `Failed to load resource: MethylationPlugin/Store/SeqFeature/MethylBigWig` on every methylation-track click, even though the plugin JS was clearly on disk and the JS URL returned 200. **Root cause:** JBrowse1's plugin loader doesn't scan `jbrowse.conf` at runtime — it consults a compiled Dojo AMD package registry inside `dist/*.bundle.js`. Dropping source files into `plugins/` is invisible to the loader unless `setup.sh` webpack-rebuilds the bundles. Apollo's embedded JBrowse ships pre-compiled `dist/*.bundle.js` inside the WAR, and there's no node/yarn toolchain on production Apollo VMs to re-run `setup.sh`. **This role is misdesigned — it was removed from the repo.** Do not resurrect it.

Confirmation of root cause: `dist/main.bundle.js` on apollo-021 contains `MethylationPlugin` (`grep -c` returns > 0); on apollo-037 pre-fix it did not. Once the bundles contain the plugin, the loader picks it up. `jbrowse.conf` doesn't matter — apollo-021 has the config there but that's a red herring; the compiled bundles are what activates the plugin.

### 2. `jbrowse_conf.json` swap

Suspected Apollo might read `jbrowse_conf.json` (JSON) rather than `jbrowse.conf` (INI). Not the case: both files are consulted for plugin declarations by stock JBrowse, but Apollo bypasses both — its plugin list is baked into the compiled bundles at build time via [Apollo's `apollo-config.groovy`](https://github.com/GMOD/Apollo/blob/master/grails-app/conf/apollo-config.groovy) and the JBrowse subtree's own build config. Editing either config file on the deployed webapp achieved nothing on 037.

Signal that ruled this out: the JBrowse analytics ping (`jbrowse.org/analytics/clientReport`) sends a `plugins=…` query param listing which plugins the runtime loader thinks are active. Pre-fix on 037: `plugins=HideTrackLabels,NeatCanvasFeatures,NeatHTMLFeatures,RegexSequenceSearch,WebApollo` — no MethylationPlugin, even though we'd edited `jbrowse.conf`. Post-fix: `MethylationPlugin` present.

### 3. `--tags deploy` after a symlink swap alone

Ran `ansible-playbook playbook-build-nectar-apollo.yml --tags deploy` after pointing the deploy symlink at the +methylation tarball. **Nothing happened on the target.** [`apollo-copy-tarred-build`](ansible/roles/apollo-copy-tarred-build/) has no `deploy` tag, so it was skipped; the on-target tarball at `/opt/Apollo-2.8.1.tar.gz` was never refreshed; `apollo-deploy-war` copied the same WAR that was already in place; Tomcat's `apollo.war` mtime stayed at 2025-05-28.

Signal that ruled this out: `stat` on `/var/lib/tomcat9/webapps/apollo.war` showed the original May 2025 mtime after the ansible run completed with no errors. Fix: either the full playbook run (Recipe A above) or the manual SCP + extract (Recipe B).

### 4. `--start-at-task="check that war file is on local machine"`

Tried to skip the pre-deploy roles and jump straight into the tarball-copy chain. Ansible produced an empty PLAY RECAP with zero tasks executed. Suspected reason: task name resolution across imported roles doesn't match reliably. Not worth chasing — the manual SCP path (Recipe B) is faster and less surprising.

### 5. A local WAR re-bake as a fallback

Since a pre-baked `Apollo-2.8.1+methylation-...` tarball turned out to already exist on `apollo-deploy` (built by the previous sysadmin for apollo-021's rollout in June 2025), we didn't need to rebuild from scratch. If that tarball ever goes missing, the [ansible/playbooks/README.md tarball-variant section](ansible/playbooks/README.md#apollo-tarball-variants-custom-jbrowse1-plugins-baked-in) documents how to rebuild one from the stock tarball on `apollo-deploy` (unpack WAR → drop plugin into `jbrowse/plugins/` → `chmod +x setup.sh && ./setup.sh` under node 12 + yarn 1.x via NVM → strip `node_modules/` → re-zip WAR → re-tar bundle). This was walked through end-to-end during triage and confirmed to produce a working bundle identical in structure to the June 2025 variant.

## Unrelated but concurrent: the "read-only transaction" 500

While verifying the plugin in the browser we hit HTTP 500 responses on Apollo's trackList endpoint with the catalina.out signature:

```
ERROR: cannot execute UPDATE in a read-only transaction
```

**This is not caused by the plugin work.** The error dates from 2026-06-23, weeks before the plugin was touched. It surfaces intermittently. See [investigate-apollo-037-readonly-txn.md](investigate-apollo-037-readonly-txn.md) for a full triage plan.

## Environment quick reference

- **Target host:** `apollo-037.genome.edu.au` / `mtan.genome.edu.au`.
- **Deployment host:** `apollo-deploy` (holds `/opt/apollo_files/*.tar.gz` variants and the `deploy/` symlink).
- **Extracted WAR on target:** `/var/lib/tomcat9/webapps/apollo/`.
- **Compiled bundles that must contain the plugin:** `.../jbrowse/dist/main.bundle.js` (and `1.bundle.js`, `browser.bundle.js`).
- **Per-organism data (on the NFS server):** `/mnt/user-data/nectar/apollo-037/apollo_data/<Organism>/trackList.json`.
- **Reference working install:** apollo-021, `methylation_test_bk` organism.
