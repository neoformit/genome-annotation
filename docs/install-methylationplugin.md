# Installing bhofmei/jbplugin-methylation on apollo-037

## Context

Client `mtan_user` on apollo-037 needed the [MethylationPlugin](https://github.com/bhofmei/jbplugin-methylation) (`bhofmei/jbplugin-methylation`) in Apollo's embedded JBrowse1 for methylation-track visualisation. The same plugin runs on apollo-021 (installed manually years ago by a previous sysadmin). This doc records the sequence that actually got it working on 037 on **2026-07-07**, including the false starts, so future occurrences can skip them.

Result: plugin baked into the WAR shipped from apollo-deploy, extracted onto apollo-037 by Tomcat, verified visible in the analytics ping's `plugins=` list, and rendering methylation tracks (WT HTML Methylation, etc.) on the "Test OK (Methylation)" organism.

## Installatioan approach

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

Once the plugin is baked into the WAR (steps above), no top-level `plugins` block is required in any organism's `trackList.json` — the plugin's Dojo AMD package is already registered globally via the compiled bundles. Activation is done **per track**, by pointing the relevant track's `storeClass` and `type` at the plugin's classes. For a bigwig methylation track:

```json
{
  "storeClass" : "MethylationPlugin/Store/SeqFeature/MethylBigWig",
  "type"       : "MethylationPlugin/View/Track/Wiggle/MethylPlot",
  ...
}
```

Files live on the NFS server: `/mnt/user-data/nectar/apollo-037/apollo_data/<Organism>/trackList.json`. No Tomcat restart needed after editing; hard-refresh the browser to bypass client-side caching.
