# tahiry-cloud-onprem

Lab on-prem monté dans VMware Workstation : firewall pfSense, trois VLANs 802.1Q
et un cluster k3s single-node (`one-prime`) qui a hébergé mon portfolio. Une fois le
lab terminé et exposé, j'ai migré le workload vers un VPS public, automatisé avec Ansible.

> **EN:** On-prem lab on VMware Workstation: pfSense firewall, three 802.1Q VLANs
> and a single-node k3s cluster (`one-prime`) that hosted my portfolio. Once the lab was
> complete and exposed, I migrated the workload to a public VPS with Ansible.
> Decommissioned, kept as a reference. See "Sécurité" and "Limites connues".

## Historique

| Période | Étape |
|---|---|
| Septembre 2026 | Réseau : pfSense, trunk 802.1Q, VLANs 10/20/30 |
| Septembre 2026 | Cluster k3s `one-prime` sur vm-containers ; portfolio déployé en `staging` et `prod` |
| Environ un mois | Portfolio exposé depuis `one-prime`, via un tunnel WireGuard vers un edge public (VPS1 : Traefik + WireGuard, derrière Cloudflare) |
| Octobre 2026 | Lab terminé côté `one-prime` : migration vers vps2 avec Ansible, bascule de l'edge, site validé pendant 48 h, puis extinction de `vm-containers` |

## Architecture

### Le lab on-prem

```
Internet
   │  WAN (VMnet3, NAT)
┌──┴──────┐
│ pfSense │── LAN management (VMnet4, host-only) : interface d'administration
└──┬──────┘
   │  trunk 802.1Q (VMnet5, host-only)
   ├─────────────────┬──────────────────┐
 VLAN 10           VLAN 20            VLAN 30
 vm-automation     vm-containers      vm-monitoring
 10.0.10.10        10.0.20.10         10.0.30.10
 contrôleur        k3s "one-prime"    prévue, non terminée
 Ansible
```

### Exposition, avant et après la migration

```
Phase 1 : exposition depuis one-prime

  Internet → Cloudflare → VPS1 (edge : Traefik + WireGuard)
                               │  WireGuard 10.10.0.0/24
                               ▼
                         pfSense (spoke) → VLAN 20 → one-prime (k3s)


Phase 2 : après la migration Ansible

  Internet → Cloudflare → VPS1 (edge : Traefik + WireGuard)
                               │  WireGuard 10.10.0.0/24
                               ▼
                         vps2 (k3s, 10.10.0.2)

  vm-automation (Ansible) ── SSH via WireGuard ──► vps2
```

## Pourquoi migrer : limites de one-prime

- **Single-node** : pas de haute disponibilité, un seul nœud k3s.
- **Hébergé dans une VM VMware Workstation** sur un poste de travail : la disponibilité du site dépend de ce poste.
- **Exposition indirecte** : le site n'était joignable que par la chaîne Cloudflare, VPS1, tunnel WireGuard, pfSense, one-prime. Une coupure sur un maillon rendait le portfolio indisponible.
- **Pas de supervision** : `vm-monitoring` n'a jamais été terminée.

Le lab a rempli son rôle d'apprentissage : réseau segmenté, cluster, déploiement.
La migration a ensuite été automatisée plutôt que refaite à la main.

## Stack

| Couche | Outils |
|---|---|
| Virtualisation | VMware Workstation Pro, Debian 13 |
| Réseau | pfSense, VLANs 10/20/30 (802.1Q), WireGuard |
| Orchestration | k3s v1.36.4 (containerd), Traefik |
| Déploiement | Kustomize (base + overlays prod/staging) |
| Automatisation | Ansible (rôles, templates Jinja2), Ansible Vault |
| Validation | yamllint, ansible-lint, shellcheck, gitleaks |

## Contenu

```
network/       pfSense et VLANs
k3s/           installation du cluster one-prime
kubernetes/    manifests du portfolio et socle de sécurité des namespaces
ansible/       rôles et playbooks de migration vers vps2
scripts/       export et validation
```

## Déploiement du portfolio

Application Astro statique, image Docker privée sur GHCR, déployée dans deux
namespaces (`prod` et `staging`) avec Kustomize. Détails : `kubernetes/README.md`.

## Migration vers vps2

Trois rôles Ansible complémentaires, relançables à volonté :

- **`k3s`** — installation de k3s single-node sur `vps2`.
- **`kubernetes`** — socle Kubernetes via Kustomize : Namespace + labels PSA,
  ResourceQuota, LimitRange, RBAC, NetworkPolicies. Ce socle reprend la
  configuration de sécurité construite et validée sur `one-prime`.
- **`portfolio`** — workload applicatif : Secret GHCR, Deployment, Service,
  Ingress.

Le playbook `02-deploy-portfolio.yml` applique `kubernetes` puis `portfolio`.
Aucune ressource n'est déployée deux fois. Secrets chiffrés par Ansible Vault.
Détails : `ansible/README.md`.

## Sécurité

| Mesure | Où |
|---|---|
| NetworkPolicies : `default-deny-all` (Ingress et Egress), puis `allow-traefik-ingress` et `allow-dns-egress`. Actives sur one-prime, reprises sur vps2 par Ansible | `kubernetes/namespaces/base/networkpolicies.yaml` |
| ResourceQuota `compute-quota` et LimitRange `default-limits`. Actifs sur one-prime, repris sur vps2 par Ansible | `kubernetes/namespaces/base/` |
| RBAC dédié (ServiceAccount `deployer`, Role, RoleBinding) | `kubernetes/namespaces/base/rbac.yaml` |
| Labels Pod Security Admission `restricted` (enforce, warn, audit) sur les namespaces | `kubernetes/namespaces/overlays/*/namespace.yaml` |
| Pod : token ServiceAccount non monté, limites CPU/mémoire | `kubernetes/base/deployment.yaml` |
| Conteneur non-root, `readOnlyRootFilesystem`, `capabilities: drop [ALL]`, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault` (déploiement Ansible sur vps2) | `ansible/roles/portfolio/templates/all.yml.j2` |
| Secrets chiffrés avec Ansible Vault ; fichier réel gitignoré | `ansible/group_vars/` |
| Token GHCR masqué dans les logs (`no_log`), manifests temporaires en `0600`, supprimés même en cas d'échec | `ansible/roles/portfolio/tasks/main.yml` |
| Kubeconfig récupéré localement (mode `644` côté serveur) | `ansible/roles/k3s/tasks/main.yml` |
| SSH : clé ed25519 dédiée ; `host_key_checking = Tue` dans la configuration Ansible (adapté au lab) | `ansible/ansible.cfg` |
| Version de k3s épinglée | `ansible/roles/k3s/defaults/main.yml` |
| Aucun Secret versionné ; export du cluster sans les Secrets | `scripts/export-k8s.sh` |

## Limites connues

- **Règles pfSense inter-VLAN permissives** (lab). Le durcissement prévu est détaillé dans `network/pfsense.md`.
- **Installation de k3s via le script officiel** : version épinglée, mais script non vérifié par checksum.
- **API Kubernetes (6443)** : à restreindre au tunnel WireGuard par le pare-feu de l'hôte (voir `ansible/README.md`).

## Retours d'expérience

- **802.1Q avec VMware Workstation :** tous les VLANs circulent sur le même câble virtuel, sans filtrage par port. Chaque VM doit tagger elle-même son trafic, sinon pfSense l'ignore.
- **Firewall du prestataire + WireGuard :** le firewall réseau fourni par l'hébergeur du VPS, placé devant le serveur, peut casser un tunnel WireGuard alors que les règles semblent correctes. Un firewall par serveur, géré sur l'hôte.
- **Firewall du prestataire ≠ iptables :** le suivi d'état des connexions ne se comporte pas pareil des deux côtés. Deux heures de debug pour le comprendre.
- **k3s single-node :** léger, avec `local-path-provisioner` qui suffit pour une application stateless.
- **Ansible :** `.vault_pass` en `chmod 600` et jamais commité. Les rôles permettent de rejouer sur un autre serveur sans rien réécrire. `kubectl wait` remplace les `sleep`.
- **Secrets :** un `.gitignore` ne suffit pas, il faut un scanner (gitleaks) qui le vérifie.

## Statut

⚠️ Lab décommissionné : `vm-containers` est éteint. Dépôt conservé comme référence.
La version active de l'infrastructure est dans `tahiry-cloud-platform`.

## Licence

MIT


> **Note** : la migration initiale de vps2 avait déployé uniquement le workload
> (rôle `portfolio`). Le socle Kubernetes complet a ensuite été appliqué via le
> rôle `kubernetes` pour aligner vps2 sur la configuration de one-prime :
> ResourceQuota, LimitRange, RBAC, NetworkPolicies et Pod Security Admission.
