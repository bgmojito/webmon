#!/bin/bash
# Tue un conteneur applicatif au hasard pour tester la résilience

set -euo pipefail

HOST_IP="${HOST_IP:-localhost}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Cibles "safe" (applicatives uniquement, pas le monitoring)
TARGETS=("webmon-backend" "webmon-frontend" "webmon-nginx")

# Mode : aléatoire ou cible explicite
if [[ $# -ge 1 ]]; then
  VICTIM="$1"
else
  VICTIM="${TARGETS[$RANDOM % ${#TARGETS[@]}]}"
fi

# Vérifie que la victime existe et tourne
if ! docker ps --format '{{.Names}}' | grep -q "^${VICTIM}$"; then
  echo -e "${RED}❌ Conteneur ${VICTIM} introuvable ou arrêté${NC}"
  echo -e "${YELLOW}Conteneurs disponibles :${NC}"
  docker ps --format '  {{.Names}}'
  exit 1
fi

echo -e "${RED}💀 CHAOS MONKEY${NC}"
echo -e "${YELLOW}Cible : ${VICTIM}${NC}"
echo ""

# Snapshot de l'état avant
echo -e "${CYAN}📸 État avant :${NC}"
docker ps --filter "name=${VICTIM}" --format "  {{.Names}} : {{.Status}}"

# Kill
echo ""
echo -e "${RED}🔥 Killing ${VICTIM}...${NC}"
docker exec "$VICTIM" kill 1 > /dev/null 2>&1

# Attente du redémarrage
echo -e "${YELLOW}⏱  Attente du redémarrage automatique...${NC}"
START_TIME=$(date +%s)
for i in {1..30}; do
  sleep 1
  STATUS=$(docker ps --filter "name=${VICTIM}" --format '{{.Status}}' 2>/dev/null || echo "")
  if [[ "$STATUS" == *"Up"* ]]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo ""
    echo -e "${GREEN}✅ ${VICTIM} a redémarré en ${DURATION}s${NC}"
    echo ""
    echo -e "${CYAN}📸 État après :${NC}"
    docker ps --filter "name=${VICTIM}" --format "  {{.Names}} : {{.Status}}"
    echo ""
    echo -e "${CYAN}🔍 Vérifie Grafana pour voir la coupure : http://${HOST_IP}:3000${NC}"
    exit 0
  fi
done

echo -e "${RED}❌ Le conteneur ne s'est pas relancé en 30s. Vérifie 'restart: unless-stopped' dans docker-compose.yml${NC}"
exit 1