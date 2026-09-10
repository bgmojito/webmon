-include .env
export

HOST_IP ?= localhost

.PHONY: help start stop restart logs ps build clean status \
        backup restore chaos stress health rebuild test-backup

# === Aide par défaut ===
help:
	@echo ""
	@echo "WebMon - Commandes disponibles :"
	@echo ""
	@echo "  make start         Démarre toute la stack"
	@echo "  make stop          Arrête la stack"
	@echo "  make restart       Redémarre la stack"
	@echo "  make logs          Affiche les logs en temps réel"
	@echo "  make ps            Liste les conteneurs et leur état"
	@echo "  make status        Statut détaillé des services"
	@echo "  make health        Vérifie la santé de chaque endpoint"
	@echo "  make clean         Arrête tout et supprime les volumes"
	@echo "  make build         Rebuild les images"
	@echo "  make rebuild S=X   Rebuild un seul service (ex: make rebuild S=backend)"
	@echo ""
	@echo "  make backup        Sauvegarde Postgres"
	@echo "  make restore       Restaure la dernière sauvegarde"
	@echo "  make test-backup   Teste le cycle backup/restore complet"
	@echo "  make chaos         Tue un conteneur au hasard"
	@echo "  make stress        Génère 30s de charge CPU"
	@echo ""

# === Lifecycle ===
start:
	docker compose up -d --build
	@echo ""
	@echo "✅ Stack démarrée"
	@echo ""
	@echo "🌐 App          : http://$(HOST_IP)"
	@echo "📊 Grafana      : http://localhost:3000 (accès local uniquement, admin/<mot de passe .env>)"
	@echo "📈 Prometheus   : http://localhost:9090 (accès local uniquement)"
	@echo "📦 cAdvisor     : http://localhost:8080 (accès local uniquement)"
	@echo ""

stop:
	docker compose stop

restart: stop start

clean:
	docker compose down -v
	@echo "✅ Stack arrêtée et volumes supprimés"

# === Inspection ===
logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

status:
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

health:
	@echo "🔍 Test des endpoints..."
	@echo -n "  Frontend         : " && (curl -fsS -o /dev/null http://localhost && echo "OK") || echo "FAIL"
	@echo -n "  Backend API      : " && (curl -fsS -o /dev/null http://localhost/api/tasks && echo "OK") || echo "FAIL"
	@echo -n "  Grafana          : " && (curl -fsS -o /dev/null http://localhost:3000/api/health && echo "OK") || echo "FAIL"
	@echo -n "  Prometheus       : " && (curl -fsS -o /dev/null http://localhost:9090/-/healthy && echo "OK") || echo "FAIL"
	@echo -n "  Loki             : " && (curl -fsS -o /dev/null http://localhost:3100/ready && echo "OK") || echo "FAIL"
	@echo -n "  cAdvisor         : " && (curl -fsS -o /dev/null http://localhost:8080/healthz && echo "OK") || echo "FAIL"

build:
	docker compose build

rebuild:
	@if [ -z "$(S)" ]; then echo "Usage: make rebuild S=backend"; exit 1; fi
	docker compose build $(S)
	docker compose up -d $(S)

# === DevOps demos ===
backup:
	@bash scripts/backup.sh

restore:
	@bash scripts/restore.sh

test-backup:
	@bash scripts/test-backup-restore.sh

chaos:
	@bash scripts/chaos.sh

stress:
	@echo "🔥 Génération de charge CPU pendant 30s..."
	docker run --rm -d --name webmon-stress --network webmon_webmon polinux/stress stress --cpu 2 --timeout 30s
	@echo "Observez Grafana : http://localhost:3000 (accès local uniquement)"