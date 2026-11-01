#!/usr/bin/env bash
# Re-point everything that depends on node IPs at the current ones: ssh cp1 → w1/w2 and the lab block
# in /etc/hosts (+ its cloud-init template) on every running lab node. Runs on the lab HOST.
# Use after cp1/w1/w2 are recreated. A snapshot keeps whatever was true when it was taken.
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh
w3_ip_record

log "cp1=$(ip cp1) w1=$(ip w1) w2=$(ip w2) w3=$W3_IP"
running=$(multipass list --format csv | awk -F, 'NR>1 && $2=="Running" && $1~/^(cp1|w[123])$/{print $1}')
ssh_sync
hosts_sync $running
multipass exec cp1 -- bash -c 'ssh w1 hostname && ssh w2 hostname && getent hosts cp1 w1 w2 w3'
