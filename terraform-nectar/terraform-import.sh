#!/bin/bash
# Terraform state import script for Apollo Nectar infrastructure.
# Run from terraform-nectar/ with OpenStack credentials sourced:
#   source apollo-openrc.sh
#   bash terraform-import.sh
#
# After completion, run `terraform plan` to verify — expected result:
#   Plan: 1 to add, 0 to change, 0 to destroy
# (the 1 addition is the new apollo VM you added to apollo-varsanddata.tf)

set -e

# VMs must be imported first — the floating IP resources use
# `for_each = openstack_compute_instance_v2.*_apollo_vms` which Terraform
# cannot evaluate until those VM resources are present in state.

echo "=== Infrastructure Servers ==="
terraform import openstack_compute_instance_v2.tfs_apollo_backup_20250430    b0e8991a-7d57-45ca-b89d-89b0818474a2
terraform import openstack_compute_instance_v2.tfs_apollo_user_nfs_20250512  2a62b7de-5d86-4c19-934c-e36bd2ac59ff
terraform import openstack_compute_instance_v2.tfs_apollo_monitor_20250529   76f35eb4-15a9-4976-8f45-895ae41b88bc
terraform import openstack_compute_instance_v2.tfs_apollo_portal_20250609    620088fb-c73d-4841-9bf9-7ae857dccd8d
terraform import openstack_compute_instance_v2.tfs_jbrowse_portal_20250617   626595ae-d16d-44f0-a3f7-1da7edb3ef29
terraform import openstack_compute_instance_v2.tfs_jbrowse2_portal_20251106  afddb7fe-6a20-40ef-ab83-bf677591c028

echo "=== Internal Apollo VMs ==="
terraform import 'openstack_compute_instance_v2.internal_apollo_vms["001"]'  bc099181-5fcd-4910-89cd-c2a2d27b2067
terraform import 'openstack_compute_instance_v2.internal_apollo_vms["004"]'  d1c26069-3dc9-4381-a36b-02675c8c7b20
terraform import 'openstack_compute_instance_v2.internal_apollo_vms["011"]'  74b7d27f-af7a-45d9-806b-edf7db83c7b7

echo "=== Client Apollo VMs ==="
terraform import 'openstack_compute_instance_v2.client_apollo_vms["003"]'    a5d28166-e684-4f08-94a8-db1b01d0ba04
terraform import 'openstack_compute_instance_v2.client_apollo_vms["016"]'    26318764-81d9-47ee-b1b0-769f0ffb546f
terraform import 'openstack_compute_instance_v2.client_apollo_vms["017"]'    6c2d0e53-6163-405d-86d7-66f3190a36cb
terraform import 'openstack_compute_instance_v2.client_apollo_vms["018"]'    e9019e09-4130-4e5b-bc87-5a35d61c04a9
terraform import 'openstack_compute_instance_v2.client_apollo_vms["019"]'    d3cf6df7-0c5d-4f6b-942a-8f2ba227c95a
terraform import 'openstack_compute_instance_v2.client_apollo_vms["021"]'    c60b00cc-68b1-44eb-aa7d-0d1d6cc74b32
terraform import 'openstack_compute_instance_v2.client_apollo_vms["022"]'    f12dfc67-dc1e-4936-9e5f-c3e10e934396
terraform import 'openstack_compute_instance_v2.client_apollo_vms["024"]'    68127771-1486-4650-abc7-bbf95537a043
terraform import 'openstack_compute_instance_v2.client_apollo_vms["025"]'    bb1843e7-899b-435a-9a0a-9402c54700ce
terraform import 'openstack_compute_instance_v2.client_apollo_vms["026"]'    84810772-45aa-4e6f-9fda-4c90493f4ce2
terraform import 'openstack_compute_instance_v2.client_apollo_vms["029"]'    d0ea58b7-0b23-4043-b502-4b3285497622
terraform import 'openstack_compute_instance_v2.client_apollo_vms["030"]'    59715d56-238a-46bc-b9af-7a8084cbb721
terraform import 'openstack_compute_instance_v2.client_apollo_vms["031"]'    83ae16f3-22d5-4f8f-8fd8-02f8b7db8eeb
terraform import 'openstack_compute_instance_v2.client_apollo_vms["033"]'    efd80d5a-28e2-4f75-b5c3-d2698db96306
terraform import 'openstack_compute_instance_v2.client_apollo_vms["034"]'    3b7be137-909b-4c69-a0e4-b787d2ac1d02
terraform import 'openstack_compute_instance_v2.client_apollo_vms["035"]'    0946173d-433d-45de-a6ef-5b92fd157d30
terraform import 'openstack_compute_instance_v2.client_apollo_vms["036"]'    a6794ee8-3ae7-45ef-9f51-03e551fb9b43

echo "=== Temporary Apollo VMs ==="
terraform import 'openstack_compute_instance_v2.temporary_apollo_vms["999"]' 00ce18cf-bc4d-4afc-a231-2daceadf3e2b

echo "=== Security Groups ==="
terraform import openstack_networking_secgroup_v2.SSH_access                  4a05ca02-fc3b-4e3f-87f0-7189f3344792
terraform import openstack_networking_secgroup_v2.Web_Server_access_full      924a8bd2-c81d-40ea-8f84-d3e004d19a13
terraform import openstack_networking_secgroup_v2.Globus_Connect_access       9cce02ba-463e-4c9c-be56-802793369666
terraform import openstack_networking_secgroup_v2.NFS_Server_local_access     00da313a-5a3f-40f3-9f78-8cdd1ed8829a
terraform import openstack_networking_secgroup_v2.Postgresql_allowed_group    587c8625-53e0-43b9-96c5-fe7e2c84ac22
terraform import openstack_networking_secgroup_v2.Postgresql_Server_local_access 1a12935b-a934-4de1-ab11-c97cbce6424d
terraform import openstack_networking_secgroup_v2.ICMP_local_access           612d5e5e-3fde-4891-a8ea-a557b986ab35
terraform import openstack_networking_secgroup_v2.SequenceServer_Web_access   1d3e74f4-a60d-4262-ab2e-6c23586eb8ed
terraform import openstack_networking_secgroup_v2.Apollo3_Server_access       b1349300-9299-4465-bc4a-c0f765cc17f1
terraform import openstack_networking_secgroup_v2.NRPE_local_access           c7ac69ca-ae21-40da-86f0-51b3523f5ce7
terraform import openstack_networking_secgroup_v2.Prometheus_Server_local_access c4a7b8aa-8e39-4c26-9660-9433986a8ea0
terraform import openstack_networking_secgroup_v2.Prometheus_Server_Web_access   4c9501b6-508d-4346-ac9f-ca6f3cc69b7a
terraform import openstack_networking_secgroup_v2.Grafana_Server_Web_access   3b831be7-63b5-46d4-8926-6a8cfafa2b71

echo "=== Security Group Rules ==="
terraform import openstack_networking_secgroup_rule_v2.SSH_access-ingress-tcp-22                                    39da7876-4d53-4795-8117-ebcd0ec68891
terraform import openstack_networking_secgroup_rule_v2.Web_Server_access_full-ingress-tcp-80                        91d5c25c-715b-46bf-ac44-07c22c222319
terraform import openstack_networking_secgroup_rule_v2.Web_Server_access_full-ingress-tcp-443                       45648af8-3f89-46c1-8d00-bc574cee6cd4
terraform import openstack_networking_secgroup_rule_v2.Web_Server_access_full-ingress-tcp-8080                      479fd23e-424a-4d8c-954c-3164f012b2bb
terraform import openstack_networking_secgroup_rule_v2.Globus_Connect_access-ingress-tcp-50000_51000                70c23ecf-6236-44b3-8765-951444a73757
terraform import openstack_networking_secgroup_rule_v2.NFS_Server_local_access-ingress-tcp-111                      aa835680-7a4a-4763-add2-90317c0c94e8
terraform import openstack_networking_secgroup_rule_v2.NFS_Server_local_access-ingress-udp-111                      bb32fd65-eb5c-40e5-90d6-f70047292e26
terraform import openstack_networking_secgroup_rule_v2.NFS_Server_local_access-ingress-tcp-2049                     371fd11b-e2c5-4335-8d55-1c3087a711c7
terraform import openstack_networking_secgroup_rule_v2.NFS_Server_local_access-ingress-tcp-50003                    790a1645-57a0-43b4-88f6-e24bbd461855
terraform import openstack_networking_secgroup_rule_v2.NFS_Server_local_access-ingress-udp-50003                    ba9ccb2f-8109-4d10-b5ee-8ce03168fe5e
terraform import openstack_networking_secgroup_rule_v2.Postgresql_allowed_group-outbound-tcp-5432                   946199d1-51c8-411d-9fec-01dbf73c1ce3
terraform import openstack_networking_secgroup_rule_v2.Postgresql_Server_local_access-ingress-tcp-5432              263fc27e-dfc9-48f1-b165-31e699224224
terraform import openstack_networking_secgroup_rule_v2.ICMP_local_access-ingress-icmp-Any                           2d9dda3b-3198-468f-9da9-1bd41123ef6c
terraform import openstack_networking_secgroup_rule_v2.SequenceServer_Web_access-ingress-tcp-4567                   82f1cf00-c043-48e8-9f60-99f5d3e89377
terraform import openstack_networking_secgroup_rule_v2.Apollo3_Server_access-ingress-tcp-3999                       3a69459f-a32f-4b7c-8454-066ff0843907
terraform import openstack_networking_secgroup_rule_v2.Apollo3_Server_access-ingress-tcp-9000                       b177a4a3-02c9-4954-b0ec-fb8be15e18f0
terraform import openstack_networking_secgroup_rule_v2.NRPE_local_access-ingress-tcp-5666                           d03908b9-a3a0-4dad-8004-e217c07e4468
terraform import openstack_networking_secgroup_rule_v2.Prometheus_Server_local_access-ingress-tcp-9090              6d9a751e-7e6f-4bd0-a6f4-879fe27a5a88
terraform import openstack_networking_secgroup_rule_v2.Prometheus_Server_local_access-node_exporter-ingress-tcp-9100 1990a575-cebc-46cc-9766-ad0d0678ccce
terraform import openstack_networking_secgroup_rule_v2.Prometheus_Server_Web_access-ingress-tcp-9090                c8c9bde2-106d-45c2-95f0-677d8cb4faf6
terraform import openstack_networking_secgroup_rule_v2.Grafana_Server_Web_access-ingress-tcp-3000                   1f7354d2-d766-46d4-906b-e772a259a43a

echo "=== Floating IPs (infrastructure) ==="
terraform import openstack_networking_floatingip_v2.apollo_backup_fip         4c58f91f-e71b-449a-aa35-08bccf221b0b
terraform import openstack_networking_floatingip_v2.apollo_user_nfs_fip       6202e197-8cc4-478e-8624-d998fa357efb
terraform import openstack_networking_floatingip_v2.apollo_monitor_fip        8d312bbc-7807-4e18-a83f-27dad872ded0
terraform import openstack_networking_floatingip_v2.apollo_portal_fip         7023ff0d-bf8c-4b6c-912c-79faaf583af8
terraform import openstack_networking_floatingip_v2.jbrowse_portal_fip        aceac80b-2322-4404-9621-03b1c2b4bd9d
terraform import openstack_networking_floatingip_v2.jbrowse2_portal_fip       af4ac223-bf88-4b64-a90b-f5e30ba74c75

echo "=== Floating IPs (internal apollos) ==="
terraform import 'openstack_networking_floatingip_v2.internal_apollo_fips["001"]' a28a67ab-45c5-4a9b-8a0d-e82f097c24e1
terraform import 'openstack_networking_floatingip_v2.internal_apollo_fips["004"]' 6d0367fd-dacf-4a44-b51f-1284a55d1e27
terraform import 'openstack_networking_floatingip_v2.internal_apollo_fips["011"]' 617fedbb-63b0-4251-b462-59628bec4cd8

echo "=== Floating IPs (client apollos) ==="
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["003"]'   a1a99894-c10c-4b84-8335-8067484aca1e
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["016"]'   1aa879b7-4c11-471c-9b0b-ebbdc946c399
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["017"]'   ebacbec8-6be4-4ad7-987f-6a35ed1af553
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["018"]'   fe9ba43a-2e0b-4221-8dc6-f5aaad612051
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["019"]'   701d01d3-7dbb-4010-ab59-5640423a244d
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["021"]'   df5fb817-9a3e-4b07-abf1-51f6bbb309b7
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["022"]'   18d4af6c-70bc-48c8-8c77-dfd1337adeae
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["024"]'   74342cf1-b0da-46ea-9b5f-7391e436a61d
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["025"]'   32cee966-290d-4390-82de-58fd30d9118f
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["026"]'   cef6fdb7-1123-4aec-beb8-233bbdc71c8c
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["029"]'   f525e44b-8a39-4aa3-89df-e89476392943
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["030"]'   1dbaf72c-179f-4436-90b4-3739b1c7bcd7
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["031"]'   af0a725b-ca5f-4ee8-97c7-4e785ce50ff9
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["033"]'   df0b11aa-d571-412a-864c-b72deb36a5c2
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["034"]'   72d82455-bd3e-42c2-b80c-8e33ecaa42e3
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["035"]'   59c39d79-cc87-4445-a701-058209ef191b
terraform import 'openstack_networking_floatingip_v2.client_apollo_fips["036"]'   3d46b9a7-5ef3-411e-9894-48baee8d7b94

echo "=== Floating IPs (temporary apollos) ==="
terraform import 'openstack_networking_floatingip_v2.temporary_apollo_fips["999"]' adeca863-acc7-4014-be70-68cd57289e3c

echo "=== Floating IP Associations (infrastructure) ==="
terraform import openstack_networking_floatingip_associate_v2.apollo_backup_fip_assoc      4c58f91f-e71b-449a-aa35-08bccf221b0b
terraform import openstack_networking_floatingip_associate_v2.apollo_user_nfs_fip_assoc    6202e197-8cc4-478e-8624-d998fa357efb
terraform import openstack_networking_floatingip_associate_v2.apollo_monitor_fip_assoc     8d312bbc-7807-4e18-a83f-27dad872ded0
terraform import openstack_networking_floatingip_associate_v2.apollo_portal_fip_assoc      7023ff0d-bf8c-4b6c-912c-79faaf583af8
terraform import openstack_networking_floatingip_associate_v2.jbrowse_portal_fip_assoc     aceac80b-2322-4404-9621-03b1c2b4bd9d
terraform import openstack_networking_floatingip_associate_v2.jbrowse2_portal_fip_assoc    af4ac223-bf88-4b64-a90b-f5e30ba74c75

echo "=== Floating IP Associations (internal apollos) ==="
terraform import 'openstack_networking_floatingip_associate_v2.internal_apollo_fips_associate["001"]' a28a67ab-45c5-4a9b-8a0d-e82f097c24e1
terraform import 'openstack_networking_floatingip_associate_v2.internal_apollo_fips_associate["004"]' 6d0367fd-dacf-4a44-b51f-1284a55d1e27
terraform import 'openstack_networking_floatingip_associate_v2.internal_apollo_fips_associate["011"]' 617fedbb-63b0-4251-b462-59628bec4cd8

echo "=== Floating IP Associations (client apollos) ==="
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["003"]'   a1a99894-c10c-4b84-8335-8067484aca1e
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["016"]'   1aa879b7-4c11-471c-9b0b-ebbdc946c399
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["017"]'   ebacbec8-6be4-4ad7-987f-6a35ed1af553
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["018"]'   fe9ba43a-2e0b-4221-8dc6-f5aaad612051
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["019"]'   701d01d3-7dbb-4010-ab59-5640423a244d
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["021"]'   df5fb817-9a3e-4b07-abf1-51f6bbb309b7
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["022"]'   18d4af6c-70bc-48c8-8c77-dfd1337adeae
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["024"]'   74342cf1-b0da-46ea-9b5f-7391e436a61d
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["025"]'   32cee966-290d-4390-82de-58fd30d9118f
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["026"]'   cef6fdb7-1123-4aec-beb8-233bbdc71c8c
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["029"]'   f525e44b-8a39-4aa3-89df-e89476392943
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["030"]'   1dbaf72c-179f-4436-90b4-3739b1c7bcd7
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["031"]'   af0a725b-ca5f-4ee8-97c7-4e785ce50ff9
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["033"]'   df0b11aa-d571-412a-864c-b72deb36a5c2
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["034"]'   72d82455-bd3e-42c2-b80c-8e33ecaa42e3
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["035"]'   59c39d79-cc87-4445-a701-058209ef191b
terraform import 'openstack_networking_floatingip_associate_v2.client_apollo_fips_associate["036"]'   3d46b9a7-5ef3-411e-9894-48baee8d7b94

echo "=== Floating IP Associations (temporary apollos) ==="
terraform import 'openstack_networking_floatingip_associate_v2.temporary_apollo_fips_associate["999"]' adeca863-acc7-4014-be70-68cd57289e3c

echo "=== Block Storage Volumes ==="
terraform import openstack_blockstorage_volume_v3.jbrowse_build_volume   57e28bd4-73b3-4260-b517-596aadbafb92
terraform import openstack_blockstorage_volume_v3.jbrowse2_build_volume  3655342d-a6d8-4522-8269-2674a095e479
terraform import openstack_blockstorage_volume_v3.apollo_build_volume    93fd02aa-7f05-4a6e-ad53-b40de9311802

echo "=== Volume Attachments ==="
terraform import openstack_compute_volume_attach_v2.jbrowse_build_volume    626595ae-d16d-44f0-a3f7-1da7edb3ef29/57e28bd4-73b3-4260-b517-596aadbafb92
terraform import openstack_compute_volume_attach_v2.jbrowse2_build_volume   afddb7fe-6a20-40ef-ab83-bf677591c028/3655342d-a6d8-4522-8269-2674a095e479
terraform import openstack_compute_volume_attach_v2.apollo_011_volume_attach 74b7d27f-af7a-45d9-806b-edf7db83c7b7/93fd02aa-7f05-4a6e-ad53-b40de9311802

echo ""
echo "=== Import complete. Running terraform plan to verify... ==="
terraform plan
