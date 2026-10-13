#!/usr/bin/env bash
# T139: restaurar una copia en una base vacía y comprobar su integridad (RNF-8, D-34).
# Uso: bash deploy/tests/restore_test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"
cd "$HERE/.."

PROJECT=pulperia-restore-test
export BACKUPS_DIR=./tests/.backups-restore
DIR="$HERE/.backups-restore"
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml -f tests/docker-compose.test.yml --env-file tests/env.test)

cleanup() { "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1; rm -rf "$DIR"; }
trap cleanup EXIT
cleanup
mkdir -p "$DIR"

psql_db() { docker exec "${PROJECT}-db-1" psql -U pulperia -d "$1" -tA -c "$2"; }
restore() { "${COMPOSE[@]}" run --rm -T --entrypoint /bin/sh backup /scripts/restore.sh "$@"; }

echo "Preparación"
"${COMPOSE[@]}" up -d --build db migrate >/dev/null 2>&1
for i in $(seq 1 60); do
  [ "$(docker inspect -f '{{.State.Status}}' ${PROJECT}-migrate-1 2>/dev/null)" = "exited" ] && break
  sleep 2
done
psql_db pulperia "
insert into users (id, email, password_hash, created_at) values
  ('0198a000-0000-7000-8000-000000000001', 'ana@correo.com', 'x', now()),
  ('0198a000-0000-7000-8000-000000000002', 'beto@correo.com', 'x', now());
insert into businesses (id, name, amount_mode, quantity_mode, created_at, status)
  values ('0198a000-0000-7000-8000-0000000000a1', 'Pulpería Ana', 'integer', 'integer', now(), 'active');
insert into memberships (user_id, business_id, role, status, final_sync_used)
  values ('0198a000-0000-7000-8000-000000000001', '0198a000-0000-7000-8000-0000000000a1', 'owner', 'active', false);
" >/dev/null
"${COMPOSE[@]}" run --rm -T backup once >/dev/null 2>&1
DUMP="$(ls -1 "$DIR" | grep -E '^pulperia-.*\.dump$' | head -1)"
check "hay una copia para restaurar" test -n "$DUMP"

echo "Restauración en una base vacía"
OUT="$(restore "/backups/$DUMP" pulperia_restore 2>&1)"; CODE=$?
expect_equal "sale con 0" "0" "$CODE"
case "$OUT" in
  *"Integridad: OK"*) pass "informa que la integridad está bien" ;;
  *) fail "debería informar integridad OK (salida: ${OUT: -200})" ;;
esac
expect_equal "los usuarios coinciden con el origen" "2" "$(psql_db pulperia_restore 'select count(*) from users')"
expect_equal "los negocios coinciden con el origen" "1" "$(psql_db pulperia_restore 'select count(*) from businesses')"
expect_equal "las pertenencias coinciden con el origen" "1" "$(psql_db pulperia_restore 'select count(*) from memberships')"
expect_equal "el historial de migraciones llegó completo" \
  "$(psql_db pulperia 'select count(*) from "__EFMigrationsHistory"')" \
  "$(psql_db pulperia_restore 'select count(*) from "__EFMigrationsHistory"')"

echo "Nunca pisa una base con datos"
OUT="$(restore "/backups/$DUMP" pulperia_restore 2>&1)"; CODE=$?
expect_equal "sale con 3 si el destino no está vacío" "3" "$CODE"
expect_equal "no cambió nada del destino" "2" "$(psql_db pulperia_restore 'select count(*) from users')"
OUT="$(restore "/backups/$DUMP" pulperia 2>&1)"; CODE=$?
expect_equal "tampoco restaura sobre la base en uso" "3" "$CODE"
expect_equal "la base en uso sigue intacta" "2" "$(psql_db pulperia 'select count(*) from users')"

echo "Entradas malas"
OUT="$(restore /backups/no-existe.dump pulperia_x 2>&1)"; CODE=$?
expect_equal "un archivo que no existe sale con 2" "2" "$CODE"
echo "esto no es una copia" > "$DIR/basura.dump"
OUT="$(restore /backups/basura.dump pulperia_basura 2>&1)"; CODE=$?
expect_equal "un archivo que no es una copia sale con 1" "1" "$CODE"
expect_equal "no deja creada la base de una copia inválida" "0" \
  "$(psql_db postgres "select count(*) from pg_database where datname='pulperia_basura'")"
OUT="$(restore "/backups/$DUMP" 'mala;drop' 2>&1)"; CODE=$?
expect_equal "un nombre de base con caracteres raros sale con 2" "2" "$CODE"

echo "Integridad que sí detecta problemas"
psql_db postgres "create database pulperia_rota" >/dev/null
"${COMPOSE[@]}" run --rm -T --entrypoint /bin/sh backup -c \
  "pg_restore --no-owner -d pulperia_rota /backups/$DUMP" >/dev/null 2>&1
psql_db pulperia_rota "drop table payments" >/dev/null
"${COMPOSE[@]}" run --rm -T --entrypoint /bin/sh -e PGDATABASE=pulperia_rota backup -c \
  "pg_dump --format=custom --no-owner --file=/backups/rota.dump" >/dev/null 2>&1
OUT="$(restore /backups/rota.dump pulperia_rota_restore 2>&1)"; CODE=$?
expect_equal "una copia sin una tabla esperada sale con 5" "5" "$CODE"
case "$OUT" in
  *payments*) pass "dice qué tabla falta" ;;
  *) fail "debería nombrar la tabla que falta (salida: ${OUT: -200})" ;;
esac

finish
