# VLANs

Trunk 802.1Q entre pfSense (`vmx2`) et les VMs. Chaque VM tagge son trafic
(VMware Workstation ne filtre pas les VLANs sur un vNIC).

| VLAN | Nom | Subnet | VM | IP |
|---|---|---|---|---|
| 10 | Automation | 10.0.10.0/24 | vm-automation | 10.0.10.10 |
| 20 | Containers | 10.0.20.0/24 | vm-containers | 10.0.20.10 |
| 30 | Monitoring | 10.0.30.0/24 | vm-monitoring | 10.0.30.10 |
| — | Management | 192.168.220.0/24 | pfSense GUI | 192.168.220.254 |

## Configuration Debian

Chaque VM utilise une interface VLAN sur son interface réseau principale.

### vm-automation — VLAN 10

```text
auto lo
iface lo inet loopback

auto ens160
iface ens160 inet manual

auto ens160.10
iface ens160.10 inet static
    address 10.0.10.10/24
    gateway 10.0.10.254
    dns-nameservers 10.0.10.254
    dns-search devsecops.home.arpa
```

### vm-containers — VLAN 20

```text
auto lo
iface lo inet loopback

auto ens33
iface ens33 inet manual

auto ens33.20
iface ens33.20 inet static
    address 10.0.20.10/24
    gateway 10.0.20.254
    dns-nameservers 10.0.20.254
    dns-search devsecops.home.arpa
```

### vm-monitoring — VLAN 30

```text
auto lo
iface lo inet loopback

auto ens160
iface ens160 inet manual

auto ens160.30
iface ens160.30 inet static
    address 10.0.30.10/24
    gateway 10.0.30.254
    dns-nameservers 10.0.30.254
    dns-search devsecops.home.arpa
```

## Module noyau

Le module `8021q` est chargé pour permettre la création des interfaces VLAN :

```bash
echo "8021q" | sudo tee -a /etc/modules
```

## Vérifications

Après la configuration réseau, je vérifie la présence de l'interface VLAN,
son adresse IP et sa connectivité avec pfSense :

```bash
ip -br addr show
ip -d link show ens33.20
ping -c 2 10.0.20.254
```

## Accès SSH depuis Windows

Le poste Windows reste connecté uniquement au LAN de management
(`VMnet4`, `192.168.220.0/24`). Pour accéder aux VMs des VLANs 10, 20 et 30,
j'ai ajouté des routes statiques vers pfSense, qui assure ensuite le routage
entre le LAN de management et les VLANs. Le trafic est routé, sans NAT.

### Routes statiques Windows

Les routes sont ajoutées depuis PowerShell lancé en administrateur :

```powershell
route add 10.0.10.0 mask 255.255.255.0 192.168.220.254 -p
route add 10.0.20.0 mask 255.255.255.0 192.168.220.254 -p
route add 10.0.30.0 mask 255.255.255.0 192.168.220.254 -p
```

L'option `-p` conserve les routes après un redémarrage. Vérification :

```powershell
route print -4
```

### Flux réseau

```text
Windows (192.168.220.1)
   │
   │ routes statiques vers les VLANs
   ▼
pfSense LAN (192.168.220.254)
   ├─▶ vmx2.10 → vm-automation  (10.0.10.10:22)
   ├─▶ vmx2.20 → vm-containers  (10.0.20.10:22)
   └─▶ vmx2.30 → vm-monitoring  (10.0.30.10:22)
```

### Configuration SSH sur les VMs

J'ai installé et activé le serveur SSH sur les VMs pour les administrer
depuis le poste Windows :

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
ss -tlnp | grep :22
```

L'accès SSH se fait depuis le LAN de management (`192.168.220.0/24`).

### Tests depuis Windows

Je vérifie d'abord la connectivité avec `ping`, puis l'accès SSH :

```powershell
ping 10.0.10.10
ssh utilisateur@10.0.10.10
```

Le même principe s'applique aux VMs des VLANs 20 et 30.

