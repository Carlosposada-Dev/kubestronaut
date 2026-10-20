---
title: "Clúster Kubernetes de 3 nodos con kubeadm sobre Ubuntu — guía verificada de principio a fin"
date: 2026-08-31
tags: [kubernetes, kubeadm, multipass, calico, cka, homelab]
k8s_version: v1.34.11
tested_on: Ubuntu 24.04.4 LTS · multipass 1.16.3 · containerd 2.2.1 · Calico v3.32.2
tiempo_real: ~2 h
---

# Clúster Kubernetes de 3 nodos con kubeadm sobre Ubuntu

Esta guía levanta un clúster Kubernetes real —un nodo de plano de control y dos
workers— en máquinas virtuales locales, usando `kubeadm`. No es minikube, no es
kind, no es un clúster gestionado: es la misma instalación que hace un
administrador en producción, y es la única forma honesta de prepararse para el
examen CKA.

Cada comando de aquí fue ejecutado y su salida verificada. Los errores que
aparecen en la sección de trampas son errores que ocurrieron de verdad durante
la instalación, no hipótesis.

## Por qué kubeadm y no un clúster gestionado

Si tu día a día es EKS, GKE o AKS, el proveedor te esconde el plano de control.
Nunca ves los certificados, nunca tocas etcd, nunca instalas un CNI, y el nodo
nace `Ready` por arte de magia. Eso está muy bien para producción y es terrible
para aprender.

En kubeadm todo eso es trabajo tuyo, y ahí es donde está el aprendizaje. A lo
largo de la guía marco cada punto donde un clúster gestionado se comporta
distinto, porque son exactamente los puntos ciegos que el examen ataca.

## Requisitos

| Recurso | Mínimo | Usado aquí |
|---|---|---|
| CPU | 6 hilos | Ryzen 5 3600 (6c/12t) |
| RAM | 16 GB | 48 GB |
| Disco libre | 40 GB | — |
| SO anfitrión | Linux con KVM | Ubuntu 24.04 |

Reparto por VM: **2 vCPU y 4 GB cada una**. Los 2 vCPU del nodo de plano de
control no son negociables — `kubeadm init` tiene un *preflight check* que falla
con menos.

## Decisiones de diseño

| Decisión | Elección | Motivo |
|---|---|---|
| Hipervisor | multipass (QEMU/KVM) | Snapshots nativos y VMs Ubuntu en un comando |
| Versión K8s | v1.34 | El examen CKA corre v1.35. Instalar 1.34 deja el `kubeadm upgrade` como ejercicio real |
| CNI | **Calico** | Flannel **no implementa NetworkPolicy**. Si vas a CKS, elegir Flannel significa rehacer el clúster |
| Pod CIDR | `10.244.0.0/16` | El default de Calico (`192.168.0.0/16`) choca con redes domésticas típicas |
| Runtime | containerd | Sin Docker. Dockershim no existe desde v1.24 |

Una precisión de vocabulario que conviene fijar desde el principio: lo que creas
son **tres nodos**, uno de ellos *nodo de plano de control*. El plano de control
no es la máquina — es el conjunto de componentes (apiserver, etcd, scheduler,
controller-manager) que corren sobre ese nodo.

## Convención de ubicación — léela antes de copiar nada

En un laboratorio de tres nodos vas a estar saltando entre cuatro máquinas
distintas: tu anfitrión y las tres VMs. **El error más caro de todo el montaje
no es técnico, es ejecutar el comando correcto en la máquina equivocada.**

Por eso cada bloque de comandos de esta guía lleva un banner que dice dónde se
ejecuta:

```bash
# ▶▶ HOST — cposada@cposada
```

```bash
# ▶▶ cp1 — ubuntu@cp1
```

```bash
# ▶▶ w1 — ubuntu@w1   (entra con: ssh w1   desde cp1)
```

Si un bloque no lo lleva, asume que es el anfitrión. Y adopta esta costumbre,
que cuesta un segundo y te ahorra una hora:

```bash
hostname
```

**Antes de cualquier `sudo`, `hostname`.** Es la verificación más barata que
existe y la única que impide que borres un manifiesto en el nodo equivocado.

---

# Fase 0 — Preparar el anfitrión

## 0.1 Comprobar que la virtualización está activa

```bash
egrep -c '(vmx|svm)' /proc/cpuinfo
ls -l /dev/kvm
lsmod | grep kvm
```

Lo esperado es un número mayor que cero, que `/dev/kvm` exista, y que
`lsmod` muestre `kvm_amd` (o `kvm_intel`) además de `kvm`.

**Aquí está la primera trampa, y es muy común.** El primer comando puede
devolver `12` —el CPU soporta virtualización— y aun así no existir `/dev/kvm`:

```
$ ls -l /dev/kvm
ls: cannot access '/dev/kvm': No such file or directory

$ sudo modprobe kvm_amd
modprobe: ERROR: could not insert 'kvm_amd': Operation not supported
```

`/proc/cpuinfo` reporta lo que el **silicio** sabe hacer. Que esté *habilitado*
es otra cosa, y la decide el firmware. El diagnóstico definitivo:

```bash
sudo dmesg | grep -i -e svm -e kvm
```

```
[ 0.519418] SVM disabled (by BIOS) in MSR_VM_CR
[ 15.811944] kvm_amd: SVM not supported by CPU 11
```

`SVM disabled (by BIOS)` es concluyente. Los mensajes de `not supported by CPU`
que vienen detrás son consecuencia, no una causa aparte.

## 0.2 Activar SVM / VT-x en la UEFI

Reinicia y entra a la UEFI (normalmente `Del` o `F2`). Busca **SVM Mode** en
placas AMD, o **Intel VT-x** en Intel:

| Fabricante | Ruta habitual |
|---|---|
| ASUS | Advanced → CPU Configuration → SVM Mode |
| MSI | OC → CPU Features → SVM Mode |
| Gigabyte | Tweaker / M.I.T. → Advanced CPU Settings → SVM Mode |
| ASRock | Advanced → CPU Configuration → SVM |

Ponlo en `Enabled`, guarda, y haz un **apagado completo** (algunas placas no
aplican el cambio con un reinicio caliente).

Si ves también **IOMMU / AMD-Vi**, casi nunca está junto a SVM — suele vivir en
`Advanced → AMD CBS → NBIO Common Options → IOMMU`. **No lo toques.** IOMMU solo
hace falta para *passthrough* de dispositivos PCI a una VM, cosa que esta guía
no hace, y en algunas placas activarlo sin configurar bien los grupos causa
problemas de arranque o de USB.

En dual-boot con Windows no hay conflicto: SVM es un ajuste de firmware sobre el
CPU y ningún sistema operativo lo revierte. El único efecto colateral notable es
que Windows 11 puede habilitar VBS / Integridad de memoria, que cuesta unos
puntos de FPS en juegos; se desactiva desde Windows sin tocar la UEFI.

### Nota al margen: si `reboot` se niega

```
$ sudo reboot
Operation inhibited by "cposada" (PID 4826 "gnome-session-s")...
```

systemd tiene **inhibidores**: procesos que registran "no apagues todavía". Los
de tipo `delay` solo retrasan unos segundos; los de tipo `block` deniegan.
Antes de forzar, mira quién es y por qué:

```bash
systemd-inhibit --list | cat     # el `| cat` evita que se corte la columna MODE
ps aux | grep -e unattended -e packagekit -e apt
```

Si hay un `apt` o `dpkg` instalando de verdad, **espera** — forzar te deja
paquetes a medio configurar. Si lo único que aparece es
`unattended-upgrade-shutdown --wait-for-signal`, ese proceso no está
actualizando nada: está aparcado esperando una señal de apagado para *entonces*
comprobar si hay algo en curso. Es un block inhibitor permanente por diseño, y
en ese caso forzar es seguro:

```bash
sudo systemctl reboot -i
```

## 0.3 Validación post-UEFI

```bash
sudo dmesg | grep -i svm      # ya NO debe decir "disabled (by BIOS)"
ls -l /dev/kvm                 # crw-rw----+ 1 root kvm
lsmod | grep kvm               # kvm ... 1 kvm_amd
sudo usermod -aG kvm $USER
```

El `+` en `crw-rw----+` indica que el dispositivo tiene una **ACL**:
`systemd-logind` concede acceso a `/dev/kvm` al usuario de la sesión activa
automáticamente, así que probablemente ya funcionas sin cerrar sesión.
Compruébalo con `getfacl /dev/kvm | grep $USER`. El `usermod` sigue siendo buena
idea como red de seguridad para sesiones no interactivas.

## 0.4 Instalar multipass

```bash
sudo snap install multipass
multipass version
multipass snapshot --help
```

**Ese último comando es un gate, no un adorno.** Si `snapshot` no existe, tu
multipass es anterior a la 1.13 → `sudo snap refresh multipass`. Sin snapshots
no montes este laboratorio: la mitad de su valor está en poder romperlo y
restaurarlo en tres minutos.

```bash
df -h /var/snap                # al menos 40 GB libres
```

---

# Fase 1 — Crear las tres VMs

```bash
for n in cp1 w1 w2; do
  multipass launch 24.04 --name $n --cpus 2 --memory 4G --disk 20G
done

multipass list
```

```
Name    State     IPv4              Image
cp1     Running   10.167.152.47     Ubuntu 24.04 LTS
w1      Running   10.167.152.24     Ubuntu 24.04 LTS
w2      Running   10.167.152.155    Ubuntu 24.04 LTS
```

Guarda la IP del plano de control, la vas a usar varias veces:

```bash
CP_IP=$(multipass info cp1 --format csv | awk -F, 'NR==2{print $3}')
echo $CP_IP
```

## Validación

```bash
multipass exec w1 -- ping -c2 $CP_IP
```

Latencias de **décimas de milisegundo** confirman aceleración por hardware. Si
ves decenas de ms, KVM no está en uso y algo de la Fase 0 quedó a medias.

## Cómo viven estas VMs (y qué pasa al apagarlas)

`multipassd` corre como root y lanza un proceso `qemu-system-x86_64` por
instancia. No hay magia:

- **Disco:** un archivo qcow2 por instancia en
  `/var/snap/multipass/common/data/multipassd/vault/instances/`. Es un overlay
  copy-on-write sobre la imagen base, thin-provisioned: pides 20 GB, ocupa ~5 GB.
- **RAM:** la toma el proceso qemu solo mientras la VM corre.
- **Red:** un bridge virtual `mpqemubr0` en el anfitrión, con NAT y un dnsmasq
  que reparte DHCP. Por eso los nodos se ven entre sí.

`multipass stop` es un apagado ACPI ordenado. El qcow2 queda intacto y, al
arrancar, systemd levanta `containerd` y `kubelet` porque quedaron `enabled`:
**el clúster se reconstruye solo en 1–2 minutos** sin que hagas nada.

El único riesgo real es que **cambie la IP del nodo de plano de control**: esa
dirección está grabada en los SAN de los certificados del apiserver y en todos
los kubeconfig. En la práctica no cambia, porque la MAC de cada instancia es
estable y dnsmasq devuelve el mismo lease. Conviene verificarlo **ahora**, con
las VMs vacías, y no dentro de tres meses:

```bash
multipass stop cp1 w1 w2 && multipass start cp1 w1 w2 && multipass list
sudo snap restart multipass && sleep 10 && multipass list
```

Las tres IPs deben ser idénticas tras ambas pruebas. (El `sleep` hace falta
porque `snap restart` devuelve el control antes de que `multipassd` abra su
socket; sin él verás `cannot connect to the multipass socket`, que no es un
error real.)

**Sobre la suspensión del anfitrión:** al despertar de un S3, el reloj del
*guest* dio un salto de horas. Kubernetes es sensible al tiempo: los Lease
expiran, hay reelección de líder, y verás nodos `NotReady` un par de minutos.
Se recupera solo, pero no saques conclusiones de lo que veas justo después de
despertar. La hibernación del anfitrión o un cuelgue sí equivalen a un corte de
corriente y pueden corromper etcd. Regla: `multipass stop --all` antes de cerrar
el día.

---

# Fase 2 — Preparar los tres nodos

Estos cinco pasos son idénticos en los tres nodos, así que van en un script.

```bash
cat > prep-node.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
K8S_MINOR="${K8S_MINOR:-v1.34}"

# 1. Swap fuera. El kubelet se niega a arrancar con swap activo.
sudo swapoff -a
sudo sed -i '/\sswap\s/s/^/#/' /etc/fstab

# 2. Módulos y sysctl. Sin br_netfilter el tráfico del bridge no pasa por
#    iptables y kube-proxy no funciona.
printf 'overlay\nbr_netfilter\n' | sudo tee /etc/modules-load.d/k8s.conf
sudo modprobe overlay && sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system >/dev/null

# 3. containerd con cgroup driver systemd.
#    Un desajuste aquí es la causa número uno de "el kubelet no arranca".
sudo apt-get update -qq
sudo apt-get install -y -qq containerd apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/^\(\s*\)SystemdCgroup = false/\1SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd && sudo systemctl enable containerd

# 4. crictl apuntando al socket correcto
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
EOF

# 5. Paquetes de Kubernetes
sudo mkdir -p /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -qq
sudo apt-get install -y -qq kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
SCRIPT
chmod +x prep-node.sh

for n in cp1 w1 w2; do
  multipass transfer prep-node.sh $n:/home/ubuntu/prep-node.sh
  multipass exec $n -- bash /home/ubuntu/prep-node.sh
done
```

Tarda entre 3 y 5 minutos para los tres nodos. Notas sobre el script:

- **`apt-mark hold`** impide que una actualización rutinaria del sistema mueva
  la versión de Kubernetes por debajo de tus pies. Cuando quieras actualizar de
  verdad, `apt-mark unhold` es el primer paso del procedimiento.
- **`SystemdCgroup = true`** es el ajuste que más silenciosamente falla. El
  `sed` depende de encontrar la línea exacta en el TOML generado, y el formato
  cambia entre versiones mayores de containerd. Por eso se verifica abajo.
- El `rm -f` del keyring evita que `gpg --dearmor` falle si repites el script.

## Validación — cinco líneas por nodo, quince en total

```bash
for n in cp1 w1 w2; do
  echo "--- $n"
  multipass exec $n -- bash -c '
    swapon --show | wc -l                                          # 0
    systemctl is-active containerd                                 # active
    grep -c "SystemdCgroup = true" /etc/containerd/config.toml     # 1
    sysctl -n net.ipv4.ip_forward                                  # 1
    kubeadm version -o short'
done
```

```
--- cp1
0
active
1
1
v1.34.11
```

Si el tercer valor sale `0`, **detente aquí**: el `sed` no encontró la línea y
el kubelet no va a arrancar después. Abre `/etc/containerd/config.toml` y
corrige a mano.

> Nota de versiones: Ubuntu 24.04 instala hoy **containerd 2.2.1**, bastante más
> nuevo que el que asumen la mayoría de guías. El `sed` sigue funcionando, pero
> es exactamente el motivo por el que este paso se verifica en vez de darse por
> hecho.

---

# Fase 3 — `kubeadm init` y el CNI

```bash
multipass exec cp1 -- sudo kubeadm init \
  --apiserver-advertise-address=$CP_IP \
  --pod-network-cidr=10.244.0.0/16 \
  --node-name=cp1 | tee kubeadm-init.log
```

**Guarda el log.** Contiene el comando `join` que necesitas después.

Vale la pena leer la salida en vez de esperar a que termine, porque cuenta
exactamente qué hace un plano de control:

```
[certs] Generating "ca" certificate and key
[certs] apiserver serving cert is signed for DNS names [...] and IPs [10.96.0.1 10.167.152.47]
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "super-admin.conf" kubeconfig file
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[kubelet-start] Starting the kubelet
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods
[mark-control-plane] Marking the node cp1 ... taints [node-role.kubernetes.io/control-plane:NoSchedule]
```

Ahí está el mecanismo completo: kubeadm **no arranca** el plano de control.
Escribe cuatro archivos YAML en `/etc/kubernetes/manifests/` y deja que el
kubelet los descubra. El kubelet es el único componente que puede levantar Pods
sin que exista todavía un API server, porque lee del disco, no de la API.

Si ves esta línea, es informativa y no un problema:

```
remote version is much newer: v1.37.0; falling back to: stable-1.34
```

kubeadm consultó cuál es la última estable y respetó tu minor. Es justo lo que
queremos.

## kubeconfig

```bash
# Dentro del nodo
multipass exec cp1 -- bash -c '
  mkdir -p $HOME/.kube
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config'

# Y en el anfitrión, que es desde donde vas a trabajar
mkdir -p ~/.kube
multipass exec cp1 -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config

kubectl get nodes
```

```
NAME   STATUS     ROLES           AGE   VERSION
cp1    NotReady   control-plane   27s   v1.34.11
```

**`NotReady` es el resultado correcto en este punto.** Un clúster vanilla nace
sin red. `kubectl get pods -n kube-system` muestra los dos CoreDNS en `Pending`
por el mismo motivo: no hay red donde colocarlos.

Este es el punto exacto que un clúster gestionado te esconde: allí el CNI viene
preinstalado y el nodo nace `Ready`, así que nunca ves esta fase intermedia ni
aprendes a diagnosticarla.

## Instalar Calico

```bash
CALICO_VER=$(curl -s https://api.github.com/repos/projectcalico/calico/releases/latest \
             | grep -oP '"tag_name": "\K[^"]+')
echo $CALICO_VER          # v3.32.2 al escribir esto

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VER}/manifests/tigera-operator.yaml
curl -sLO https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VER}/manifests/custom-resources.yaml
sed -i 's#192.168.0.0/16#10.244.0.0/16#' custom-resources.yaml
kubectl create -f custom-resources.yaml
```

Resolver la versión con la API de GitHub evita fijar una URL que envejece en
tres meses.

Son dos pasos con papeles distintos: `tigera-operator.yaml` instala el
**operador**, y `custom-resources.yaml` crea el objeto `Installation` que le
dice *qué* desplegar y con qué CIDR. Si te saltas el `sed`, Calico usará
`192.168.0.0/16` y no coincidirá con el `--pod-network-cidr` del init.

## Validación

```bash
kubectl get pods -n calico-system
kubectl get nodes
kubectl get pods -n kube-system
```

Espera 1–3 minutos. El pod que importa es **`calico-node`**: en cuanto pasa a
`Running`, el nodo pasa a `Ready` y CoreDNS pasa de `Pending` a `Running`. Los
demás componentes del operador (`calico-apiserver`, `goldmane`, `whisker`)
terminan de bajar imágenes después y no bloquean nada.

---

# Fase 4 — Unir los workers

```bash
JOIN=$(multipass exec cp1 -- sudo kubeadm token create --print-join-command)
echo "$JOIN"

for n in w1 w2; do multipass exec $n -- sudo $JOIN; done
```

El token que imprimió `kubeadm init` **caduca a las 24 horas**.
`token create --print-join-command` lo regenera, y es el camino reproducible.

```bash
kubectl get nodes -o wide
kubectl label node w1 node-role.kubernetes.io/worker=
kubectl label node w2 node-role.kubernetes.io/worker=
kubectl get nodes
```

Los workers aparecen `NotReady` durante ~40 segundos: el DaemonSet de Calico
tiene que colocar un `calico-node` en cada uno. Es el mismo ciclo que viviste
con `cp1`, comprimido.

La etiqueta `node-role.kubernetes.io/worker=` es puramente cosmética —
`kubectl get nodes` no infiere el rol de ninguna otra cosa.

Una advertencia de `kube-proxy` sobre `bindAddress` recomendado `::` en lugar de
`0.0.0.0` es normal y no requiere acción.

## Validación

```bash
kubectl get nodes
kubectl get pods -n calico-system -o wide | grep calico-node
```

Tres nodos `Ready`, y **un `calico-node` por nodo**. Si a un nodo le falta el
suyo, ahí está la causa de que siga `NotReady`.

---

# Fase 5 — Pruebas de aceptación

Seis comprobaciones. Ninguna es ceremonial: cada una enseña algo que un clúster
gestionado no te deja ver.

## 1. El taint del plano de control

```bash
kubectl describe node cp1 | grep -i -A2 -i taint
```
```
Taints:  node-role.kubernetes.io/control-plane:NoSchedule
```

## 2. Los static Pods, en disco

```bash
multipass exec cp1 -- sudo ls -l /etc/kubernetes/manifests/
```
```
etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml
```

Ojo: esos archivos viven **dentro del nodo**. Un `cat /etc/kubernetes/...` desde
el anfitrión falla con `No such file or directory`, y es fácil confundirse
cuando estás saltando entre las dos máquinas.

## 3. Confirmar que son mirror Pods

```bash
kubectl get pod kube-apiserver-cp1 -n kube-system \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/config\.mirror}{"\n"}'
```

Debe imprimir un hash. Un mirror Pod es un reflejo **de solo lectura** del Pod
real que gestiona el kubelet: borrarlo con `kubectl delete` no detiene nada,
porque el kubelet lo recrea desde el archivo. Para parar un static Pod se mueve
el YAML fuera del directorio.

## 4. DNS interno y conectividad al ClusterIP

```bash
kubectl run t --image=busybox:1.28 --restart=Never -it --rm -- \
  sh -c 'nslookup kubernetes.default; wget -qO- -T3 10.96.0.1:443 2>&1 | head -1'
```
```
Server:    10.96.0.10
Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
wget: server returned error: HTTP/1.0 400 Bad Request
```

El `400 Bad Request` es **correcto**: estás hablando HTTP plano contra un puerto
que espera TLS. Lo que se está probando es que la conexión llega, no que
autentique. Tres capas verificadas de un golpe: CoreDNS, kube-proxy y la ruta
pod → Service → ClusterIP.

> **Usa `busybox:1.28`, no una versión más reciente.** Las versiones posteriores
> tienen un bug conocido en `nslookup` que hace fallar la resolución de nombres
> cortos dentro de Kubernetes; la documentación oficial fija la imagen a `1.28`
> por ese motivo. Con `busybox:1.36` verás `NXDOMAIN` y creerás que tu DNS está
> roto cuando no lo está. Es una trampa perfecta: el síntoma apunta a CoreDNS y
> la causa está en la imagen de prueba.

## 5. Scheduling real

```bash
kubectl create deploy web --image=nginx --replicas=4
sleep 15
kubectl get pods -o wide
kubectl delete deploy web
```

Las cuatro réplicas deben repartirse entre `w1` y `w2`, **ninguna en `cp1`**.
Esa es la prueba funcional de que el taint hace su trabajo.

## 6. Certificados

```bash
multipass exec cp1 -- sudo kubeadm certs check-expiration
```

```
CERTIFICATE     EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY
apiserver       Aug 31, 2027 19:46 UTC   364d            ca
admin.conf      Aug 31, 2027 19:46 UTC   364d            ca
...
CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME
ca                      Aug 28, 2036 19:46 UTC   9y
etcd-ca                 Aug 28, 2036 19:46 UTC   9y
```

El patrón vale la pena memorizarlo: **certificados hoja a 1 año, CAs a 10 años**
(la columna muestra `9y` porque redondea hacia abajo, igual que muestra `364d`
para un año). La asimetría es intencional: las CA firman, así que viven más.

Los certificados hoja se renuevan solos en cada `kubeadm upgrade`. Si el clúster
nunca se actualiza, alguien tiene que acordarse antes del año con
`kubeadm certs renew`. En un clúster gestionado ese alguien es el proveedor y tú
nunca te enteras.

## Extra: metrics-server

No viene incluido, y sin él `kubectl top` no funciona:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
sleep 60
kubectl top nodes
```

El parche `--kubelet-insecure-tls` hace falta porque los certificados de servicio
del kubelet son autofirmados en una instalación kubeadm por defecto. **Es
aceptable en un laboratorio y no en producción.**

---

# Fase 6 — Preconfigurar el entorno de trabajo

Esta fase no existe en ninguna guía de kubeadm, y es la que más tiempo te va a
ahorrar durante los meses siguientes. **Va antes de los snapshots a propósito**:
si tomas el snapshot primero, cada restauración borra tus alias, tu `.vimrc` y
tus claves SSH, y acabas reconfigurando el entorno veinte veces.

Una aclaración importante de encuadre: en el examen CKA te dan una terminal ya
lista, con un nodo desde el que saltas a los demás sin pedir contraseña. **En tu
laboratorio eso no existe y tienes que construirlo.** Es infraestructura del
entorno, no material de estudio — pero si no lo haces, cada ejercicio empieza
con fricción.

## 6.1 Decidir desde dónde trabajas

Hasta ahora has manejado el clúster desde el anfitrión con `multipass exec`.
Para practicar CKA eso está mal, y conviene cambiarlo ahora: **el examen te sitúa
dentro de un nodo**, no en una máquina externa con `kubeconfig`. Trabaja desde
`cp1` y sal de ahí solo para gestionar las VMs.

```bash
# ▶▶ HOST
multipass shell cp1
```

Dos avisos que verás en el banner de bienvenida de `cp1`, y qué hacer con cada uno:

- **`*** System restart required ***`** — normal tras la instalación. No hace
  falta reiniciar para trabajar; queda pendiente para cuando te convenga.
- **`N updates can be applied immediately`** — **nunca corras `apt upgrade` en un
  nodo del clúster.** Tus paquetes de Kubernetes están en `hold`, pero un
  `apt upgrade` es exactamente el mecanismo por el que una versión se mueve sin
  que lo pidas. Si necesitas instalar algo, siempre explícito:
  `sudo apt-get install <paquete>=<versión>`.

Comprueba también que no tienes un `kubectl` más nuevo escondido en el anfitrión
(un snap, un binario en `/usr/local/bin`). Un `kubectl` dos minors por delante
del clúster produce avisos y comportamientos raros que te harán perder tiempo
buscando un problema inexistente:

```bash
# ▶▶ HOST
which -a kubectl && kubectl version --client
```

## 6.2 Alias y entorno de shell

```bash
# ▶▶ cp1 — ubuntu@cp1
hostname                     # cp1 → adelante

cat >> ~/.bashrc <<'EOF'
# ---- CKA ----
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
alias kn='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods -o wide'
alias kga='kubectl get all -A'
alias kd='kubectl describe'
alias kx='kubectl explain --recursive'
export KUBE_EDITOR=vim
export ETCDCTL_API=3
# ---- end CKA ----
EOF

printf 'set ts=2 sw=2 et ai nu\nsyntax on\n' > ~/.vimrc
echo "export PS1='\[\e[1;31m\]\h\[\e[0m\]:\w\$ '" >> ~/.bashrc
source ~/.bashrc
```

El `PS1` pinta el hostname en rojo en el prompt. Suena cosmético y no lo es: es
la misma defensa que el `hostname` de la convención de arriba, pero permanente.

### Validación

```bash
type __start_kubectl        # debe existir → autocompletado activo
echo $do                     # --dry-run=client -o yaml
k version --client           # el alias responde
```

El prompt debe verse como `cp1:~$` con el hostname coloreado.

### Cómo se usan — ejemplos reales

El `.vimrc` importa tanto como los alias: `et` (espacios en vez de tabs) evita
que YAML pegado en vim se rompa por indentación, y `nu` te da números de línea
para navegar rápido con `:42`.

| Objetivo | Con los alias |
|---|---|
| Pod imperativo | `k run web --image=nginx` |
| Esqueleto YAML de un Pod | `k run web --image=nginx $do > pod.yaml` |
| Deployment con réplicas | `k create deploy api --image=nginx --replicas=3` |
| YAML de un Deployment para editarlo | `k create deploy api --image=nginx $do > d.yaml` |
| Borrado instantáneo | `k delete pod web $now` |
| Cambiar de namespace por defecto | `kn kube-system` |
| Ver pods con nodo e IP | `kgp` |
| Radiografía del clúster | `kga` |
| Diagnosticar un pod | `kd pod web` |
| Buscar un campo sin salir de la terminal | `kx pod.spec.containers.livenessProbe` |

El patrón que resuelve la mitad del examen es siempre el mismo: **genera con
`$do`, edita lo que no se puede hacer imperativamente, aplica.**

```bash
k create deploy api --image=nginx --replicas=3 $do > d.yaml
vim d.yaml          # aquí añades probes, resources, volumes, tolerations
k apply -f d.yaml
```

> **Advertencia honesta sobre los alias.** En el examen **no hay ayudas
> preinstaladas**: si quieres alias, los escribes tú al empezar, contra el reloj.
> Por eso no basta con tenerlos en el laboratorio — hay que practicar
> **escribirlos de memoria**. Conviértelo en un ritual de 2 minutos al inicio de
> cada sesión de estudio: teclea el bloque completo a mano, sin copiar, antes de
> empezar. Si no puedes reproducirlo en dos minutos, en el examen te costará
> más de lo que te ahorra.
>
> Y ten un plan B mental: si los alias fallan o te equivocas, `kubectl` completo
> funciona igual. Nunca dependas de `k` hasta el punto de bloquearte sin él.

## 6.3 SSH sin contraseña de cp1 a los workers

En el examen saltas entre nodos con `ssh <nodo>` y funciona. Aquí hay que
construirlo.

```bash
# ▶▶ cp1
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub          # ← copia esta línea completa
```

Abre una **segunda terminal** en el anfitrión, sin cerrar la de `cp1`:

```bash
# ▶▶ HOST — segunda terminal
for n in w1 w2; do
  multipass exec $n -- bash -c "echo '<PEGA_AQUI_LA_CLAVE_PUBLICA>' >> ~/.ssh/authorized_keys"
done
```

De vuelta en `cp1`, define los atajos:

```bash
# ▶▶ cp1
cat >> ~/.ssh/config <<'EOF'
Host w1
  HostName 10.167.152.24
  User ubuntu
  StrictHostKeyChecking no
Host w2
  HostName 10.167.152.155
  User ubuntu
  StrictHostKeyChecking no
EOF
chmod 600 ~/.ssh/config
```

Sustituye las IPs por las tuyas. `StrictHostKeyChecking no` es aceptable en un
laboratorio desechable que vas a restaurar constantemente; **en producción, no**.

### Validación

```bash
# ▶▶ cp1
ssh w1 hostname && ssh w2 hostname
```

Debe imprimir `w1` y `w2`, sin pedir contraseña y sin preguntar por la huella
del host. A partir de aquí puedes cerrar la segunda terminal del anfitrión y
trabajar siempre desde `cp1`.

Esto no es comodidad: la mitad de las tareas de CKA sobre nodos —parar el
kubelet, mover un manifiesto, mirar logs de containerd, un `drain` seguido de
mantenimiento— requieren estar *dentro* del worker. Sin SSH, cada una empieza
con un rodeo por el anfitrión.

---

# Fase 7 — Snapshots

La fase que convierte esto en un laboratorio en vez de en una instalación.

**Toma el snapshot ahora, después de la Fase 6.** Así cada restauración te
devuelve un clúster limpio *con* tus alias, tu `.vimrc` y tu SSH ya montados.

```bash
multipass stop cp1 w1 w2
for n in cp1 w1 w2; do multipass snapshot $n --name clean-v134; done
multipass start cp1 w1 w2
multipass list --snapshots
```

> **Los nombres de snapshot no admiten puntos.** `clean-1.34` falla con
> `Invalid snapshot name`. Siguen las mismas reglas que los nombres de
> instancia, básicamente las de un hostname. Usa `clean-v134`.

Restaurar:

```bash
multipass stop cp1 w1 w2
for n in cp1 w1 w2; do multipass restore --destructive $n.clean-v134; done
multipass start cp1 w1 w2
kubectl get nodes
```

Cronometra el ciclo completo una vez. En el hardware de referencia son
**3 minutos**. Si en tu caso pasa de cinco, no vas a romper el clúster lo
suficiente como para aprender de él, y merece la pena optimizarlo.

---

# Trampas y errores reales

Un resumen de todo lo que salió mal durante esta instalación, porque es más útil
que la versión donde todo funciona a la primera.

| Síntoma | Causa real | Solución |
|---|---|---|
| `/dev/kvm` no existe pese a ver `svm` en `/proc/cpuinfo` | SVM deshabilitado en la UEFI | `dmesg \| grep -i svm` lo confirma; activar SVM Mode |
| `reboot` denegado por un inhibidor | `unattended-upgrade-shutdown` bloquea por diseño | Verificar que no hay `apt` real corriendo, luego `systemctl reboot -i` |
| `cannot connect to the multipass socket` | `snap restart` retorna antes de que abra el socket | Esperar 10 s y reintentar |
| `nslookup` devuelve NXDOMAIN dentro del clúster | Bug de `nslookup` en busybox > 1.28 | Usar `busybox:1.28` |
| `Invalid snapshot name: "clean-1.34"` | Los nombres de snapshot no admiten puntos | `clean-v134` |
| `Error from server (AlreadyExists)` al reaplicar Calico | `kubectl create` no es idempotente | Es ruido si el recurso ya existía; `kubectl apply` para reaplicar |
| El terminal se queda colgado tras `kubectl get ... -w` | El flag `-w` es un watch permanente | `Ctrl+C`; para verificación puntual, omitir `-w` |
| `couldn't attach to pod, falling back to streaming logs` | Carrera con `-it --rm` y contenedores de un solo comando | Cosmético, la salida se duplica pero es válida |
| El kubelet no arranca tras instalar | Desajuste de cgroup driver entre kubelet y containerd | `SystemdCgroup = true` en `/etc/containerd/config.toml` |
| La versión de Kubernetes cambió sin pedirlo | `apt upgrade` en un nodo | **Nunca `apt upgrade` en un nodo.** Solo `apt-get install <pkg>=<versión>` |
| Avisos raros de `kubectl`, comportamiento inconsistente | Un `kubectl` del anfitrión (snap o `/usr/local/bin`) varios minors por delante del clúster | `which -a kubectl`; trabaja desde `cp1` o alinea versiones |
| Tras restaurar un snapshot se perdieron alias y claves SSH | El snapshot se tomó antes de configurar el entorno | Configurar shell y SSH **antes** del snapshot (Fase 6 → Fase 7) |
| Comando ejecutado en la máquina equivocada | Cuatro terminales abiertas y ningún indicador | `hostname` antes de cada `sudo`; hostname coloreado en el `PS1` |

---

# Gestionado vs vanilla — el resumen

| Comportamiento | Clúster gestionado (EKS/GKE/AKS) | kubeadm |
|---|---|---|
| Componentes del plano de control | En una cuenta del proveedor, invisibles | Static Pods en `/etc/kubernetes/manifests/` |
| `kubectl get nodes` | Solo workers | Incluye el nodo de plano de control, con su taint |
| CNI | Preinstalado; el nodo nace `Ready` | **Nada viene incluido.** `NotReady` hasta que instalas uno |
| Acceso a etcd | Ninguno; el proveedor hace backups | `etcdctl` en el nodo. **El backup es tuyo** |
| PKI | Invisible | Tres CAs, tuyas para renovar. Certificados a 1 año |
| Identidad | Un principal IAM mapeado a usuario/grupo | El CN y O de un certificado x509 |
| Instalación | Terraform / consola / CLI del proveedor | `kubeadm init` + `join` + CNI a mano |
| Actualización | Una llamada a la API | `kubeadm upgrade plan/apply` + `drain`/`uncordon` |
| `type: LoadBalancer` | Aparece un balanceador solo | `<pending>` para siempre; no hay cloud-controller-manager |
| `kubectl top` | Suele venir listo | Instalas metrics-server tú |

La regla que lo resume: **cada punto donde el proveedor hace algo
automáticamente es un punto donde tienes que saber qué está pasando de verdad.**

---

# Qué hacer con el clúster ahora

Con el snapshot tomado, el clúster es desechable. Eso habilita el único tipo de
práctica que sirve para un examen práctico: romper cosas a propósito y
arreglarlas contra el reloj.

Un patrón que funciona bien es un pequeño arnés de scripts, cada uno con cuatro
piezas: `romper`, `verificar`, `arreglar` y un array de pistas escalonadas.

```bash
#!/usr/bin/env bash
# breaks/01-scheduler-down.sh
TITLE="Los Pods nuevos se quedan Pending"
TARGET_MIN=6

do_break() { multipass exec cp1 -- sudo mv /etc/kubernetes/manifests/kube-scheduler.yaml /root/; }
do_fix()   { multipass exec cp1 -- sudo mv /root/kube-scheduler.yaml /etc/kubernetes/manifests/; }
do_verify() {
  kubectl run chk --image=nginx --restart=Never >/dev/null 2>&1
  sleep 20
  [ -n "$(kubectl get pod chk -o jsonpath='{.spec.nodeName}')" ]
}
HINTS=(
  "Crea un Pod. ¿Llega a tener nodo asignado?"
  "kubectl describe pod — ¿hay eventos, o no hay NINGUNO?"
  "Sin FailedScheduling, nadie lo miró. ¿Quién debía mirarlo y dónde vive?"
)
```

Dos decisiones de diseño que importan:

**Las herramientas viven en el anfitrión, no dentro de los nodos.** Si rompes el
kubelet o containerd en el nodo donde vive tu tooling, pierdes las dos cosas a
la vez. Desde el anfitrión tienes `kubectl` y `multipass exec` a los tres nodos:
suficiente para romper y para verificar.

**Las pistas salen de un array pre-escrito, no de un asistente.** Un modelo de
lenguaje al que le pides "no me ayudes hasta que lo intente" acaba cediendo
siempre. Un array es determinista y honesto. Si quieres consultar a alguien,
hazlo describiendo síntomas — que es exactamente lo que harás en un incidente
real.

Las roturas de mayor valor son las que un entorno de práctica online no te deja
tocar: static Pods, etcd, certificados, kubelet, CNI y actualizaciones. Es
decir, precisamente el plano de control que un clúster gestionado te esconde.
