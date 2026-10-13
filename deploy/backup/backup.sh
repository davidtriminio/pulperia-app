#!/bin/sh
# Copia diaria de la base (D-20, D-34). Corre dentro del servicio `backup` del Compose.
#
#   backup.sh loop            una copia cada día a la hora BACKUP_AT (UTC); es lo normal
#   backup.sh once            una copia ahora y sale (lo usan las pruebas y quien la quiera a mano)
#   backup.sh delay HH:MM     segundos hasta la próxima vez que sean HH:MM UTC
#
# Variables: PGHOST, PGUSER, PGPASSWORD, PGDATABASE (de la base), BACKUP_DIR (por omisión /backups),
# BACKUP_KEEP (cuántas conserva, 3), BACKUP_AT (HH:MM en UTC, 03:00) y BACKUP_AFTER_COMMAND
# (opcional: se ejecuta tras cada copia con la ruta en $BACKUP_FILE, para enviarla fuera del servidor).
#
# Códigos de salida de `once`: 0 bien, 1 la copia falló (no se toca ninguna copia anterior),
# 4 la copia quedó bien pero el comando de salida falló.
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_KEEP="${BACKUP_KEEP:-3}"
BACKUP_AT="${BACKUP_AT:-03:00}"
PREFIX="pulperia"

log() { echo "[backup $(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# "07" -> 7 (el shell leería 08 y 09 como octal inválido).
dec() { printf '%d' "$(printf '%s' "$1" | sed 's/^0*\([0-9]\)/\1/')"; }

# Segundos hasta la próxima vez que el reloj de UTC marque $1 (HH:MM). Si ya es esa hora o pasó,
# la de mañana. BACKUP_NOW_UTC (HH:MM:SS) fija "ahora" para las pruebas.
delay_until() {
  target="$1"
  now="${BACKUP_NOW_UTC:-$(date -u +%H:%M:%S)}"
  th="$(dec "${target%%:*}")"; tm="$(dec "${target#*:}")"
  nh="$(dec "${now%%:*}")"; rest="${now#*:}"; nm="$(dec "${rest%%:*}")"; ns="$(dec "${rest#*:}")"
  wanted=$(( th * 3600 + tm * 60 ))
  current=$(( nh * 3600 + nm * 60 + ns ))
  diff=$(( wanted - current ))
  if [ "$diff" -le 0 ]; then diff=$(( diff + 86400 )); fi
  echo "$diff"
}

# Deja solo las BACKUP_KEEP copias más recientes (el nombre lleva la fecha, así que ordenar por nombre
# es ordenar por tiempo).
rotate() {
  ls -1 "$BACKUP_DIR" 2>/dev/null | grep -E "^${PREFIX}-[0-9]{8}T[0-9]{6}Z\.dump$" | sort -r \
    | tail -n +"$((BACKUP_KEEP + 1))" | while read -r old; do
      rm -f "$BACKUP_DIR/$old"
      log "copia antigua eliminada: $old"
    done
}

backup_once() {
  mkdir -p "$BACKUP_DIR"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  file="$BACKUP_DIR/$PREFIX-$stamp.dump"
  # Dos copias en el mismo segundo: se espera para que el nombre siga ordenando por tiempo.
  while [ -e "$file" ]; do
    sleep 1
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    file="$BACKUP_DIR/$PREFIX-$stamp.dump"
  done
  partial="$file.partial"

  log "iniciando copia de $PGDATABASE en $PGHOST"
  # Primero a un archivo parcial: una copia a medias nunca ocupa el lugar de una buena.
  if ! pg_dump --format=custom --no-owner --file="$partial"; then
    rm -f "$partial"
    log "ERROR: pg_dump falló; las copias anteriores no se tocaron"
    return 1
  fi
  if ! pg_restore --list "$partial" >/dev/null 2>&1; then
    rm -f "$partial"
    log "ERROR: la copia generada no es legible; las copias anteriores no se tocaron"
    return 1
  fi
  mv "$partial" "$file"
  log "copia lista: $file ($(du -h "$file" | cut -f1))"
  rotate

  if [ -n "${BACKUP_AFTER_COMMAND:-}" ]; then
    log "ejecutando el comando de salida"
    if ! BACKUP_FILE="$file" sh -c "$BACKUP_AFTER_COMMAND"; then
      log "AVISO: el comando de salida falló; la copia local sigue en $file"
      return 4
    fi
  fi
  return 0
}

case "${1:-loop}" in
  once)
    backup_once
    ;;
  delay)
    delay_until "${2:-$BACKUP_AT}"
    ;;
  loop)
    log "servicio de copias: cada día a las $BACKUP_AT UTC, conserva $BACKUP_KEEP"
    while true; do
      wait_s="$(delay_until "$BACKUP_AT")"
      log "próxima copia en ${wait_s}s"
      sleep "$wait_s"
      backup_once || true
    done
    ;;
  *)
    echo "Uso: backup.sh [loop|once|delay HH:MM]" >&2
    exit 2
    ;;
esac
