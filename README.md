# WebMon

> **TP DevOps** — Plateforme web conteneurisée supervisée avec Prometheus, Grafana, Loki et cAdvisor.

## Équipe

- Membre 1 : Lead Infra (Docker Compose, Nginx, Makefile, scripts)
- Membre 2 : Backend & DB (Node.js API + PostgreSQL)
- Membre 3 : Frontend & UX (HTML/CSS/JS)
- Membre 4 : Observability (Prometheus, Grafana, Loki, dashboards)

## Démarrage rapide

```bash
cp .env.example .env
make start
```

Puis :
- App : http://localhost
- Grafana : http://localhost:3000 (admin/admin)
- Prometheus : http://localhost:9090
- cAdvisor : http://localhost:8080
- Alertmanager : http://localhost:9093 (accessible uniquement en local, 127.0.0.1)

## Alerting

La stack ne se contente plus de collecter et d'afficher des métriques : Prometheus évalue
des règles d'alerte en continu et les transmet à Alertmanager dès qu'elles passent à l'état
`firing`.

### Règles en place

Définies dans [`prometheus/rules/alerts.yml`](prometheus/rules/alerts.yml), chargées par
Prometheus via `rule_files:` dans `prometheus.yml` :

| Alerte | Condition | Sévérité |
|---|---|---|
| `ServiceDown` | Une cible scrapée (`up == 0`) ne répond plus depuis plus de 2 minutes | critical |
| `ContainerRestartLoop` | Un conteneur redémarre plus de 2 fois en 15 minutes (`changes(container_start_time_seconds[15m])`) | warning |
| `HighDiskUsage` | Espace disque disponible sous 15 % sur un point de montage | warning |
| `HighMemoryUsage` | Mémoire d'un conteneur au-dessus de 85 % de sa limite pendant plus de 5 minutes | warning |

Chaque alerte porte un label `severity` et des annotations `summary` / `description` qui
incluent le nom de l'instance/du conteneur concerné, pour être immédiatement lisibles dans
Prometheus et Alertmanager.

> `HighMemoryUsage` se base sur `container_spec_memory_limit_bytes` (exposé par cAdvisor) :
> elle ne se déclenchera que pour les conteneurs auxquels une limite mémoire (`mem_limit` /
> `deploy.resources.limits.memory`) a été fixée, sinon le ratio reste proche de 0.

### Alertmanager

Le service `alertmanager` (voir `docker-compose.yml`) lit
[`alertmanager/alertmanager.yml`](alertmanager/alertmanager.yml) et route toutes les
alertes vers un receiver webhook local (`webhook-local`), sans aucun identifiant réel —
à remplacer par un vrai receiver (Slack, email, PagerDuty...) en production. Comme les
autres ports de supervision, il n'est exposé que sur `127.0.0.1:9093`.

Prometheus est relié à Alertmanager via la section `alerting:` de `prometheus.yml`.

### Tester les alertes

1. Démarrer la stack (`make start`) puis ouvrir http://localhost:9090/rules : les 4 règles
   doivent apparaître avec l'état `ok` (pas d'erreur de chargement).
2. Arrêter un conteneur non critique pour simuler une panne, par exemple :
   ```bash
   docker stop webmon-cadvisor
   ```
3. Sur http://localhost:9090/alerts, l'alerte `ServiceDown` passe d'abord à l'état
   **Pending** (dès que `up == 0`), puis à **Firing** après 2 minutes (le temps défini par
   `for:` dans la règle).
4. Une fois à l'état Firing, l'alerte apparaît dans Alertmanager : http://localhost:9093
   (onglet "Alerts"), avec ses labels (`severity`, `job`, `instance`) et ses annotations.
5. Relancer le conteneur (`docker start webmon-cadvisor`) : l'alerte repasse à `inactive`
   côté Prometheus et se résout côté Alertmanager.

Pour tester `ContainerRestartLoop`, utiliser `make chaos` (ou `scripts/chaos.sh`) plusieurs
fois de suite en moins de 15 minutes sur un même conteneur applicatif : cAdvisor détecte les
changements de `container_start_time_seconds` et l'alerte se déclenche une fois le seuil de
redémarrages dépassé.

`HOST_IP` (défaut `localhost`) contrôle l'hôte affiché dans les URLs ci-dessus et dans `make chaos` ; à surcharger via variable d'environnement, ex. `HOST_IP=192.168.1.10 make start`, ou en la définissant dans `.env` (voir plus bas — le Makefile charge automatiquement `.env` s'il existe).

## Secrets et configuration

Les identifiants sensibles (`POSTGRES_PASSWORD`, `GF_SECURITY_ADMIN_PASSWORD`,
`DATA_SOURCE_NAME`) ne sont plus écrits en dur dans `docker-compose.yml`.
Ils sont lus depuis un fichier `.env` local, non commité (voir
`.gitignore`). Ce même fichier `.env` peut aussi porter `HOST_IP` (voir
ci-dessus), pour garder un seul point de configuration.

Procédure :

1. Copier le fichier d'exemple : `cp .env.example .env`
2. Adapter les valeurs si besoin (mot de passe PostgreSQL, mot de passe
   admin Grafana, chaîne de connexion `DATA_SOURCE_NAME` — elle doit
   rester cohérente avec `POSTGRES_PASSWORD` — et éventuellement
   `HOST_IP`)
3. Démarrer la stack normalement (`make start` ou
   `docker compose up -d`) : Docker Compose charge automatiquement
   `.env` à la racine du projet, et le Makefile fait de même pour
   `HOST_IP`

`.env.example` contient des valeurs de démo fonctionnelles : la stack
démarre en une seule commande sans configuration supplémentaire. Ne
committez jamais votre `.env` local.

## Exposition réseau

Seuls `nginx` (port 80) et l'application sont exposés sur toutes les
interfaces. Les services de supervision (Prometheus, Grafana, Loki,
cAdvisor, node-exporter, postgres-exporter) ne publient leurs ports que
sur `127.0.0.1`, donc uniquement accessibles depuis la machine hôte
elle-même. La communication inter-conteneurs (scraping Prometheus,
etc.) continue de passer par le réseau Docker interne `webmon` via les
noms de service.

## Documentation

Voir [docs/INSTALLATION.md](docs/INSTALLATION.md) pour l''installation complète.

## Commandes disponibles

| Commande | Action |
|---|---|
| `make start` | Démarre toute la stack |
| `make stop` | Arrête la stack |
| `make restart` | Redémarre |
| `make logs` | Affiche les logs en temps réel |
| `make ps` | Liste les conteneurs |
| `make clean` | Arrête et supprime les volumes |
| `make backup` | Sauvegarde la base Postgres |
| `make restore` | Restaure la dernière sauvegarde |
| `make chaos` | Tue un conteneur au hasard (test résilience) |


## Commandes disponibles pour webmon.ps1

| Commande | Action |
|---|---|
| `.\scripts\webmon.ps1 start` | Démarre le script |
| `.\scripts\webmon.ps1 chaos` | Arrête un conteneur hasard |
| `.\scripts\webmon.ps1 health` | état|

