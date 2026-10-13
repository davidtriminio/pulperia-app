# Utilidades de las pruebas del despliegue (se leen con `source`). Corren con Docker, en Git Bash.
set -u

# Git Bash en Windows convierte rutas como /backups en rutas de Windows: se desactiva.
export MSYS_NO_PATHCONV=1

FAILURES=0

pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FALLA %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

# check "descripción" comando...   (pasa si el comando sale con 0)
check() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}

# check_not "descripción" comando...   (pasa si el comando sale distinto de 0)
check_not() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$description"; else pass "$description"; fi
}

# expect_equal "descripción" esperado real
expect_equal() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (esperado: '$2', real: '$3')"; fi
}

finish() {
  if [ "$FAILURES" -eq 0 ]; then echo "Todo bien."; exit 0; fi
  echo "$FAILURES comprobación(es) fallaron."; exit 1
}
