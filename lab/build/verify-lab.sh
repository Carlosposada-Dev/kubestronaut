#!/usr/bin/env bash
# Prove the build: tool matrix per node × snapshot, acceptance on the default base, IPs unchanged.
# Leaves cp1/w1/w2 on lab-v<next> and w3 on prep<next>, all running. Runs on the lab HOST.
set -euo pipefail
cd "$(dirname "$0")"
source ./common.sh

NEXT_MINOR=${NEXT_MINOR:-1.37}
BASE_MINOR=${BASE_MINOR:-1.36}
NEXT_SNAP="lab-v$(echo "$NEXT_MINOR" | tr -d .)"
BASE_SNAP="lab-v$(echo "$BASE_MINOR" | tr -d .)"
W3_SNAP="prep$(echo "$NEXT_MINOR" | tr -d .)"
OUT=matrix-$(date +%Y%m%d-%H%M).txt

restore() {  # $1 = snapshot, $2.. = nodes
  local s=$1; shift
  multipass stop "$@" >/dev/null
  for n in "$@"; do multipass restore "$n.$s" --destructive >/dev/null; done
  multipass start "$@" >/dev/null
  for n in "$@"; do wait_ssh "$n"; done
}

: > "$OUT"
for s in "$BASE_SNAP" "$NEXT_SNAP"; do
  log "restore $s and audit"
  restore "$s" cp1 w1 w2
  for n in cp1 w1 w2; do audit "$n" | sed "s/^/$n $s /" >> "$OUT"; done
done
log "restore w3.$W3_SNAP and audit"
restore "$W3_SNAP" w3
audit w3 | sed "s/^/w3 $W3_SNAP /" >> "$OUT"

log "acceptance on $NEXT_SNAP"
for _ in $(seq 1 60); do [ "$(kc get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)" = 3 ] && break; sleep 10; done
multipass transfer acceptance.sh cp1:/tmp/acceptance.sh
multipass exec cp1 -- bash /tmp/acceptance.sh 2>&1 | grep -v "couldn't attach" | tee acceptance-verify.log
multipass exec cp1 -- rm -f /tmp/acceptance.sh /tmp/audit.sh
for n in w1 w2 w3; do multipass exec "$n" -- rm -f /tmp/audit.sh; done

log "IPs and everything that depends on them"
w3_ip_record
echo "cp1=$(ip cp1) w1=$(ip w1) w2=$(ip w2) w3=$(ip w3)"
[ "$(ip w3)" = "$W3_IP" ] && echo "PASS  w3 kept $W3_IP" || echo "FAIL  w3 is $(ip w3), expected $W3_IP"
multipass exec cp1 -- bash -c 'ssh w1 hostname && ssh w2 hostname' >/dev/null 2>&1 \
  && echo "PASS  ssh cp1 -> w1, w2" || echo "FAIL  ssh cp1 -> w1, w2"
for n in cp1 w1 w2 w3; do
  # /etc/hosts only (getent would fall back to multipass DNS), minus Ubuntu's own "127.0.1.1 <hostname>"
  got=$(multipass exec "$n" -- awk '$1!~/^127\./ && $2~/^(cp1|w1|w2|w3)$/{printf "%s=%s ", $2, $1}' /etc/hosts)
  want="cp1=$(ip cp1) w1=$(ip w1) w2=$(ip w2) w3=$W3_IP "
  [ "$got" = "$want" ] && echo "PASS  /etc/hosts on $n" || echo "FAIL  /etc/hosts on $n: $got"
done

log "tool matrix → $OUT"
awk '{k=$3; c=$1"/"$2; v[k,c]=$4; if(!(k in seen)){seen[k]=1; keys[++nk]=k} if(!(c in sc)){sc[c]=1; cols[++nc]=c}}
     END{printf "%-16s", "tool"; for(i=1;i<=nc;i++) printf " %-15s", cols[i]; print "";
         for(j=1;j<=nk;j++){printf "%-16s", keys[j]; for(i=1;i<=nc;i++) printf " %-15s", v[keys[j],cols[i]]; print ""}}' "$OUT"
grep -q '^FAIL' acceptance-verify.log && exit 1 || true
