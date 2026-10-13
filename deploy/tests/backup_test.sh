#!/usr/bin/env bash
# T138 y T140: copia diaria con rotación de 3, y comando de salida opcional (D-20, D-34).
# Uso: bash deploy/tests/backup_test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"
cd "$HERE/.."

PROJECT=pulperia-backup-test
OUT=./tests/.backups-test
rm -rf "$HERE/.backups-test"; mkdir -p "$HERE/.backups-test"
export BACKUPS_DIR="$OUT"
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml -f tests/docker-compose.test.yml --env-file tests/env.test)

cleanup() { "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1; rm -rf "$HERE/.backups-test"; }
trap cleanup EXIT
cleanup
mkdir -p "$HERE/.backups-test"

dumps() { ls -1 "$HERE/.backups-test" | grep -E '^pulperia-.*\.dump$' || true; }
count() { dumps | grep -c . || true; }
run_backup() { "${COMPOSE[@]}" run --rm -T "$@" backup once; }

echo "Preparación"
"${COMPOSE[@]}" up -d --build db migrate >/dev/null 2>&1
for i in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Status}}' ${PROJECT}-migrate-1 2>/dev/null)" = "exited" ] && break
  sleep 2
done
docker exec ${PROJECT}-db-1 psql -U pulperia -d pulperia -c \
  "insert into users (id, email, password_hash, created_at) values (gen_random_uuid(), 'ana@correo.com', 'x', now())" >/dev/null

echo "Una copia"
run_backup >/dev/null 2>&1
expect_equal "queda exactamente un archivo de copia" "1" "$(count)"
FIRST="$(dumps | head -1)"
check "el archivo es una copia válida de PostgreSQL (pg_restore --list)" \
  docker run --rm -v "$(pwd -W 2>/dev/null || pwd)/tests/.backups-test:/b:ro" postgres:17-alpine pg_restore --list "/b/$FIRST"
expect_equal "no queda ningún archivo parcial" "0" "$(ls -1 "$HERE/.backups-test" | grep -c '\.partial$' || true)"
check "el nombre lleva la fecha en UTC" bash -c "echo '$FIRST' | grep -Eq '^pulperia-[0-9]{8}T[0-9]{6}Z\.dump$'"

echo "Rotación de 3"
for n in 2 3 4; do run_backup >/dev/null 2>&1; done
expect_equal "tras 4 ejecuciones quedan exactamente 3" "3" "$(count)"
check "la más antigua fue la que se borró" bash -c "! ls '$HERE/.backups-test' | grep -q '$FIRST'"
NEWEST="$(dumps | tail -1)"
run_backup -e BACKUP_KEEP=2 >/dev/null 2>&1
expect_equal "con BACKUP_KEEP=2 quedan 2" "2" "$(count)"
check "la más reciente anterior sigue ahí" bash -c "ls '$HERE/.backups-test' | grep -q '$NEWEST'"

echo "Si la copia falla no se pierde nada"
BEFORE="$(dumps | tr '\n' ' ')"
run_backup -e PGPASSWORD=incorrecta >/dev/null 2>&1
CODE=$?
check "sale con error" test "$CODE" -ne 0
expect_equal "las copias anteriores siguen intactas" "$BEFORE" "$(dumps | tr '\n' ' ')"
expect_equal "no queda archivo parcial tras el fallo" "0" "$(ls -1 "$HERE/.backups-test" | grep -c '\.partial$' || true)"

echo "Comando de salida (T140)"
run_backup -e BACKUP_AFTER_COMMAND='echo "$BACKUP_FILE" > /backups/hook.txt' >/dev/null 2>&1
check "el comando de salida se ejecutó" test -f "$HERE/.backups-test/hook.txt"
LAST="$(dumps | tail -1)"
expect_equal "recibió la ruta de la copia recién hecha en BACKUP_FILE" "/backups/$LAST" "$(tr -d '\r\n' < "$HERE/.backups-test/hook.txt")"

run_backup -e BACKUP_AFTER_COMMAND='exit 7' >/dev/null 2>&1
CODE=$?
expect_equal "si el comando falla, sale con 4 (aviso) y no con 0" "4" "$CODE"
check "la copia local queda aunque el comando falle" test "$(count)" -ge 2
check "la rotación se respeta aunque el comando falle" test "$(count)" -le 3

echo "Horario diario"
delay() { "${COMPOSE[@]}" run --rm -T -e BACKUP_NOW_UTC="$1" backup delay "$2" 2>/dev/null | tr -d '\r\n'; }
expect_equal "faltan 30 s para las 03:00 si son las 02:59:30" "30" "$(delay 02:59:30 03:00)"
expect_equal "pasadas las 03:00 espera hasta mañana" "82800" "$(delay 04:00:00 03:00)"
expect_equal "justo a la hora espera un día entero" "86400" "$(delay 03:00:00 03:00)"
expect_equal "de madrugada hasta las 03:30" "5400" "$(delay 02:00:00 03:30)"

finish
