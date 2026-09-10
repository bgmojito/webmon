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

