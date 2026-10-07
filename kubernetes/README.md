# Manifests Kubernetes

Les manifests Kubernetes du portfolio déployé sur le cluster k3s `one-prime`.

J'ai séparé la configuration en deux parties : d'abord le socle commun des
namespaces (sécurité, quotas et RBAC), puis le workload du portfolio. Cette
organisation permet de réutiliser le même socle pour `staging` et `prod`.

## Structure

```text
kubernetes/
├── namespaces/               socle commun des namespaces
│   ├── base/
│   │   ├── networkpolicies.yaml
│   │   ├── resourcequota.yaml
│   │   ├── limitrange.yaml
│   │   ├── rbac.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── prod/             namespace.yaml + kustomization.yaml
│       └── staging/          namespace.yaml + kustomization.yaml
├── base/                     workload du portfolio
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── prod/                 ingress.yaml + kustomization.yaml
    └── staging/              ingress.yaml + kustomization.yaml
```

## Déploiement

Le déploiement suit volontairement deux étapes : le socle du namespace est
appliqué en premier, puis le workload.

```bash
kubectl apply -k namespaces/overlays/staging
kubectl apply -k overlays/staging

kubectl apply -k namespaces/overlays/prod
kubectl apply -k overlays/prod
```

Cette séparation permet de préparer les contrôles de sécurité avant de lancer
l'application.

Le Secret `ghcr-pull`, utilisé pour récupérer l'image privée depuis GHCR,
n'est pas versionné dans Git. Il est créé séparément dans chacun des namespaces.

## Socle de sécurité

Le dossier `namespaces/` contient les contrôles communs appliqués à `prod`
et `staging` :

* `default-deny-all` bloque par défaut les flux Ingress et Egress.
* `allow-traefik-ingress` autorise uniquement le trafic entrant nécessaire
  depuis Traefik.
* `allow-dns-egress` permet aux pods de résoudre les noms via DNS.
* `ResourceQuota` limite les ressources consommées par le namespace.
* `LimitRange` définit les valeurs par défaut pour les ressources des pods.
* Un ServiceAccount `deployer`, un Role et un RoleBinding assurent le RBAC.
* Les namespaces portent les labels nécessaires à Pod Security Admission
  avec le niveau `restricted`.

Le détail des règles réseau et des ressources est disponible directement dans
les manifests de `namespaces/base/`.

## Sécurité du pod

Le Deployment du portfolio désactive le montage automatique du token du
ServiceAccount et définit les limites CPU/mémoire.

Lors de la migration vers vps2, le rôle Ansible applique également le
durcissement du conteneur :

* exécution en tant qu'utilisateur non-root ;
* système de fichiers racine en lecture seule ;
* suppression de toutes les capabilities Linux ;
* `allowPrivilegeEscalation: false` ;
* profil `seccomp` `RuntimeDefault`.

Le template utilisé pour cette partie se trouve dans :

```text
ansible/roles/portfolio/templates/all.yml.j2
```

## Passage à vps2

Les manifests ont d'abord été utilisés sur `one-prime` pour construire et
valider le déploiement du portfolio.

Lors de la migration, j'ai repris ce fonctionnement avec Ansible afin de ne
pas reconstruire manuellement le cluster. Le rôle
`ansible/roles/kubernetes/` applique le même socle de sécurité sur vps2,
puis `ansible/roles/portfolio/` déploie le workload.

L'objectif est de conserver la même base Kubernetes tout en automatisant
l'installation sur le nouvel environnement.

## Vérification avant commit

Les Secrets réels ne doivent jamais être présents dans le dépôt. Avant un
commit, je vérifie notamment qu'aucun token GHCR, `dockerconfigjson` ou clé
privée n'a été ajouté :

```bash
grep -rniE "dockerconfigjson|ghp_|BEGIN.*PRIVATE" .

```
## Version d'image

Les manifests épinglent `v0.1.0`, version déployée sur `one-prime`.
Le rôle Ansible `portfolio` déploie `v0.2.0` sur `vps2` (mise à jour
appliquée pendant la migration).

```



---

> **État final** : le socle Kubernetes complet (ResourceQuota, LimitRange, RBAC,
> NetworkPolicies, PSA) est appliqué sur vps2 par le rôle `ansible/roles/kubernetes/`.
> Il est aligné sur celui construit et validé sur one-prime.
