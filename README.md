# WebMon

> **TP DevOps** — Plateforme web conteneurisée supervisée avec Prometheus, Grafana, Loki et cAdvisor.

## Équipe

- Membre 1 : Lead Infra (Docker Compose, Nginx, Makefile, scripts)
- Membre 2 : Backend & DB (Node.js API + PostgreSQL)
- Membre 3 : Frontend & UX (HTML/CSS/JS)
- Membre 4 : Observability (Prometheus, Grafana, Loki, dashboards)

## Démarrage rapide

```bash
make start
```

Puis :
- App : http://localhost
- Grafana : http://localhost:3000 (admin/admin)
- Prometheus : http://localhost:9090
- cAdvisor : http://localhost:8080

`HOST_IP` (défaut `localhost`) contrôle l'hôte affiché dans les URLs ci-dessus et dans `make chaos` ; à surcharger via variable d'environnement, ex. `HOST_IP=192.168.1.10 make start`.

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

