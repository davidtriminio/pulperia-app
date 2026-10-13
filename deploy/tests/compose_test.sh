#!/usr/bin/env bash
# T136: `docker compose up` deja la API respondiendo por HTTPS y migrada, y la base y la API no
# son alcanzables desde fuera del Compose (D-33). Uso: bash deploy/tests/compose_test.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib.sh"
cd "$HERE/.."

PROJECT=pulperia-test
COMPOSE=(docker compose -p "$PROJECT" -f docker-compose.yml -f tests/docker-compose.test.yml --env-file tests/env.test)

cleanup() { "${COMPOSE[@]}" down -v --remove-orphans >/dev/null 2>&1; }
trap cleanup EXIT
cleanup

echo "Configuración"
check "el Compose es válido con un .env completo" "${COMPOSE[@]}" config -q
MISSING=$(docker compose -p "$PROJECT" -f docker-compose.yml config 2>&1 || true)
case "$MISSING" in
  *"Falta POSTGRES_PASSWORD"*|*"Falta API_DOMAIN"*) pass "sin .env falla diciendo qué falta" ;;
  *) fail "sin .env debería fallar diciendo qué falta (salida: ${MISSING:0:120})" ;;
esac

echo "Arranque"
"${COMPOSE[@]}" up -d --build 2>&1 | tail -3
BASE=https://localhost:18443

for i in $(seq 1 60); do
  if [ "$(curl -ks -o /dev/null -w '%{http_code}' "$BASE/health")" = "200" ]; then break; fi
  sleep 2
done

expect_equal "la API responde 200 en /health por HTTPS" "200" "$(curl -ks -o /dev/null -w '%{http_code}' "$BASE/health")"
expect_equal "el cuerpo de /health es {status: ok}" '{"status":"ok"}' "$(curl -ks "$BASE/health")"
check "el servicio de migración terminó bien" bash -c \
  "[ \"\$(docker inspect -f '{{.State.ExitCode}}' ${PROJECT}-migrate-1)\" = 0 ]"
check "la base quedó migrada (existe la tabla users)" bash -c \
  "docker exec ${PROJECT}-db-1 psql -U pulperia -d pulperia -tAc \"select to_regclass('public.users') is not null\" | grep -q t"

echo "Aislamiento"
expect_equal "la base no publica ningún puerto al anfitrión" "" "$(docker port ${PROJECT}-db-1)"
expect_equal "la API no publica ningún puerto al anfitrión" "" "$(docker port ${PROJECT}-api-1)"
case "$(docker port ${PROJECT}-caddy-1)" in
  *"443/tcp -> 0.0.0.0:18443"*) pass "Caddy sí publica el 443" ;;
  *) fail "Caddy debería publicar el 443" ;;
esac

echo "CORS"
ALLOWED=$(curl -ks -D - -o /dev/null -X OPTIONS "$BASE/api/businesses" \
  -H "Origin: https://pulperia-web.vercel.app" -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: authorization,content-type" | tr -d '\r' | tr 'A-Z' 'a-z')
case "$ALLOWED" in
  *"access-control-allow-origin: https://pulperia-web.vercel.app"*) pass "el origen configurado recibe CORS" ;;
  *) fail "el origen configurado debería recibir CORS" ;;
esac
OTHER=$(curl -ks -D - -o /dev/null -X OPTIONS "$BASE/api/businesses" \
  -H "Origin: https://sitio-malicioso.example" -H "Access-Control-Request-Method: POST" | tr -d '\r' | tr 'A-Z' 'a-z')
case "$OTHER" in
  *"access-control-allow-origin"*) fail "un origen no configurado no debería recibir CORS" ;;
  *) pass "un origen no configurado no recibe CORS" ;;
esac

echo "Comandos de administración documentados (T141)"
curl -ks -o /dev/null -X POST "$BASE/api/auth/register" -H "Content-Type: application/json" \
  -d '{"email":"ana@correo.com","password":"contrasena1","businessName":"Pulperia Ana","amountMode":"integer","quantityMode":"integer"}'
RESET="$("${COMPOSE[@]}" exec -T api dotnet Pulperia.Api.dll admin reset-password ana@correo.com 2>&1)"
CODE=$?
expect_equal "el comando documentado de restablecer contraseña sale con 0" "0" "$CODE"
NEWPASS="$(printf '%s\n' "$RESET" | grep 'Contraseña nueva' | sed 's/.*: //' | tr -d '\r\n')"
case "$RESET" in
  *SELECT*|*"Executed DbCommand"*) fail "la salida no debería traer consultas de la base" ;;
  *) pass "la salida es limpia: sin consultas de la base" ;;
esac
expect_equal "muestra una contraseña de 16 caracteres" "16" "${#NEWPASS}"
LOGIN="$(curl -ks -o /dev/null -w '%{http_code}' -X POST "$BASE/api/auth/login" \
  -H "Content-Type: application/json" -d "{\"email\":\"ana@correo.com\",\"password\":\"$NEWPASS\"}")"
expect_equal "con la contraseña nueva se inicia sesión por HTTPS" "200" "$LOGIN"
GRANT="$("${COMPOSE[@]}" exec -T api dotnet Pulperia.Api.dll admin grant-superadmin ana@correo.com 2>&1)"
case "$GRANT" in
  *"ahora es super administrador"*) pass "el comando documentado de marcar super administrador funciona" ;;
  *) fail "marcar super administrador debería funcionar (salida: ${GRANT: -160})" ;;
esac

finish
