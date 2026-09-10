#!/bin/bash
# Déroule le cycle complet backup -> perte de données -> restore et vérifie
# que la donnée revient intacte, sans intervention humaine.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail() {
  echo -e "${RED}❌ $1${NC}"
  exit 1
}

step() {
  echo -e "${YELLOW}▶ $1${NC}"
}

psql_exec() {
  docker compose exec -T postgres psql -U webmon -d webmon -v ON_ERROR_STOP=1 "$@"
}

# 1. Vérifie que la stack tourne
step "Vérification que postgres tourne"
if ! docker compose exec -T postgres pg_isready -U webmon >/dev/null 2>&1; then
  fail "Le conteneur postgres ne tourne pas. Lance 'make start' d'abord."
fi
echo -e "${GREEN}✅ Postgres est up${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_VALUE="webmon-backup-restore-test-${TIMESTAMP}-$$"
CLEANED_UP=0

cleanup() {
  if [[ "$CLEANED_UP" -eq 0 ]]; then
    docker compose exec -T postgres psql -U webmon -d webmon -c \
      "DELETE FROM tasks WHERE title='${TEST_VALUE}';" >/dev/null 2>&1 || true
    CLEANED_UP=1
  fi
}
trap cleanup EXIT

# 2. Insère une ligne de test identifiable (avec horodatage dans la valeur)
step "Insertion de la ligne de test : ${TEST_VALUE}"
psql_exec -c "INSERT INTO tasks(title) VALUES ('${TEST_VALUE}');" >/dev/null

INSERTED=$(psql_exec -tAc "SELECT title FROM tasks WHERE title='${TEST_VALUE}';")
[[ "$INSERTED" == "$TEST_VALUE" ]] || fail "La ligne de test n'a pas été insérée correctement."
echo -e "${GREEN}✅ Ligne de test présente en base${NC}"

# 3. Lance backup.sh et vérifie qu'un fichier a bien été produit
step "Lancement de backup.sh"
mkdir -p backups
BACKUPS_BEFORE=$(find backups -maxdepth 1 -name 'webmon_*.sql' 2>/dev/null | wc -l | tr -d ' ')
bash scripts/backup.sh
BACKUPS_AFTER=$(find backups -maxdepth 1 -name 'webmon_*.sql' 2>/dev/null | wc -l | tr -d ' ')
[[ "$BACKUPS_AFTER" -gt "$BACKUPS_BEFORE" ]] || fail "Aucun nouveau fichier de backup n'a été produit."

BACKUP_FILE=$(ls -t backups/webmon_*.sql 2>/dev/null | head -1 || echo "")
[[ -s "$BACKUP_FILE" ]] || fail "Le fichier de backup ${BACKUP_FILE} est vide ou introuvable."
grep -qF "$TEST_VALUE" "$BACKUP_FILE" || fail "Le backup ${BACKUP_FILE} ne contient pas la ligne de test."
echo -e "${GREEN}✅ Backup produit : ${BACKUP_FILE}${NC}"

# 4. Vide la table
step "Purge de la table tasks"
psql_exec -c "TRUNCATE TABLE tasks;" >/dev/null

# 5. Vérifie que la donnée a bien disparu
REMAINING=$(psql_exec -tAc "SELECT count(*) FROM tasks WHERE title='${TEST_VALUE}';" | tr -d ' ')
[[ "$REMAINING" == "0" ]] || fail "La table n'a pas été vidée, le test ne prouve rien."
echo -e "${GREEN}✅ Table vidée, donnée de test absente${NC}"

# 6. Lance restore.sh en mode non interactif
step "Lancement de restore.sh --yes sur ${BACKUP_FILE}"
bash scripts/restore.sh --yes "$BACKUP_FILE" >/dev/null

# 7. Vérifie que la ligne de test est revenue, avec la bonne valeur
RESTORED=$(psql_exec -tAc "SELECT title FROM tasks WHERE title='${TEST_VALUE}';")
[[ "$RESTORED" == "$TEST_VALUE" ]] || fail "La ligne de test n'a pas été restaurée correctement."
echo -e "${GREEN}✅ Ligne de test restaurée avec la bonne valeur${NC}"

# 8. Nettoie sa donnée de test
cleanup

echo ""
echo -e "${GREEN}🎉 Cycle backup/restore validé : la restauration est idempotente.${NC}"
exit 0
