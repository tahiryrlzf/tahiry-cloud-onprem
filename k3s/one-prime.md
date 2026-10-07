# k3s one-prime

Cluster single-node installé de zéro sur `vm-containers` (VLAN 20).

## Fiche

| | |
|---|---|
| VM | vm-containers |
| OS | Debian 13 |
| CPU / RAM | 4 vCPU / 7.7 GiB |
| IP | 10.0.20.10/24 (`ens33.20`) |
| Version | v1.36.4+k3s1 |
| Runtime | containerd |
| Ingress | Traefik |

## Installation

Version épinglée, kubeconfig lisible par root uniquement :

```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION=v1.36.4+k3s1 \
  sh -s - server --write-kubeconfig-mode 600
```

## Vérifications

```bash
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
sudo k3s kubectl get svc -n kube-system traefik
```

## Namespaces

- `prod` : Deployment, Service et Ingress du portfolio
- `staging` : même déploiement, avec un autre hôte, pour tester avant `prod`
- `kube-system` : coredns, traefik, metrics-server, local-path-provisioner

Le socle de sécurité de `prod` et `staging` (NetworkPolicies, quota, LimitRange,
RBAC, Pod Security) est décrit dans `kubernetes/README.md`.

## Secret

`ghcr-pull` (type dockerconfigjson) dans `prod` et `staging`, pour récupérer
l'image privée sur GHCR. Il n'est pas versionné.

## Stockage

Aucun PVC : l'application est stateless.

## Suite

Migré vers vps2 en octobre 2026. Voir `ansible/`.
