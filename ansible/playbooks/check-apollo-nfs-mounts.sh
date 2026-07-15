#!/bin/bash
#
# Run this on apollo-deploy VM
#
# Sweep client Apollo VMs and report whether /home/data (NFS-mounted
# apollo_data) is currently mounted. Run on apollo-deploy (which already
# has ssh access to every apollo-XXX host via the ubuntu user).
#
# Prints one line per host:
#   OK <host>           mounted
#   UNMOUNTED <host>    ssh worked but /home/data not mounted
#   UNREACHABLE <host>  ssh failed / timed out / df hung

export VAULT_PASS_ALLOW_NULL=1
ANSIBLE_HOSTS_PATH=/opt/github-ansible/ansible/playbooks/hosts
HOSTS=$(ansible -i "$ANSIBLE_HOSTS_PATH" apollovms --list-hosts | grep apollo)

if [ -z "$HOSTS" ]; then
    echo "Could not read hosts from $ANSIBLE_HOSTS_PATH." >&2
    exit 2
fi

for host in $HOSTS; do
    out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -n "ubuntu@${host}" 'timeout 10 df -h /home/data 2>&1' 2>&1)

    line=$(echo "$out" | awk '$NF=="/home/data"{print $1, $2, $5; exit}')
    if [ -n "$line" ]; then
        printf 'OK           %-32s  %s\n' "$host" "$line"
    elif [ -z "$out" ] || echo "$out" | grep -qE 'Connection|refused|timed out|resolve'; then
        printf 'UNREACHABLE  %-32s  %s\n' "$host" "$(echo "$out" | head -1)"
    else
        printf 'UNMOUNTED    %-32s\n' "$host"
    fi
done
