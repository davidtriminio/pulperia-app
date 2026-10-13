# Despliegue y operación (Oracle Cloud + Vercel)

Esta carpeta pone la API y la base de datos en tu máquina de **Oracle Cloud** con Docker (D-33) y
deja la copia diaria de la base (D-34). La web va aparte, en **Vercel**.

```
Internet ──https──▶ Caddy ──▶ API (.NET) ──▶ PostgreSQL
                    (80/443)   (interna)     (interna)
                                                │
                                   backup (pg_dump diario) ──▶ ./backups
```

- Solo **Caddy** publica puertos (80 y 443). La API y la base no se alcanzan desde internet.
- Caddy saca y renueva solo el certificado HTTPS de Let's Encrypt.
- La API no migra sola: el servicio `migrate` aplica las migraciones pendientes antes de arrancarla.
- Todo lo que cambia entre máquinas va en un archivo **`.env`** de esta carpeta (no va al repositorio).

## 1. Una sola vez: preparar la máquina

### 1.1 DNS en Cloudflare
Crea un registro **A** para tu subdominio (por ejemplo `api`) con la **IP pública** de la instancia
y la nube en **gris (solo DNS)**, no naranja. Así Caddy obtiene su certificado directamente.

### 1.2 Puertos en Oracle (hay que abrirlos en dos sitios)
1. **Red virtual (VCN)** → tu subred → *Security List* (o el NSG de la instancia) → reglas de
   entrada: TCP **80** y TCP/UDP **443** desde `0.0.0.0/0`. El 22 (SSH) déjalo solo para tu IP.
2. **Firewall del propio Ubuntu.** Las imágenes de Oracle traen reglas de `iptables` que bloquean todo
   salvo el 22. En la instancia:

   ```bash
   sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
   sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
   sudo iptables -I INPUT 6 -m state --state NEW -p udp --dport 443 -j ACCEPT
   sudo netfilter-persistent save
   ```

   (Si usas `ufw`: `sudo ufw allow 80,443/tcp && sudo ufw allow 443/udp`.)

### 1.3 Docker
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"      # cierra sesión y vuelve a entrar
docker compose version               # debe responder
```

### 1.4 El código y el `.env`
```bash
git clone https://github.com/davidtriminio/pulperia-app.git
cd pulperia-app/deploy
cp .env.example .env
chmod 600 .env
nano .env
```
Rellena en `.env`:

| Variable | Qué poner |
|---|---|
| `API_DOMAIN` | El subdominio de la API, por ejemplo `api.tudominio.com` |
| `POSTGRES_PASSWORD` | Una contraseña larga y propia: `openssl rand -base64 32` |
| `CORS_ALLOWED_ORIGINS` | La URL de tu web en Vercel (`https://….vercel.app` o tu dominio), sin `*` |
| `BACKUP_AT`, `BACKUP_KEEP` | Hora (UTC) de la copia diaria y cuántas conservar (03:00 y 3) |

## 2. Arrancar

```bash
cd pulperia-app/deploy
docker compose up -d --build
docker compose ps                         # db y api "Up"; migrate "Exited (0)" es lo correcto
curl https://api.tudominio.com/health     # {"status":"ok"}
```

La primera vez, Caddy tarda unos segundos en obtener el certificado. Si `curl` falla, mira
`docker compose logs caddy` y la sección *Problemas comunes*.

En la app móvil y en la web, la dirección de la API es `https://api.tudominio.com`.

## 3. Operación del día a día

| Qué | Comando (desde `deploy/`) |
|---|---|
| Ver el estado | `docker compose ps` |
| Ver los registros de la API | `docker compose logs -f api` |
| Actualizar a una versión nueva | `git pull && docker compose up -d --build` (migra solo) |
| Reiniciar la API | `docker compose restart api` |
| Aplicar un cambio del `.env` | `docker compose up -d` |

### 3.1 Marcar a un super administrador (RF-95)
La persona debe haberse registrado antes en la app. Después:

```bash
docker compose exec api dotnet Pulperia.Api.dll admin grant-superadmin correo@ejemplo.com
docker compose exec api dotnet Pulperia.Api.dll admin revoke-superadmin correo@ejemplo.com
```

Retirar la marca al último super administrador se rechaza. Cada cambio queda en la auditoría.

### 3.2 Restablecer la contraseña de una cuenta (RF-81, T141)
Cuando alguien olvidó su contraseña y no tiene otra forma de entrar:

```bash
docker compose exec api dotnet Pulperia.Api.dll admin reset-password correo@ejemplo.com
```

Responde algo así:

```
Contraseña restablecida para correo@ejemplo.com. Se cerraron sus sesiones abiertas.
Contraseña nueva (se muestra una sola vez): k7Mw2PxQ9tHnR4Zb
```

- La contraseña se muestra **una sola vez** y no queda guardada en ningún sitio: cópiala y entrégasela
  a la persona por un medio seguro; que la cambie al entrar.
- Se cierran todas sus sesiones abiertas (en el teléfono tendrá que volver a iniciar sesión).
- Queda en la auditoría quién lo hizo y cuándo, y el comando no muestra datos de ningún negocio.
- Si el correo no existe, dice «No existe una cuenta con ese correo» y no cambia nada.

Un super administrador también puede hacerlo desde el panel web (`POST /api/admin/accounts/{id}/reset-password`).

### 3.3 Activar un negocio nuevo (RF-103)
Cada negocio nuevo nace pendiente y no funciona hasta que un super administrador lo activa. Mientras no
exista el panel web, se hace por la API con la sesión de un super administrador:

```bash
TOKEN=$(curl -s https://api.tudominio.com/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"tu@correo.com","password":"TU_CONTRASEÑA"}' | sed 's/.*"accessToken":"\([^"]*\)".*/\1/')

# ver los pendientes
curl -s "https://api.tudominio.com/api/admin/businesses?status=pending" -H "Authorization: Bearer $TOKEN"
# activar uno
curl -s -X POST "https://api.tudominio.com/api/admin/businesses/ID_DEL_NEGOCIO/activate" \
  -H "Authorization: Bearer $TOKEN"
```

## 4. Copias de seguridad (RNF-8, D-34)

### 4.1 Qué hace el servicio
- Cada día a la hora `BACKUP_AT` (UTC) genera un volcado completo de la base con `pg_dump`.
- Lo deja en `deploy/backups/` **en la misma máquina**, con el nombre `pulperia-AAAAMMDDTHHMMSSZ.dump`.
- Conserva las `BACKUP_KEEP` más recientes (3) y borra el resto.
- Si la copia falla no toca las anteriores. Una copia a medias nunca ocupa el lugar de una buena.

> **Importante:** RNF-8 pide que la copia esté **fuera de la máquina donde corre la base**. Por
> decisión tuya (D-34) la copia queda en el mismo servidor y **tú la sacas cada día**. Si no la sacas,
> una pérdida de la máquina se lleva también las copias.

### 4.2 Sacar la copia cada día (desde tu computadora)
El archivo más reciente es el último por nombre. Ejemplo con `scp` (ajusta usuario, host y rutas):

```bash
scp ubuntu@api.tudominio.com:pulperia-app/deploy/backups/pulperia-*.dump ./copias-pulperia/
```

Para que corra solo, prográmalo en tu computadora:
- **Windows:** Programador de tareas → acción *Iniciar un programa* con el comando `scp` de arriba.
- **Linux/macOS:** `crontab -e` → `30 4 * * * scp ubuntu@api.tudominio.com:…/*.dump ~/copias-pulperia/`

La hora debe ser posterior a `BACKUP_AT`. Revisa de vez en cuando que el archivo del día exista.

### 4.3 Enganche para automatizarlo después (opcional)
`BACKUP_AFTER_COMMAND` en el `.env` es un comando que se ejecuta **dentro del contenedor de copias**
justo después de cada copia, con la ruta en `$BACKUP_FILE`. Sirve para enviarla a otro lado sin
cambiar nada más. Va vacío por omisión. Dos cosas a saber:

- Solo existen las herramientas de esa imagen (Alpine con `postgres`): `cp`, `wget`, `sh`. Para
  `rclone` o `ssh` habría que usar otra imagen.
- Si el comando falla, la copia local **se conserva** y queda un aviso en los registros
  (`docker compose logs backup`).

### 4.4 Restaurar una copia
Siempre se restaura en una **base vacía**; el script se niega a escribir sobre una que tenga datos.

**Probar una copia sin tocar nada** (crea una base `pulperia_restore` y comprueba su integridad):

```bash
docker compose run --rm --entrypoint sh backup /scripts/restore.sh /backups/pulperia-AAAAMMDDTHHMMSSZ.dump
```

Termina con `Integridad: OK` y los conteos de usuarios, negocios, pertenencias, clientes, fiados y
abonos. Para borrar la base de prueba después:

```bash
docker compose exec db psql -U pulperia -d postgres -c 'DROP DATABASE pulperia_restore'
```

**Recuperar el servicio después de perder la base** (ya con el `.env` y un `docker compose up -d db`):

```bash
docker compose stop api caddy backup
docker compose exec db psql -U pulperia -d postgres -c 'DROP DATABASE pulperia' -c 'CREATE DATABASE pulperia'
docker compose run --rm --entrypoint sh backup /scripts/restore.sh /backups/pulperia-AAAAMMDDTHHMMSSZ.dump pulperia
docker compose up -d
```

Si la máquina es nueva, copia primero el `.dump` a `deploy/backups/`.

## 5. Problemas comunes

| Síntoma | Causa probable |
|---|---|
| `curl https://api…` no conecta o da error de certificado | Faltan abrir 80/443 en la VCN **o** en el firewall de Ubuntu (1.2); o el registro de Cloudflare está en naranja (proxy) |
| `docker compose logs caddy` dice que no puede obtener el certificado | El dominio no apunta a la IP de la máquina, o el 80 está cerrado (Let's Encrypt entra por el 80) |
| La web de Vercel muestra un error de CORS | `CORS_ALLOWED_ORIGINS` no incluye exactamente la URL de la web (con `https://`, sin barra al final); aplica con `docker compose up -d` |
| `migrate` termina con error | Mira `docker compose logs migrate`; la API no arranca hasta que migre bien |
| Una cuenta no puede entrar tras un reinicio de contraseña | Debe usar la contraseña nueva exacta; si se perdió, repite 3.2 |

## 6. Pruebas de este despliegue

Corren en tu computadora con Docker (no hace falta la máquina de Oracle):

```bash
bash deploy/tests/compose_test.sh   # arranque, HTTPS, migración, aislamiento, CORS y comandos del servidor
bash deploy/tests/backup_test.sh    # copia diaria, rotación, comando de salida y horario
bash deploy/tests/restore_test.sh   # restauración e integridad
```
