# pfSense

Firewall du lab. 3 interfaces VMware.

| Interface | VMnet | Rôle | IP |
|---|---|---|---|
| WAN | VMnet3 (NAT) | Internet | 192.168.101.200/24 |
| LAN | VMnet4 (Host-only) | Management | 192.168.220.254/24 |
| Trunk | VMnet5 (Host-only) | VLANs | — |

## VLANs sur l'interface trunk (`vmx2`)

| VLAN | Interface pfSense | Subnet | IP pfSense |
|---|---|---|---|
| 10 | vmx2.10 (OPT1) | 10.0.10.0/24 | 10.0.10.254 |
| 20 | vmx2.20 (OPT2) | 10.0.20.0/24 | 10.0.20.254 |
| 30 | vmx2.30 (OPT3) | 10.0.30.0/24 | 10.0.30.254 |

DHCP actif sur chaque VLAN : `.100` à `.200`.

## Identification

- Hostname : `pfsense-ds01`
- Domaine : `devsecops.home.arpa`
- DNS : 8.8.8.8, 1.1.1.1
- NTP : pool.ntp.org
- GUI : `https://192.168.220.254`, depuis le poste Windows via le LAN management

## Règles firewall

État actuel : sur chaque VLAN, source = subnet → destination = any → **Pass**.

⚠️ **Limite assumée (lab) :** ces règles permettent le trafic inter-VLAN.
Ce choix a simplifié le debug pendant la construction du lab.

Durcissement prévu en production :

| Source | Destination | Action |
|---|---|---|
| VLAN 10 (Automation) | VLAN 20, 30 sur SSH (22) | Pass |
| VLAN 30 (Monitoring) | VLAN 20 sur les ports d'exporters | Pass |
| VLAN 20 (Containers) | VLAN 10, 30 | Block |
| Tous VLANs | Autres VLANs | Block (règle par défaut, en dernier) |
| Tous VLANs | Internet | Pass |

## WireGuard

pfSense est un spoke du hub VPS1.

| | |
|---|---|
| Réseau | 10.10.0.0/24 |
| Hub (VPS1) | 10.10.0.1 |
| pfSense | 10.10.0.5 |

Les clés privées WireGuard ne sont jamais versionnées.
