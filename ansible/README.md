# Ansible

Automatisation du déploiement de l'environnement Kubernetes sur `vps2`.

## Structure

```text
ansible/
├── ansible.cfg
├── inventory.ini
├── group_vars/
│   └── vps2.yml.example
├── playbooks/
│   ├── 01-install-k3s-vps2.yml
│   ├── 02-deploy-portfolio.yml
│   └── 03-verify.yml
└── roles/
    ├── k3s/
    ├── kubernetes/
    └── portfolio/
```

## Playbooks

### `01-install-k3s-vps2.yml`

Installe k3s single-node sur `vps2`.

Le rôle `k3s` configure notamment :

* k3s `v1.36.4+k3s1`
* modules kernel nécessaires
* paramètres sysctl
* désactivation du swap
* kubeconfig pour l'administration du cluster

### `02-deploy-portfolio.yml`

Déploie l'environnement Kubernetes sur `vps2` avec deux rôles complémentaires :

```yaml
roles:
  - kubernetes
  - portfolio
```

L'ordre d'exécution est volontaire :

1. `kubernetes` prépare le socle Kubernetes.
2. `portfolio` déploie le workload applicatif dans les namespaces préparés.

### `03-verify.yml`

Effectue les vérifications de l'environnement après déploiement :

* nœud k3s
* pods
* Ingress
* réponse HTTP du site `prod`
* réponse HTTP du site `staging`

## Rôles Ansible

Le dépôt contient trois rôles complémentaires, utilisés par les playbooks selon l'étape du déploiement.

| Rôle         | Ce qu'il déploie                                                                                                                                                                                                                                             | Appelé par                          |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------- |
| `k3s`        | Installation de k3s single-node sur la cible                                                                                                                                                                                                                 | `playbooks/01-install-k3s-vps2.yml` |
| `kubernetes` | Socle Kubernetes via Kustomize : Namespace + labels Pod Security Admission (`restricted`), ResourceQuota, LimitRange, RBAC (ServiceAccount `deployer`, Role, RoleBinding), NetworkPolicies (`default-deny-all`, `allow-traefik-ingress`, `allow-dns-egress`) | `playbooks/02-deploy-portfolio.yml` |
| `portfolio`  | Workload applicatif : Secret GHCR (`ghcr-pull`), Deployment, Service, Ingress                                                                                                                                                                                | `playbooks/02-deploy-portfolio.yml` |

## Ordre d'application

Le playbook `02-deploy-portfolio.yml` applique les deux rôles dans cet ordre :

1. **`kubernetes`** — prépare le socle Kubernetes : Namespace, quotas, LimitRange, RBAC, NetworkPolicies et PSA. Le cluster est préparé pour recevoir le workload.
2. **`portfolio`** — déploie l'application dans les namespaces préparés : Secret GHCR, Deployment, Service et Ingress.

Cette séparation permet de distinguer clairement le socle de sécurité du workload applicatif et d'éviter qu'une même ressource soit gérée par les deux rôles.

## Socle Kubernetes

Le rôle `kubernetes` applique les Kustomizations présentes dans :

```text
../kubernetes/namespaces/
```

Il applique :

```text
kubernetes/namespaces/overlays/prod
kubernetes/namespaces/overlays/staging
```

Ces overlays fournissent notamment :

* Namespace
* labels d'environnement
* Pod Security Admission (`restricted`)
* ResourceQuota
* LimitRange
* ServiceAccount
* Role
* RoleBinding
* NetworkPolicies

Le rôle `kubernetes` ne déploie pas le workload applicatif.

Les overlays suivants :

```text
kubernetes/overlays/prod
kubernetes/overlays/staging
```

contiennent le Deployment, le Service et l'Ingress du portfolio. Ils sont conservés dans le dépôt comme représentation déclarative du déploiement Kubernetes de `one-prime`, mais ne sont pas utilisés par le rôle `kubernetes`.

Le workload est déployé par le rôle `portfolio` à partir de son template Jinja2.

## Contexte du projet

Le répertoire `kubernetes/` conserve le socle et les manifests Kubernetes construits pour le cluster `one-prime`.

Le socle Kubernetes a notamment été utilisé pour mettre en place :

* l'isolation des namespaces `prod` et `staging`
* les quotas de ressources
* les limites par défaut
* le RBAC
* les NetworkPolicies
* Pod Security Admission

Le dépôt a ensuite été constitué pour conserver l'ensemble de cette configuration ainsi que l'automatisation Ansible utilisée pour la migration du workload vers `vps2`.

Le rôle `kubernetes` permet de reproduire le socle sur un cluster vierge, tandis que le rôle `portfolio` permet de déployer le workload applicatif.

## Variables et secrets

Les variables sensibles ne sont pas versionnées.

Le fichier d'exemple :

```text
group_vars/vps2.yml.example
```

présente la structure attendue pour les variables protégées par Ansible Vault.

Les valeurs réelles sont conservées dans un fichier Vault local non versionné.

Variables principales :

```yaml
ansible_password
ansible_become_password
vault_ghcr_token
```

Le token GHCR est utilisé pour créer le Secret Kubernetes :

```text
ghcr-pull
```

Ce Secret n'est pas versionné dans le dépôt.

## Utilisation

Depuis le répertoire `ansible/` :

```bash
ansible-playbook playbooks/01-install-k3s-vps2.yml
```

Puis :

```bash
ansible-playbook playbooks/02-deploy-portfolio.yml
```

Enfin :

```bash
ansible-playbook playbooks/03-verify.yml
```

Le dépôt conserve également les manifests Kubernetes permettant une gestion déclarative du socle et du workload.

---

**État actuel de vps2** : le socle Kubernetes complet est appliqué sur vps2
(ResourceQuota, LimitRange, RBAC, NetworkPolicies, PSA), aligné sur celui construit et validé sur one-prime.
