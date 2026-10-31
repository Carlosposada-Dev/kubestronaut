#!/usr/bin/env bash
# Acceptance tests, run inside cp1: health gates first, then the tutorial's Phase 5 checks.
# Exits 1 if any gate fails.
fail=0
check() { local name=$1; shift; if "$@"; then echo "PASS  $name"; else echo "FAIL  $name"; fail=1; fi; }

kubectl wait -n calico-system --for=condition=Ready pod -l k8s-app=calico-node --timeout=300s >/dev/null 2>&1
kubectl wait -n kube-system --for=condition=Ready pod -l k8s-app=kube-dns --timeout=300s >/dev/null 2>&1

echo "== Gates"
ready=$(kubectl get nodes --no-headers | awk '$2=="Ready"' | wc -l)
versions=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.nodeInfo.kubeletVersion}{"\n"}{end}' | sort -u)
calico=$(kubectl get pods -n calico-system -l k8s-app=calico-node \
  -o jsonpath='{range .items[*]}{.spec.nodeName}={.status.containerStatuses[0].ready}{"\n"}{end}' | sort)
dns_bad=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | awk '$3!="Running"' | wc -l)
dns_all=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | wc -l)
tigera=$(kubectl get tigerastatus calico -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
check "3 nodes Ready ($ready)"                         [ "$ready" = 3 ]
check "same kubelet VERSION ($(echo $versions))"       [ "$(echo "$versions" | wc -l)" = 1 ]
check "calico-node 1/1 on each node ($(echo $calico))" [ "$(echo "$calico" | grep -c '=true$')" = 3 ]
check "CoreDNS Running ($dns_all pods)"                [ "$dns_all" -ge 1 ] && [ "$dns_bad" = 0 ]
check "tigerastatus calico Available=$tigera"          [ "$tigera" = True ]

echo "== 1. Control-plane taint"
kubectl describe node cp1 | grep -i -A1 taints
echo "== 2. Static Pod manifests"
sudo ls /etc/kubernetes/manifests/
echo "== 3. Mirror Pod hash"
kubectl get pod kube-apiserver-cp1 -n kube-system -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.mirror}{"\n"}'
echo "== 4. DNS + ClusterIP"
out=$(kubectl run t --image=busybox:1.28 --restart=Never -i --rm --quiet -- \
  sh -c 'nslookup kubernetes.default; wget -qO- -T3 10.96.0.1:443 2>&1 | head -1' 2>/dev/null)
echo "$out" | awk '!seen[$0]++'
check "DNS resolves kubernetes.default to 10.96.0.1" grep -q 'Address 1: 10.96.0.1' <<<"$out"
echo "== 5. Scheduling (no replica on cp1)"
kubectl create deploy web --image=nginx --replicas=4 >/dev/null
kubectl rollout status deploy web --timeout=180s >/dev/null
placed=$(kubectl get pods -l app=web -o custom-columns=NODE:.spec.nodeName --no-headers)
echo "$placed" | sort | uniq -c
kubectl delete deploy web >/dev/null
check "4 replicas, none on cp1" [ "$(echo "$placed" | grep -cvx cp1)" = 4 ]
echo "== 6. Certificates"
sudo kubeadm certs check-expiration 2>/dev/null | grep -E '^(apiserver |admin.conf|ca |etcd-ca)'

exit $fail
