#!/bin/bash
# Restaure la dernière sauvegarde, ou un fichier passé en argument

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse les arguments : --dry-run, --yes/-y, et éventuellement un chemin de fichier
DRY_RUN=0
AUTO_YES=${RESTORE_YES:-0}
BACKUP_FILE=""
for ARG in "$@"; do
  case "$ARG" in
    --dry-run)
      DRY_RUN=1
      ;;
    --yes|-y)
      AUTO_YES=1
      ;;
    *)
      BACKUP_FILE="$ARG"
      ;;
  esac
done

# Détermine le fichier à restaurer
if [[ -z "$BACKUP_FILE" ]]; then
  # Dernière sauvegarde
  BACKUP_FILE=$(ls -t backups/webmon_*.sql 2>/dev/null | head -1 || echo "")
fi

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo -e "${RED}❌ Aucun backup trouvé dans backups/${NC}"
  exit 1
fi

# Vérifie que postgres tourne
if ! docker compose exec -T postgres pg_isready -U webmon >/dev/null 2>&1; then
  echo -e "${RED}❌ Le conteneur postgres ne tourne pas. Lance 'make start' d'abord.${NC}"
  exit 1
fi

# Confirmation (sautée avec --yes/-y ou RESTORE_YES=1)
echo -e "${YELLOW}⚠️  Tu vas écraser les données actuelles avec : ${BACKUP_FILE}${NC}"
if [[ "$AUTO_YES" == "1" ]]; then
  echo "Confirmation ignorée (--yes)."
else
  read -p "Continuer ? (oui/non) : " CONFIRM
  if [[ "$CONFIRM" != "oui" ]]; then
    echo "Annulé."
    exit 0
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "${YELLOW}🧪 Dry-run : pas d'exécution${NC}"
  exit 0
fi

echo -e "${YELLOW}🔄 Restauration en cours...${NC}"

# Restauration (le dump contient déjà --clean --if-exists : il nettoie le schéma lui-même)
if docker compose exec -T postgres psql -U webmon -d webmon < "$BACKUP_FILE" > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Restauration terminée${NC}"
else
  echo -e "${RED}❌ Erreur pendant la restauration${NC}"
  exit 1
fi