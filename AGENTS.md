# AGENTS.md — pulperia-app

## Proyecto
App para pulperías (negocios locales) que administra deudas de clientes (fiados): quién debe, cuánto y por qué. Cada ítem fiado guarda el precio del producto al momento de la compra. Móvil offline-first con sincronización al servidor (es la prioridad); cliente web con las mismas operaciones y permisos, pero que exige conexión. Multi-negocio (SaaS): varios usuarios por negocio y un usuario puede pertenecer a varios negocios.

Monorepo:
- `api/`    — Backend .NET (ASP.NET Core, EF Core, PostgreSQL), en Docker.
- `mobile/` — App Flutter, SQLite local (Drift) + cola de cambios para sync por lote.
- `web/`    — Cliente Angular.

## Comandos
Desde la raíz del repo salvo donde se indica.
- API:    `dotnet run --project api/src/Pulperia.Api` (http://localhost:5109) | tests: `dotnet test api`
- Mobile: `flutter run` (en `mobile/`; requiere emulador o teléfono) | análisis: `flutter analyze` | tests: `flutter test` (en `mobile/`) | código generado de Drift: `dart run build_runner build --delete-conflicting-outputs` (en `mobile/`; el `.g.dart` se versiona)
- Web:    `pnpm start` (en `web/`, equivale a `ng serve`; http://localhost:4200) | tests: `pnpm test --watch=false` (en `web/`, una sola pasada) | build: `pnpm build`
- Emulador Android: `ANDROID_SDK_ROOT` y `ANDROID_HOME` deben apuntar a `V:\Programas\Android\Sdk` al lanzarlo (`emulator -avd Resizable_Experimental`); Flutter ya usa ese SDK (`flutter config --android-sdk`). Luego `flutter run -d emulator-5554`.

## Estilo y convenciones
- Código e identificadores en inglés; mensajes al usuario y documentación en español.
- Dinero: siempre enteros en la unidad menor (centavos de lempira) en .NET, Flutter y Angular, según el plan (D-1). Nunca `double`/`float`.
- IDs generados en el cliente para poder crear registros offline: paquete `uuid`, UUID v7 (RFC 9562), mediante un único generador inyectable (D-21). El servidor acepta cualquier GUID válido, sin suponer v4.
- Fechas en UTC en almacenamiento y API.

## Commits
- Conventional Commits con scope: `tipo(scope): descripción` (ej. `feat(mobile): registrar abono general`).
- Scopes permitidos: `api`, `mobile`, `web`, `specs`, `docs`, `repo` (configuración transversal).
- Un commit por tarea de `specs/*/tasks.md`, al terminarla con la suite en verde; tests e implementación van juntos, y la casilla de la tarea se marca en ese mismo commit.
- El mensaje no lleva el ID de la tarea: es Conventional Commits puro (ej. `feat(api): crear solución .NET por capas`).
- Nunca añadir a Claude como coautor ni atribución a Claude en commits o PRs.

## Ramas
- Flujo `main` ← `develop` ← ramas de trabajo. Nunca se commitea directo en `main` ni en `develop`.
- Niveles de trabajo: **tarea** (un commit con sus tests y su casilla de `tasks.md`), **bloque** (grupo de tareas relacionadas, que cierra con informe) y **fase** (grupo de bloques de una fase, o de un tramo estable de ella, de `tasks.md`).
- Cada fase tiene una rama y un PR hacia `develop`; los bloques de esa fase son commits consecutivos en esa misma rama, con un commit por tarea. Si una fase es muy larga se parte en tramos coherentes, cada uno con su rama y su PR.
- La rama se crea desde `develop` y se llama `<tipo>/<scope>-<descripción-de-la-fase>` (ej. `feat/mobile-fase-9-interfaz`), con tipo y scope de Conventional Commits.
- Las tareas delicadas (sincronización, permisos, API/servidor, seguridad, migraciones) llevan rama y PR propios, aparte de la fase.
- Las ramas entran en `develop` mediante PR con "rebase and merge" (nunca squash), para conservar un commit por tarea; solo con CI (`ci-ok`) en verde.
- `develop` entra en `main` mediante PR al cerrar cada fase, o cada tramo estable de una fase cuyo resto depende de otro proyecto (p. ej. del servidor), siempre con las suites de los proyectos existentes en verde. Al cerrar una fase se propone ese PR al usuario.
- Antes de cada bloque: `git fetch --prune`, `gh pr list --state all` y pull de `develop`, verificando qué está realmente fusionado.
- Al terminar cada bloque se sube la rama y se para con un informe de cierre (por tarea: qué se hizo, tests, y decisiones que la spec no define); el PR se abre al cerrar la fase o el tramo, o antes si el usuario lo pide. No se abren ni se fusionan PR sin petición del usuario.
- Al abrir un PR se entrega siempre al usuario el comando de fusión con el número real: `gh pr merge <número> --rebase --delete-branch`.

## Reglas
- Lee `docs/constitution.md` y la spec activa en `specs/` antes de tocar código.
- No añadas dependencias ni cambies el contrato de la API sin actualizar antes la spec/plan.
- No modifiques archivos dentro de `specs/` salvo petición explícita.
- Tests primero en cada tarea (verlos en rojo, implementar, ver verde) y un commit por tarea. Párate al terminar el bloque (informe y push), o antes si algo bloquea: un test que no pasa, una laguna de la spec, una dependencia no aprobada o una tarea de más de 30 minutos.

## Al terminar cada tarea y al cerrar el bloque
- Ejecuta los tests del/los proyecto(s) tocados y confirma en tu respuesta que todo pasa.
