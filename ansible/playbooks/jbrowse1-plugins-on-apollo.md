# Installing JBrowse1 plugins on Apollo instances

Apollo 2.x embeds JBrowse1 inside its WAR (served at `/apollo/jbrowse/…`). Custom JBrowse1 plugins (e.g. [bhofmei/jbplugin-methylation](https://github.com/bhofmei/jbplugin-methylation)) are installed by dropping the plugin into `webapps/apollo/jbrowse/plugins/<PluginID>/` and registering it in `jbrowse.conf`. This is automated by the [apollo-install-jbrowse1-plugins](../roles/apollo-install-jbrowse1-plugins/) role.

**Not to be confused with:** JBrowse2 plugins (the standalone JBrowse2 install at `/var/www/<domain>/jbrowse2/`, installed by [jbrowse2-install-web](../roles/jbrowse2-install-web/)) or the JBrowse portal plugins (`group_vars/jbrowseportalvms/vars`, consumed by [jbrowse-build-jbrowse-on-portal](../roles/jbrowse-build-jbrowse-on-portal/)). Those are separate deployment targets.

## How it works

1. Plugins are declared per host (or per group) as a list under `apollo_jbrowse1_plugins`. Empty list = no-op.
2. The role clones each plugin into `/var/lib/tomcat9/webapps/apollo/jbrowse/plugins/<name>/`, registers a `[plugins.<name>]` block in `jbrowse.conf`, chowns the tree to `tomcat`, and restarts Tomcat only if something changed.
3. The role is idempotent. Because Tomcat re-extracts the WAR on every `apollo.war` redeploy, the role must run **after** [apollo-deploy-war](../roles/apollo-deploy-war/) — it is already wired into [playbook-build-nectar-apollo.yml](playbook-build-nectar-apollo.yml) under the `deploy` tag, so a normal Apollo build/redeploy re-establishes plugins automatically.

## Declaring a plugin

Add to `host_vars/<apollo>.genome.edu.au/vars` (or `group_vars/<group>/vars` for a shared list):

```yaml
---
apollo_jbrowse1_plugins:
  - name: MethylationPlugin          # must match the plugin's hardcoded ID (also the folder name)
    repo: "https://github.com/bhofmei/jbplugin-methylation"
    version: master                  # optional, default 'master'
    # config:                        # optional, rendered as key = value lines inside [plugins.<name>]
    #   extendedModifications: "true"
    #   isAnimal: "false"
```

`name` **must** match the plugin's declared JBrowse plugin ID (not the repo name). For `jbplugin-methylation` the ID is `MethylationPlugin`.

## Running the install

Two supported paths:

- **Standalone (no WAR redeploy)** — [playbook-install-apollo-jbrowse1-plugins.yml](playbook-install-apollo-jbrowse1-plugins.yml). Assumes the webapp is already extracted and healthy. Fastest and safest for adding a plugin to a live production Apollo.

  ```
  ansible-playbook playbook-install-apollo-jbrowse1-plugins.yml \
    --inventory-file hosts \
    --limit <apollo>.genome.edu.au
  ```

- **Full deploy** — `playbook-build-nectar-apollo.yml --tags deploy`. Re-copies the WAR, restarts Tomcat, then installs the plugin. Requires the standard build vars because [apollo-decode-extravars-setfacts-combined](../roles/apollo-decode-extravars-setfacts-combined/) runs unconditionally:

  ```
  ansible-playbook playbook-build-nectar-apollo.yml \
    --inventory-file hosts \
    --limit <apollo>.genome.edu.au \
    --tags deploy \
    --extra-vars "apollo_instance_number=<NN> apollo_subdomain_name=<subdomain>"
  ```

  Use this when you want to redeploy the WAR at the same time as adding a plugin.

## Per-organism registration (required for Apollo)

Registering the plugin in `jbrowse.conf` is **not** sufficient on Apollo's embedded JBrowse — each organism's `trackList.json` that uses plugin-provided track types must **also** declare the plugin at the top level, otherwise clicking a track fails with `Failed to load resource: <PluginID>/Store/...`.

The organism's `trackList.json` (on the NFS server under `apollo_data/<Organism>/`) needs:

```json
"plugins": {
  "MethylationPlugin": {
    "extendedModifications": true
  }
},
```

- `location` is deliberately omitted; JBrowse defaults to `plugins/<Name>/` (relative to `/apollo/jbrowse/`), which is where the role installs it.
- Any keys inside the object are passed through as plugin config (`extendedModifications` shown; see the plugin's own docs for what it accepts).
- Mirror this from an organism that already works — e.g. apollo-021's `methylation_test_bk/trackList.json`.

This is per-organism data configuration, **not infrastructure**. It's a manual/data-side change and is out of scope for the role. After editing, no restart is needed — hard-refresh the browser to bypass client-side caching of `trackList.json`.

## Verification

1. On the Apollo VM: `ls /var/lib/tomcat9/webapps/apollo/jbrowse/plugins/<PluginID>/` shows the cloned repo.
2. `sudo grep -A5 <PluginID> /var/lib/tomcat9/webapps/apollo/jbrowse/jbrowse.conf` shows the `[plugins.<PluginID>]` block.
3. `curl -sI https://<apollo>.genome.edu.au/apollo/jbrowse/plugins/<PluginID>/js/main.js` returns 200.
4. In an organism configured to use the plugin, click one of its tracks and confirm no `Failed to load resource` errors in the browser console.
5. Re-run the standalone playbook and confirm no changed tasks (idempotency).

## Reference

- Role: [ansible/roles/apollo-install-jbrowse1-plugins/](../roles/apollo-install-jbrowse1-plugins/)
- Standalone playbook: [playbook-install-apollo-jbrowse1-plugins.yml](playbook-install-apollo-jbrowse1-plugins.yml)
- Full build playbook (imports the role under the `deploy` tag): [playbook-build-nectar-apollo.yml](playbook-build-nectar-apollo.yml)
- Historical rollout record for MethylationPlugin on apollo-037: [../../install-methylationplugin.md](../../install-methylationplugin.md)
