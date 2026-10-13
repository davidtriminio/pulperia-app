#!/bin/sh
# Restaura una copia (la del servicio `backup`) en una base VACÍA y comprueba su integridad
# (RNF-8, D-34). Nunca pisa una base con datos.
#
#   restore.sh <ruta-de-la-copia> [base-destino]      (por omisión: <PGDATABASE>_restore)
#
# Variables: PGHOST, PGUSER, PGPASSWORD, PGDATABASE. Códigos de salida:
#   0 restaurada e íntegra · 1 la copia no se pudo leer o restaurar · 2 uso incorrecto o archivo
#   inexistente · 3 la base destino ya tiene datos · 5 se restauró pero falló la comprobación.
set -eu

file="${1:-}"
target="${2:-${PGDATABASE:-pulperia}_restore}"

if [ -z "$file" ]; then
  echo "Uso: restore.sh <ruta-de-la-copia> [base-destino]" >&2
  exit 2
fi
if [ ! -f "$file" ]; then
  echo "No existe la copia: $file" >&2
  exit 2
fi
case "$target" in
  *[!a-zA-Z0-9_]*|"")
    echo "Nombre de base no válido: solo letras, números y guion bajo." >&2
    exit 2
    ;;
esac

# Antes de crear nada: ¿se puede leer la copia?
if ! pg_restore --list "$file" >/dev/null 2>&1; then
  echo "El archivo no es una copia válida de PostgreSQL: $file" >&2
  exit 1
fi

created=0
if [ "$(psql -d postgres -tAc "select 1 from pg_database where datname = '$target'")" = "1" ]; then
  tables="$(psql -d "$target" -tAc "select count(*) from information_schema.tables where table_schema = 'public'")"
  if [ "$tables" != "0" ]; then
    echo "La base $target ya tiene datos ($tables tablas): no se restaura encima. Usa una base nueva." >&2
    exit 3
  fi
else
  createdb -d postgres "$target" 2>/dev/null || createdb "$target"
  created=1
fi

echo "Restaurando $file en $target..."
if ! pg_restore --no-owner --exit-on-error -d "$target" "$file"; then
  echo "La restauración falló." >&2
  if [ "$created" = "1" ]; then dropdb "$target" || true; fi
  exit 1
fi

# Consulta de integridad: tablas esperadas, historial de migraciones y pertenencias sin dueño.
if ! psql -d "$target" -v ON_ERROR_STOP=1 -tA -f "$(dirname "$0")/integrity.sql"; then
  echo "Integridad: FALLA (la base $target quedó restaurada pero no pasa la comprobación)" >&2
  exit 5
fi
echo "Integridad: OK"
