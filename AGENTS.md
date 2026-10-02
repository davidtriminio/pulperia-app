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
- Mobile: `flutter run` (en `mobile/`; requiere emulador o teléfono) | análisis: `flutter analyze` | tests: `flutter test` (en `mobile/`)
- Web:    `pnpm start` (en `web/`, equivale a `ng serve`; http://localhost:4200) | tests: `pnpm test --watch=false` (en `web/`, una sola pasada) | build: `pnpm build`
- Emulador Android: `ANDROID_SDK_ROOT` y `ANDROID_HOME` deben apuntar a `V:\Programas\Android\Sdk` al lanzarlo (`emulator -avd Resizable_Experimental`); Flutter ya usa ese SDK (`flutter config --android-sdk`). Luego `flutter run -d emulator-5554`.

## Estilo y convenciones
- Código e identificadores en inglés; mensajes al usuario y documentación en español.
- Dinero: siempre enteros en la unidad menor (centavos de lempira) en .NET, Flutter y Angular, según el plan (D-1). Nunca `double`/`float`.
- IDs generados en el cliente (GUID/UUID) para poder crear registros offline.
- Fechas en UTC en almacenamiento y API.

## Commits
- Conventional Commits con scope: `tipo(scope): descripción` (ej. `feat(mobile): registrar abono general`).
- Scopes permitidos: `api`, `mobile`, `web`, `specs`, `docs`, `repo` (configuración transversal).
- Un commit por tarea de `specs/*/tasks.md`, al terminarla con la suite en verde; tests e implementación van juntos.
- El mensaje no lleva el ID de la tarea: es Conventional Commits puro (ej. `feat(api): crear solución .NET por capas`).
- Nunca añadir a Claude como coautor ni atribución a Claude en commits o PRs.

## Ramas
- Flujo `main` ← `develop` ← ramas de trabajo. Nunca se commitea directo en `main` ni en `develop`.
- Cada rama de trabajo se crea desde `develop` y se llama `<tipo>/<scope>-<descripción-corta>` (ej. `feat/api-solucion-por-capas`), con tipo y scope de Conventional Commits.
- Las ramas de trabajo entran en `develop` mediante PR; `develop` entra en `main` mediante PR cuando hay un estado estable con las suites en verde.
- Al terminar una rama, se para en el paso del PR.

## Reglas
- Lee `docs/constitution.md` y la spec activa en `specs/` antes de tocar código.
- No añadas dependencias ni cambies el contrato de la API sin actualizar antes la spec/plan.
- No modifiques archivos dentro de `specs/` salvo petición explícita.
- Una tarea cada vez, tests primero; al terminar la tarea, párate.

## Al terminar cualquier tarea
- Ejecuta los tests del/los proyecto(s) tocados y confirma en tu respuesta que todo pasa.
