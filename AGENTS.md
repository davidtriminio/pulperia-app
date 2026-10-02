# AGENTS.md — pulperia-app

## Proyecto
App para pulperías (negocios locales) que administra deudas de clientes (fiados): quién debe, cuánto y por qué. Cada ítem fiado guarda el precio del producto al momento de la compra. Móvil offline-first con sincronización al servidor (es la prioridad); cliente web con las mismas operaciones y permisos, pero que exige conexión. Multi-negocio (SaaS): varios usuarios por negocio y un usuario puede pertenecer a varios negocios.

Monorepo:
- `api/`    — Backend .NET (ASP.NET Core, EF Core, PostgreSQL), en Docker.
- `mobile/` — App Flutter, SQLite local (Drift) + cola de cambios para sync por lote.
- `web/`    — Cliente Angular.

## Comandos (completar al crear cada proyecto)
- API:    `dotnet run --project api/...`  | tests: `dotnet test api`
- Mobile: `flutter run`                   | tests: `flutter test` (en `mobile/`)
- Web:    `ng serve`                      | tests: `ng test` (en `web/`)

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

## Reglas
- Lee `docs/constitution.md` y la spec activa en `specs/` antes de tocar código.
- No añadas dependencias ni cambies el contrato de la API sin actualizar antes la spec/plan.
- No modifiques archivos dentro de `specs/` salvo petición explícita.
- Una tarea cada vez, tests primero; al terminar la tarea, párate.

## Al terminar cualquier tarea
- Ejecuta los tests del/los proyecto(s) tocados y confirma en tu respuesta que todo pasa.
