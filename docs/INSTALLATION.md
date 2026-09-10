# Installation

## Prérequis

- **Docker Engine** récent (Docker Desktop sur Windows/macOS, ou Docker Engine natif sur Linux).
- **Docker Compose v2**, c'est-à-dire la sous-commande intégrée `docker compose` (et non le binaire historique `docker-compose` en v1). Toutes les commandes du Makefile et de `scripts/webmon.ps1` utilisent la syntaxe v2.
- Sous Windows, PowerShell 5.1+ (ou PowerShell 7) pour exécuter `scripts/webmon.ps1`. Sous Linux/macOS, `make` et `bash`.
- Accès au socket Docker (`/var/run/docker.sock`) : requis par `cadvisor` et `promtail` pour observer les autres conteneurs.

### Ressources minimales

La stack démarre 13 conteneurs (application + supervision). À titre indicatif :

| Ressource | Minimum | Recommandé |
|---|---|---|
| CPU | 2 cœurs | 4 cœurs |
| RAM | 3 Go disponibles pour Docker | 4 Go ou plus |
| Disque | 5 Go libres (images + volumes) | 10 Go |

Ces chiffres n'incluent pas la charge générée volontairement par `make stress` / `.\scripts\webmon.ps1 stress` (test de charge CPU).

## Procédure de démarrage

1. **Cloner le dépôt puis se placer dedans :**
   ```bash
   git clone <url-du-depot>
   cd webmon
   ```

2. **Vérifier les ports libres** (voir tableau ci-dessous) : `80`, `3000`, `9090`, `9093`, `3100`, `8080`, `9100`, `9187`.

3. **Démarrer la stack :**
   - Linux/macOS :
     ```bash
     make start
     ```
   - Windows :
     ```powershell
     .\scripts\webmon.ps1 start
     ```
   Cette commande build les images applicatives (`backend`, `frontend`, `nginx`) puis lance l'ensemble des conteneurs en arrière-plan.

4. **Attendre que tout soit prêt.** Le conteneur `backend` attend que `postgres` soit `healthy` avant de démarrer ; les autres services démarrent en parallèle. Vérifier l'état :
   - Linux/macOS : `make status` puis `make health`
   - Windows : `.\scripts\webmon.ps1 status` puis `.\scripts\webmon.ps1 health`

5. **Accéder aux services** (voir [README.md](../README.md) pour les URLs et identifiants).

6. **Arrêter la stack** quand vous avez terminé :
   - Linux/macOS : `make stop` (conserve les données) ou `make clean` (supprime aussi les volumes, donc les données Postgres/Grafana/Prometheus/Loki)
   - Windows : `.\scripts\webmon.ps1 stop` ou `.\scripts\webmon.ps1 clean`

## Ports exposés

Seul `nginx` (port `80`) est publié sans restriction d'interface (`"80:80"`, équivalent à `0.0.0.0:80`) : c'est le seul service pensé pour être exposé à des utilisateurs finaux. Tous les ports de supervision ci-dessous sont publiés en `127.0.0.1:<port>:<port>` dans `docker-compose.yml`, donc joignables uniquement depuis la machine hôte elle-même, pas depuis l'extérieur — voir [Modèle de menace](../README.md#modèle-de-menace) dans le README pour le raisonnement derrière ce choix.

| Port hôte | Service | Rôle | Accessibilité prévue |
|---|---|---|---|
| `80` | `nginx` | Point d'entrée de l'application (reverse proxy vers `frontend` et `backend`) | Publique (`0.0.0.0`) — c'est le seul service pensé pour être exposé à des utilisateurs finaux |
| `3000` | `grafana` | Dashboards de supervision (identifiants par défaut `admin`/`admin`) | Locale (`127.0.0.1`) / admin |
| `9090` | `prometheus` | Interface et API Prometheus (métriques, requêtes PromQL) | Locale (`127.0.0.1`) / admin — pas d'authentification |
| `9093` | `alertmanager` | Interface et API Alertmanager (alertes actives, silences) | Locale (`127.0.0.1`) / admin — pas d'authentification |
| `3100` | `loki` | API de requête des logs (consommée par Grafana) | Locale (`127.0.0.1`) / admin — pas d'authentification |
| `8080` | `cadvisor` | Métriques et introspection des conteneurs (tourne en `privileged: true`) | Locale (`127.0.0.1`) / admin — sensible, pas d'authentification |
| `9100` | `node-exporter` | Métriques système de l'hôte (CPU, RAM, disque) | Locale (`127.0.0.1`) / admin — pas d'authentification |
| `9187` | `postgres-exporter` | Métriques Postgres pour Prometheus | Locale (`127.0.0.1`) / admin — pas d'authentification |

Les services `postgres`, `backend`, `frontend`, `promtail` et `docker-socket-proxy` ne publient aucun port sur l'hôte : ils ne sont joignables que depuis le réseau Docker interne (`webmon`).

## Dépannage

**Port déjà utilisé (`Bind for 0.0.0.0:XXXX failed`)**
Un autre processus occupe déjà un des ports du tableau ci-dessus (souvent `80`, `3000` ou `9090`). Libérez le port ou adaptez le mapping dans `docker-compose.yml`.

**Le `backend` ne démarre jamais / reste en attente**
`backend` dépend de `postgres:service_healthy`. Vérifiez l'état du healthcheck :
```bash
docker compose ps postgres
docker compose logs postgres
```
Le healthcheck peut prendre quelques secondes après un premier démarrage (initialisation de la base).

**`cadvisor` ou `promtail` ne démarrent pas / erreurs de permission sur le socket Docker**
Ces deux services montent `/var/run/docker.sock`. Sur Linux, assurez-vous que l'utilisateur qui lance `docker compose` a les droits sur ce socket (groupe `docker`). Sur certains environnements Docker rootless ou fortement restreints, `cadvisor` (qui requiert `privileged: true`) peut échouer à démarrer — c'est un environnement non supporté par cette stack de démonstration.

**`make health` / `.\scripts\webmon.ps1 health` affiche des `FAIL`**
La commande teste des endpoints HTTP en local (`localhost`). C'est normal juste après `start` : laissez quelques secondes aux conteneurs pour finir leur initialisation, puis relancez `health`. Si un service reste en échec, consultez ses logs (`docker compose logs <service>`).

**`make backup` échoue avec « Le conteneur postgres ne tourne pas »**
Démarrez la stack (`make start`) avant de lancer une sauvegarde ou une restauration : `scripts/backup.sh` et `scripts/restore.sh` exigent que `postgres` réponde à `pg_isready`.

**Premier `make start` / `.\scripts\webmon.ps1 start` très long**
Le premier lancement construit les images `backend`, `frontend` et `nginx` et télécharge les images tierces (Postgres, Prometheus, Grafana, Loki, Promtail, cAdvisor, node-exporter, postgres-exporter). Les démarrages suivants réutilisent le cache Docker et sont nettement plus rapides.

**Les données ont disparu après une commande**
`make clean` / `.\scripts\webmon.ps1 clean` supprime volontairement les volumes Docker (`postgres-data`, `prometheus-data`, `alertmanager-data`, `grafana-data`, `loki-data`). C'est le comportement attendu de `clean` ; utilisez `stop` si vous souhaitez seulement arrêter les conteneurs sans perdre les données.
