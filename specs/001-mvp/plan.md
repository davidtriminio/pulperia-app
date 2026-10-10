# Plan técnico 001 — MVP: administrador de deudas (fiados) para pulperías

Estado: APROBADO el 2026-10-02; enmendado el 2026-10-05 con las unidades de venta (RF-86 a RF-89, D-23), el 2026-10-07 con el precio anterior y los productos repetidos (RF-90, RF-91, D-24) y el 2026-10-08 con las dependencias y el diseño de la persistencia de la API (D-25) y el 2026-10-09 con los topes de valores del servidor (D-26) y el 2026-10-09 con las contraseñas y sesiones de la API (D-27) los códigos de invitación (RF-92 a RF-94, D-28) el super administrador de la plataforma (RF-95 a RF-101, D-29) y la activación de negocios nuevos (RF-102 a RF-104, D-30) y el 2026-10-09 con los paquetes de la Fase 8 del móvil (D-31) y el 2026-10-10 con el registro con código de invitación (RF-105 a RF-107, D-32). Cubre `spec.md` (RF-1 a RF-107, RNF-1 a RNF-8) y respeta `docs/constitution.md` (principios 1 a 11).
Este plan no contiene código. Define módulos, modelo de datos, decisiones y estrategia de tests.

## 1. Visión general

```
 Flutter (móvil)                      ASP.NET Core (API)                  Angular (web)
 ┌──────────────────┐   push/pull    ┌────────────────────┐   mismas     ┌─────────────────┐
 │ UI               │◄──────────────►│ Sync + Comandos    │◄────────────►│ UI              │
 │ Casos de uso     │  lotes de ops  │ Dominio            │  operaciones │ Servicios       │
 │ Dominio          │                │ Persistencia (EF)  │  de una en   │ Dominio (reglas │
 │ Drift (local)    │                │ PostgreSQL         │  una         │  de lectura)    │
 │ Cola (outbox)    │                └────────────────────┘              └─────────────────┘
 └──────────────────┘
```

- **Una sola vía de escritura en el servidor**: todo cambio llega como una *operación* (crear cliente, registrar fiado, anular abono…). El móvil las envía en lote; la web las envía de una en una. Ambos pasan por las mismas reglas del dominio.
- **Lecturas**: el móvil lee de su base local. La web lee del servidor mediante consultas.
- **Nada se borra**: archivar y anular son estados. Por eso la sincronización no necesita lápidas de borrado (principio 11).
- **Orden de construcción** (el móvil primero, por ser la prioridad): vectores de prueba compartidos → dominio y base local del móvil → dominio y API → sincronización → web.

## 2. Módulos

### 2.1 Compartido (`shared/`)
Carpeta nueva en la raíz del monorepo. No es código ejecutable: son datos que las tres plataformas leen en sus tests.
- **Vectores de prueba** (JSON): casos de redondeo, cálculo de saldo, validación de teléfono, resumen. Las tres plataformas deben dar el mismo resultado (RNF-2, RF-34, RF-40, RF-63..66, RF-77).
- **Paleta de avatares**: 24 personajes, 6 tonos de piel y 12 fondos con sus identificadores (RF-72).
- **Unidades de venta**: la lista fija de unidades (unidad, libra, onza, kilo, docena, litro, galón, caja, bolsa, paquete) con sus identificadores estables y sus textos en español (RF-86).
- **Contrato de la API**: descripción OpenAPI mantenida junto al plan (ver sección 5).

### 2.2 API (.NET) — `api/`
| Módulo | Responsabilidad | RF |
|---|---|---|
| Identity | Cuentas por correo, sesiones, pertenencia a negocios, rol por negocio, elección de negocio | 1–6, 48, 50 |
| Businesses | Creación del negocio con nombre, cambio de nombre, ajustes de montos y cantidades | 1, 7–9, 78–80 |
| Admin tooling | Comandos del servidor: restablecer una contraseña y marcar o retirar super administradores, con registro de auditoría; sin acceso a datos de negocios | 81, 82, 95 |
| Platform admin | Rutas `/api/admin` solo para super administradores: negocios (pendientes incluidos) y cuentas con cifras agregadas, activar, suspender y reactivar, restablecer contraseña y auditoría; nunca devuelve datos de un negocio | 96–104 |
| Backups | Copia diaria de la base, enviada fuera de la máquina, con rotación de 3 copias | RNF-8 |
| Invitations | Invitaciones pendientes, aceptar, rechazar, cancelar; código de un solo uso y canje; promoción a dueño; último dueño; baja de empleado | 10–13, 67–71, 92–94 |
| Clients | Alta, edición, archivado y restauración; avatar; datos de contacto; aviso de homónimo | 14–23, 72–77 |
| Catalog | Productos: alta, cambio de precio y de unidad, archivado, precio anterior y aviso de repetidos | 24–27, 86, 90, 91 |
| Ledger | Fiados, ítems con su unidad, abonos, anulación, saldo, permisos por rol, autoría | 28–47, 49, 87–89 |
| Sync | Recepción de lotes de operaciones, idempotencia, conflictos, entrega de cambios por cursor, descarga inicial | 51–58, 62 |
| Reports | Resumen del negocio para la web | 63–65 |
| Web hosting | Entrega los archivos estáticos de la web | 59–61 |

Capas: **Domain** (reglas puras: dinero, saldo, permisos, validaciones; sin EF ni HTTP), **Application** (casos de uso y aplicación de operaciones), **Infrastructure** (EF Core, PostgreSQL), **Api** (endpoints). Principio 7.

### 2.3 Móvil (Flutter) — `mobile/`
| Módulo | Responsabilidad | RF |
|---|---|---|
| Domain | Dinero y cantidades, redondeo, saldo, validaciones, permisos por rol | 15, 16, 32–42, 74, 77 |
| Local store | Base local con todas las entidades, por negocio | 51 |
| Outbox | Cola de operaciones pendientes y su estado | 51, 56, 57 |
| Sync | Envío de lotes, descarga por cursor, descarga inicial, reintentos, resolución según respuesta del servidor | 52–58 |
| Session | Inicio de sesión, token persistente, negocio activo, cambio de negocio | 2–6 |
| Clients UI / Ledger UI / Catalog UI | Pantallas de clientes (con avatar y archivados), fiados, abonos, catálogo | 14–47 |
| Summary | Resumen calculado sobre datos locales | 63–66 |
| Business admin | Invitaciones, equipo, ajustes (requieren conexión) | 7–13, 67–71 |
| Avatar | Renderizado del avatar compuesto con recursos incluidos en la app | 14, 72 |

### 2.4 Web (Angular) — `web/`
| Módulo | Responsabilidad | RF |
|---|---|---|
| Core services | Sesión, cliente HTTP, detección de falta de conexión | 3, 59, 61 |
| Feature: clientes / fiados / abonos / catálogo | Mismas operaciones y permisos que el móvil, cada acción va directo al servidor | 14–47, 59, 60 |
| Feature: resumen | Consulta del resumen del servidor | 63–65 |
| Feature: equipo y ajustes | Invitaciones, promoción, baja, ajustes del negocio | 7–13, 67–71 |
| Feature: administración de la plataforma | Panel aparte (ruta `/admin`) solo para super administradores | 96–104 |
| Avatar | Mismo renderizado con la misma paleta compartida | 14, 72 |

## 3. Modelo de datos

### 3.1 Servidor (PostgreSQL)
Todo registro de negocio lleva `business_id` (principio 6). Los IDs son GUID generados en el cliente, UUID v7 (D-21). Fechas en UTC.

| Tabla | Campos principales |
|---|---|
| users | id, email (único sin distinguir mayúsculas), password_hash, created_at, is_super_admin (por omisión falso), suspended_at?, suspension_reason? |
| admin_audit | id, action (restablecer contraseña, marcar o retirar super admin, suspender o reactivar negocio o cuenta), target_user_id?, target_business_id? (solo el id, nunca datos del negocio), detail? (motivo), performed_by (identificador del operador, o el correo del super administrador), performed_at |
| businesses | id, name (obligatorio, editable por dueños), amount_mode (enteros / 2 decimales), quantity_mode (enteras / fraccionarias), last_seq, created_at, status (pendiente / activo / suspendido), status_reason? |
| memberships | user_id, business_id, role (dueño / empleado), status (activo / removido), removed_at, final_sync_used |
| invitations | id, business_id, email? (vacío en una invitación solo por código), code (único), status (pendiente / aceptada / rechazada / cancelada), created_by, created_at |
| clients | id, business_id, name, character_id, skin_id, background_id, phone?, address?, note?, archived, version, created_by, created_at, updated_at |
| products | id, business_id, name, price (unidad menor), unit, previous_price? (unidad menor), price_changed_at?, archived, version, created_by, created_at |
| fiados | id, business_id, client_id, total (unidad menor), occurred_at, created_by, annulled_at?, annulled_by? |
| fiado_items | id, fiado_id, product_id?, description, quantity (milésimas), unit, unit_price (unidad menor), subtotal (unidad menor) |
| payments | id, business_id, client_id, amount (unidad menor), occurred_at, created_by, annulled_at?, annulled_by? |
| change_log | business_id, seq, entity_type, entity_id |
| sessions | id, user_id, access_token_hash (único), access_expires_at, refresh_token_hash (único), refresh_expires_at, created_at, revoked_at? |
| processed_ops | op_id (clave), business_id, result, processed_at |

Reglas del modelo:
- **Dinero**: siempre entero en la unidad menor (centavos de lempira), sin importar el modo del negocio. El modo solo restringe lo que se acepta y se muestra. Así pasar de enteros a decimales (RF-8) no migra nada.
- **Unidad de venta**: `unit` es el identificador estable de una unidad de la lista compartida (`unit` por omisión). Es solo una etiqueta (D-23): ni cambia el subtotal ni convierte entre unidades. Cada ítem de fiado copia la unidad al registrarse, igual que el precio. Los productos e ítems anteriores a esta enmienda quedan con la unidad por omisión.
- **Cantidades**: entero en milésimas. El modo del negocio decide si se aceptan fracciones.
- **Saldo**: nunca se guarda. Se calcula como suma de fiados vigentes menos suma de abonos vigentes del cliente (RF-40). Un saldo guardado sería un segundo dato que sincronizar y que podría divergir.
- **Fiado sin detalle** (RF-29): fiado con total y sin ítems. Con ítems, `total` es la suma de subtotales, calculada al crear y nunca recalculada (principio 4).
- **Anulación** (RF-43): campos `annulled_at` y `annulled_by` sobre el propio fiado o abono. No hay tabla de ediciones porque no hay ediciones (RF-46).
- **Cursor de sincronización**: cada negocio tiene un contador `last_seq`. Cada cambio aplicado incrementa el contador dentro de la misma transacción y escribe una fila en `change_log`. El contador se bloquea por negocio durante el push; a esta escala no es un cuello de botella y garantiza un orden sin huecos que el cursor pueda saltarse.
- **Idempotencia**: `processed_ops` guarda el ID de cada operación aplicada. Reenviar una operación devuelve el resultado original (RF-53).

### 3.2 Móvil (SQLite vía Drift)
- Las mismas tablas de negocio (clients, products, fiados, fiado_items, payments, businesses, memberships del usuario), todas con `business_id`, para permitir varios negocios en un dispositivo (RF-5).
- **outbox**: op_id, business_id, type, payload, estado (pendiente / enviada / rechazada), código de error, created_at.
- **sync_state**: business_id, cursor (último `seq` recibido).
- **session**: usuario, negocio activo, tokens (en almacenamiento seguro, no en la base).
- El saldo y el resumen son consultas sobre las tablas locales (RF-66).
- La base local pasa a la versión 2 al añadir `unit` a `products` y `fiado_items`: una migración que conserva los datos y deja la unidad por omisión en lo existente (D-23).
- La base local pasa a la versión 3 al añadir `previous_price` y `price_changed_at` (ambos nulos) a `products`: una migración que conserva los datos y deja los dos campos en nulo en lo existente (D-24).

## 4. Sincronización

### 4.1 Operaciones
Tipos: crear / editar / archivar / restaurar cliente; crear / editar / archivar producto; crear fiado; crear abono; anular fiado; anular abono. Cada operación lleva: `op_id` (GUID), tipo, id de la entidad, datos, fecha de creación en el dispositivo (UTC) y, si edita, la `version` base.

Las operaciones de cuenta, invitaciones, equipo y ajustes del negocio **no pasan por la cola**: son en línea y el servidor es la única autoridad (ver decisión D-3).

### 4.2 Push (móvil → servidor)
1. El móvil envía las operaciones pendientes en orden de creación.
2. El servidor, por cada una y dentro de una transacción por lote: comprueba pertenencia al negocio y rol (RF-13, 45, 48), comprueba idempotencia, valida las reglas del dominio y la aplica.
3. Responde por operación: **aplicada**, **duplicada** (se trata como aplicada) o **rechazada** con código y motivo.
4. El móvil marca las aplicadas y conserva las rechazadas visibles para el usuario (RF-56, RF-57).

### 4.3 Pull (servidor → móvil)
El móvil pide los cambios con `seq` mayor que su cursor, paginados. El servidor devuelve la versión actual completa de cada entidad cambiada. La primera vez el cursor es cero y equivale a la descarga inicial (RF-58, RNF-7).

### 4.4 Reglas de conflicto (RF-54, 55, 62)
| Situación | Resultado |
|---|---|
| Dos dispositivos crean fiados o abonos distintos del mismo cliente | Se aplican todos; el saldo es la suma |
| Dos dispositivos anulan el mismo movimiento | La segunda es idempotente |
| Un dispositivo edita una entidad con `version` anterior a la del servidor | Rechazada por conflicto; el servidor gana; el móvil la recibe por pull y descarta su edición pendiente avisando al usuario |
| Abono sobre un cliente cuyo fiado se anuló en otro dispositivo | Se aplica; el saldo puede quedar a favor (RF-47) |
| Cambio hecho desde la web | Es una operación más; llega al móvil por pull con las mismas reglas |
| Fiado registrado sin conexión a un cliente que otro dispositivo archivó | Se aplica; el cliente sigue archivado con el saldo actualizado (RF-85) |

### 4.5 Empleado removido (RF-11, 12)
Al quitarlo, su pertenencia pasa a *removida* y se pone `final_sync_used` en falso. En su siguiente sincronización el servidor acepta **un último lote**, sin límite de tiempo, y a continuación revoca el acceso; el móvil borra los datos locales de ese negocio. Si no sincroniza nunca, sus datos permanecen en su teléfono: es una limitación aceptada (RF-12, fuera de alcance el borrado remoto).

## 5. Contrato de la API (resumen)
No se implementa nada fuera de este contrato sin actualizar antes el plan.

| Grupo | Intención |
|---|---|
| Auth | Registrarse, iniciar sesión, renovar sesión, cerrar sesión |
| Negocios del usuario | Listar negocios con su rol, crear negocio nuevo, ver invitaciones pendientes, aceptarlas o rechazarlas |
| Negocio | Leer y cambiar ajustes (solo dueño), listar el equipo, invitar, cancelar invitación, promover, quitar |
| Sync | Enviar lote de operaciones; pedir cambios desde un cursor |
| Operaciones individuales (web) | Enviar una operación y recibir su resultado inmediato |
| Consultas (web) | Listar clientes con saldo, ver historial de un cliente, listar archivados, listar productos, resumen del negocio |

El negocio activo se indica en cada petición y el servidor comprueba siempre que el usuario pertenece a él. Los errores devuelven un código estable y los clientes lo traducen a mensajes en español (RNF-5).

## 6. Decisiones técnicas

| ID | Decisión | Por qué | Alternativa descartada |
|---|---|---|---|
| D-1 | Dinero como entero en unidad menor en las tres plataformas | Exactitud (RNF-2, principio 5) y sin migración al pasar de enteros a decimales | `decimal` en .NET y Dart: obliga a convertir entre plataformas y a una dependencia en Dart |
| D-2 | Redondeo "mitad hacia arriba" definido una vez (al entero con montos enteros, al centavo con 2 decimales) y verificado con vectores compartidos; cantidades con hasta 3 decimales | La misma cuenta debe dar el mismo resultado en móvil, servidor y web (RF-34, 83, 84) | Cada plataforma con su redondeo por defecto: los resultados divergen en los .5 |
| D-3 | Cuentas, negocios, invitaciones, equipo y ajustes solo en línea, fuera de la cola (RNF-1) | Dependen de la autoridad del servidor (último dueño, ajuste que no puede restringirse) y no son operaciones de mostrador | Encolarlas: permitiría estados imposibles al sincronizar (RF-9, RF-71) |
| D-4 | Una sola vía de escritura (operaciones) para móvil y web | Una sola implementación de reglas; menos superficie de API | Endpoints REST de escritura distintos para la web: duplica las reglas |
| D-5 | Cursor por negocio con contador bloqueado durante el push | Orden estable sin huecos; simple (principio 3) | Marca de tiempo como cursor: pierde cambios por relojes y transacciones simultáneas |
| D-6 | Saldo calculado, no guardado | Evita divergencias entre dispositivos | Saldo guardado y actualizado en cada movimiento: dato derivado que sincronizar |
| D-7 | Sin lápidas de borrado | Nada se borra (principio 11) | Borrado lógico con lápidas: complejidad sin necesidad |
| D-8 | Edición con control de versión por entidad; el servidor gana | Cumple el principio 3 sin fusionar campo a campo | Fusión por campos: complejidad no justificada para clientes y productos |
| D-9 | Autenticación por correo y contraseña; token de acceso corto y token de renovación largo guardado de forma segura | La invitación se asocia al correo y se muestra al iniciar sesión, así que no se necesita enviar correos (RF-10, 67) | Enlace mágico o código por correo: exige un proveedor de correo y no funciona bien con conectividad pobre |
| D-10 | Si el token de renovación caduca estando sin conexión, la app sigue funcionando y exige iniciar sesión solo para sincronizar; la cola no se pierde | RF-4 y RNF-1 | Cerrar la sesión local al caducar: perdería la cola |
| D-11 | Estado de la app móvil con Riverpod | Menos código repetido, fácil de probar sin UI (principio 7) | BLoC: más ceremonia; `setState`/Provider: no escala a varios módulos |
| D-12 | Dependencias móviles mínimas: Drift, Riverpod, `uuid`, `flutter_localizations` (paquete del SDK, para que los textos propios de Flutter salgan en español, RNF-5), cliente HTTP, almacenamiento seguro, detección de conectividad | Principio 9 | Frameworks de sincronización de terceros: opacos y con reglas de conflicto propias |
| D-13 | Sincronización del móvil al abrir la app, al recuperar conexión y manualmente; no en segundo plano en el MVP | Menor consumo y menor complejidad | Servicio en segundo plano: se evalúa después |
| D-14 | Web en Angular con Tailwind CSS, sin biblioteca de componentes | Ligera (principio 9) y coherente con el diseño actual del proyecto | Angular Material: más peso, estilo propio difícil de igualar al móvil |
| D-15 | Avatar como tres identificadores; las imágenes viajan dentro de cada aplicación | Payload mínimo y funciona sin conexión (RNF-7) | Imágenes en el servidor: requiere descarga y almacenamiento |
| D-16 | Despliegue con Docker Compose: API, PostgreSQL y web estática | AGENTS.md pide el backend en Docker | Plataformas administradas: decisión de costo que corresponde al usuario |
| D-17 | Clientes HTTP escritos a mano contra un contrato OpenAPI, validado con ejemplos compartidos | Sin generadores de código ni dependencias extra | Generar clientes: añade herramientas y plantillas |
| D-19 | El restablecimiento de contraseña es un comando del servidor, sin endpoint ni pantalla, que solo recibe el correo de la cuenta, deja la contraseña nueva y escribe en `admin_audit` | Mínima superficie de ataque; no hay rol de superadmin dentro de las apps (RF-81, 82) | Rol de superadmin en la web: otra funcionalidad con su propia spec |
| D-20 | Copia diaria de la base con `pg_dump` en un servicio del Compose, enviada fuera de la máquina, con rotación de 3 copias | Cumple RNF-8 con herramientas estándar y sin dependencias de código | Replicación de la base: más costo y complejidad que lo que pide la spec |
| D-21 | IDs generados en el cliente con el paquete `uuid`, UUID v7 (RFC 9562), desde un único generador inyectable; el servidor acepta cualquier GUID válido y puede generar los mismos con `Guid.CreateVersion7` de .NET | Estándar, ordenable por tiempo (mejor rendimiento de índices en PostgreSQL) y repositorios con generadores deterministas en los tests | Generador propio con `Random.secure`: mantenimiento y auditoría a nuestro cargo |
| D-22 | Integración continua con GitHub Actions: tests de api, mobile y web en cada PR hacia `develop` y `main`, con un job final `ci-ok` exigible como comprobación obligatoria | Principio 8 (tests como puerta) aplicado también a la fusión de PR | Comprobar solo en local: depende de la disciplina de cada persona |
| D-23 | La unidad de venta es una etiqueta de una lista fija con identificadores estables; el producto y cada ítem de fiado llevan una (la del ítem es copia de la del producto, editable solo para ese ítem). No hay conversiones ni reglas de cantidad por unidad | Las pulperías venden por libra, docena, etc., y basta con mostrar en qué se contó; sin conversiones no hay inventario ni dinero que redondear distinto (RF-89) | Convertir entre unidades: reglas nuevas en las tres plataformas y cerca del inventario, fuera de alcance. Unidad como texto libre: validación y sincronización sin beneficio claro. Reglas de decimales por unidad: contradice RF-35 y RF-84 |
| D-24 | El precio anterior de un producto y la fecha del cambio viven en el propio producto (`previous_price`, `price_changed_at`), no en una lista de historial: cada cambio de precio reemplaza al anterior. Lo calcula el servidor al aplicar `product.update` con un precio distinto del vigente (la fecha es la de creación de la operación, como en D-18); un cambio que no toca el precio no los modifica. La operación de la cola no cambia; la respuesta de sincronización y las consultas de productos incluyen los dos campos (cambio aditivo del contrato). El aviso de producto repetido (RF-91) es solo del cliente y no lo exige el servidor | Es lo que se pidió (solo el anterior), no cambia las operaciones y los ítems fiados ya sirven de historial de lo cobrado | Tabla de historial completo: más trabajo en móvil, API y web sin necesidad en el MVP |
| D-25 | Persistencia de la API con EF Core y PostgreSQL, y pruebas de integración contra un PostgreSQL real. Dependencias NuGet aprobadas el 2026-10-08: `Npgsql.EntityFrameworkCore.PostgreSQL` (proveedor, trae `Microsoft.EntityFrameworkCore`) y `Microsoft.EntityFrameworkCore.Design` (solo diseño, con `PrivateAssets=all`, para generar migraciones con `dotnet ef`) en `Pulperia.Infrastructure`, y `Testcontainers.PostgreSql` solo en `Pulperia.Tests`. Sin más librerías de mapeo, nombres ni aserciones. Diseño: clases de persistencia propias en Infrastructure, separadas de los `record` del dominio y con mapeo explícito (el dominio no conoce EF); ids `uuid`, dinero en `bigint` en la unidad menor y fechas en `timestamptz` UTC; columnas en `snake_case` con una convención propia pequeña; todas las tablas de negocio con `business_id` y claves foráneas compuestas `(id, business_id)` (RNF-6); una migración por tarea, la inicial en T051, aplicadas al arrancar para que `docker compose up` deje la base migrada (T136); `password_hash` es solo una columna, la librería de hash se decide al llegar a las cuentas (T063). Las pruebas de integración llevan una categoría y `dotnet test api` las ejecuta todas: necesitan Docker en marcha, y el CI (`ubuntu-latest`) ya lo trae | Cumple el principio 8 (tests contra la base real, no contra un simulacro), el 7 (dominio sin EF) y el 9 (pocas dependencias); Testcontainers deja una base limpia en cada ejecución sin pasos manuales | Un PostgreSQL de Compose arrancado a mano con la cadena de conexión por variable de entorno: evita un paquete, pero deja datos entre ejecuciones y obliga a configurar un contenedor de servicio aparte en el CI; SQLite o base en memoria de EF: no reproducen PostgreSQL y esconden errores de migración |
| D-26 | El servidor aplica topes holgados a fiados y abonos como defensa contra desbordamientos y datos absurdos, sin cambiar lo que el móvil permite hoy: monto, precio unitario, subtotal, total y abono ≤ L 9,999,999.99 (999 999 999 en la unidad menor); cantidad de un ítem ≤ 1,000,000 (1 000 000 000 milésimas); ≤ 200 ítems por fiado; descripción de un ítem ≤ 200 caracteres. Pasar un tope rechaza la operación con un código estable (`amount_too_large`, `quantity_too_large`, `too_many_items`, `description_too_long`), y los topes se comprueban antes de calcular nada, de modo que ningún producto de cantidad por precio desborda `bigint`. Además, el servidor exige que el subtotal de cada ítem coincida con cantidad por precio redondeado como el negocio (o, con montos de 2 decimales, como los enteros, por si el dueño cambió el modo mientras el dispositivo estaba sin conexión) y que el total sea la suma de los subtotales (`subtotal_mismatch`, `total_mismatch`); el subtotal que manda el dispositivo es el registro histórico (principio 4). El móvil y la web no validan los topes: sus pantallas no llegan a esos valores | La spec no define topes y el plan pedía una sola implementación de reglas (D-4); sin topes, un payload malicioso o con un error provoca desbordamiento aritmético o filas absurdas, y el rechazo ocurre antes de guardar nada | Solo anti-desbordamiento: acepta fiados de billones y descripciones sin límite. Topes compartidos con móvil y web con vectores en `shared/`: más coherente pero toca la spec, los vectores y las pantallas, sin necesidad hoy |
| D-27 | Contraseñas y sesiones sin paquetes nuevos (se cierra la elección de D-9). **Contraseña**: PBKDF2-HMAC-SHA256 del BCL (`Rfc2898DeriveBytes.Pbkdf2`) con sal aleatoria de 16 bytes, 600 000 iteraciones y hash de 32 bytes, guardado como `pbkdf2-sha256$iteraciones$sal$hash` en `users.password_hash`; la comparación es de tiempo constante y un hash con menos iteraciones que las vigentes se renueva en el siguiente inicio de sesión. Longitud de 8 a 128 caracteres, sin más reglas de composición; el correo se recorta, se pasa a minúsculas y debe tener forma básica de dirección (`algo@algo`). **Tokens**: opacos, de 32 bytes aleatorios en base64url; en la base solo se guarda su hash SHA-256 (tabla `sessions`, una fila por sesión de un dispositivo), nunca el token. Acceso de 15 minutos y renovación de 90 días; renovar reemplaza ambos tokens de la fila (rotación) y el de renovación anterior deja de servir; cerrar sesión pone `revoked_at`. Cada petición autenticada busca el token de acceso por su hash y comprueba que no esté revocado ni caducado; luego, con la cabecera `X-Business-Id`, que el usuario sea miembro activo de ese negocio (RF-50), así que quitar a un empleado surte efecto en la siguiente petición salvo su último lote (RF-12, T081). Las respuestas de error llevan un código estable en JSON (`{ "code": "..." }`); el inicio de sesión no distingue entre correo desconocido y contraseña errónea (`invalid_credentials`). Añade una migración (`Sesiones`) | Cero dependencias nuevas (principio 9), revocación inmediata al cerrar sesión o quitar a alguien, y un token robado de la base no sirve porque solo hay hashes. PBKDF2 con esas iteraciones es el mínimo recomendado por OWASP para SHA-256 y viene en el BCL | JWT con `JwtBearer`: valida sin consultar la base pero no se revoca hasta caducar y añade un paquete. Argon2: más resistente, pero exige un paquete de terceros |
| D-28 | Cada invitación lleva un **código de un solo uso** de 8 caracteres de un alfabeto de 31 símbolos sin ambiguos (sin 0/O/1/I/L), generado con `RandomNumberGenerator`, único en toda la tabla `invitations` y guardado en claro en `invitations.code` (el dueño tiene que poder volver a verlo; vale solo mientras la invitación esté pendiente y se pierde al aceptarse o cancelarse). Se muestra como `XXXX-XXXX`; al canjear se ignoran mayúsculas, espacios y guiones. El dueño puede invitar **con correo** (como hasta ahora: el invitado la ve al iniciar sesión con ese correo) **o sin correo** (`email` nulo; solo se activa con el código); ambas llevan código. `POST /api/invitations/redeem { code }`, con sesión pero sin negocio activo, agrega a la persona como empleado (RF-93) con la misma transacción que aceptar, y reutiliza el estado `accepted`; el listado del dueño (`GET /api/business/invitations`) y la respuesta de crear devuelven el código, y `GET /api/invitations` del invitado no lo devuelve. Un código inexistente, usado o de una invitación cancelada da el mismo error (`invalid_invitation_code`, 404) sin revelar el negocio. Se limitan los canjes a 10 por minuto por usuario con el limitador de peticiones que trae ASP.NET (`Microsoft.AspNetCore.RateLimiting`, sin paquetes nuevos), lo que hace inviable adivinar un código (31^8 ≈ 8.5 × 10^11). Migración `CodigoDeInvitacion`: añade `code` (las invitaciones existentes reciben uno), vuelve opcional `email` y su restricción de formato | Cumple lo pedido (activar sin depender del correo, entregando el código por otro medio) con lo mínimo: el correo sigue siendo el camino principal, el código es un segundo camino sobre la misma tabla y las mismas reglas de aceptación, y no se envía ningún correo (D-9). El código en claro es aceptable porque es de un solo uso, caduca al resolverse la invitación y solo lo ve el dueño | Código con hash: el dueño no podría volver a verlo. Canje sin sesión: crearía cuentas implícitas. Un panel o comando del administrador del servidor que vea códigos: choca con RF-82 (el administrador no ve datos de negocios). Caducidad por tiempo: queda fuera de alcance (RF-10) |
| D-29 | **Super administrador de la plataforma**, con el alcance "plataforma sin ver fiados". **Identidad**: una cuenta normal con `users.is_super_admin`, que solo cambia con los comandos del servidor `admin grant-superadmin <correo>` y `admin revoke-superadmin <correo>` (este último se niega si es el único; ambos escriben en `admin_audit`); no existe ninguna ruta ni pantalla para marcar a nadie. **Sesiones**: la renovación de un super administrador dura 12 horas en vez de 90 días y el acceso sigue siendo de 15 minutos; cada petición a `/api/admin` comprueba en la base que la cuenta siga marcada y no suspendida. **Rutas** (`/api/admin`, nunca con `X-Business-Id`): `GET /businesses?search&page` y `GET /businesses/{id}` (nombre, correos de los dueños, número de miembros, fecha de alta, estado, última sincronización calculada como el `processed_at` más reciente del negocio y conteos de clientes, productos, fiados y abonos), `POST /businesses/{id}/suspend {reason}` y `/reactivate`, `GET /accounts?search&page` y `GET /accounts/{id}`, `POST /accounts/{id}/suspend {reason}`, `/reactivate` y `/reset-password`, y `GET /audit?page`. Las respuestas se arman con consultas agregadas dedicadas (conteos y fechas): ninguna consulta de administración lee nombres de clientes ni de productos ni montos, y una prueba lo verifica inspeccionando todos los campos devueltos. **Suspensión**: `suspended_at` y `suspension_reason`; un negocio suspendido responde `business_suspended` (403) en `RequireBusiness`, en el envío de lotes y en el pull, sin tocar sus datos ni su cola en los teléfonos (que siguen funcionando sin conexión y envían al reactivarse); una cuenta suspendida no puede iniciar sesión (`account_suspended`, 403) y sus sesiones se cierran al suspenderla. **Auditoría**: `admin_audit` se amplía con las acciones nuevas, `target_business_id` y `detail` (el motivo), y `target_user_id` pasa a ser opcional; cada acción de la API de administración se audita en la misma transacción que la hace y el registro solo se agrega (disparadores anti edición y borrado, como en los fiados). **Panel**: una ruta aparte `/admin` del cliente Angular, solo visible con la marca; las apps de las pulperías no la incluyen. **Constitución**: el principio 6 se aclara (la administración de la plataforma solo ve metadatos y cifras agregadas, jamás datos de un negocio), con aprobación del usuario. Migración `SuperAdministrador`. Sin paquetes nuevos | Da el control de la plataforma que se pidió (ver, suspender, dar soporte de cuentas, auditar) sin romper la privacidad de cada pulpería (principio 6, RF-82) ni la trazabilidad (principio 11), reutiliza el inicio de sesión y las sesiones de D-27 y mantiene la superficie de ataque pequeña: marcar a alguien exige acceso al servidor | Soporte de solo lectura de los datos de un negocio y control total: más riesgo de seguridad y de confianza, rechazados por el usuario. Cuentas de administrador separadas: otro inicio de sesión y otra tabla sin beneficio claro. Rol dentro de las mismas apps: mezcla dos mundos y amplía la superficie. Autenticación de dos factores: queda fuera del MVP |
| D-30 | **Activación de negocios nuevos**, que complementa a D-29 y sustituye sus columnas de suspensión del negocio. El negocio tiene un estado `businesses.status` (`pending`, `active`, `suspended`) con `status_reason` opcional, en vez de las columnas de suspensión de D-29 (las de cuentas, `users.suspended_at`, no cambian). **Nacimiento**: el negocio creado por el registro (T063) nace `pending`; uno creado con `POST /api/businesses` nace `active` si quien lo crea ya es dueño de algún negocio `active`, y `pending` si no (RF-104); la migración deja `active` los negocios existentes. **Transiciones válidas** (regla de dominio probada): `pending → active` (activar), `pending → suspended` (rechazar, con motivo), `active → suspended` (suspender, con motivo), `suspended → active` (reactivar); cualquier otra se rechaza. **Efecto**: un negocio `pending` o `suspended` responde 403 `business_pending` o `business_suspended` en `RequireBusiness`, en el envío de lotes y en el pull; no se pierde ni se edita ningún dato, y la cuenta del dueño inicia sesión y usa sus otros negocios con normalidad. `GET /api/businesses` devuelve el `status` de cada negocio para que las apps muestren el aviso. **Panel**: `GET /api/admin/businesses?status=pending` y `POST /api/admin/businesses/{id}/activate`; suspender y reactivar siguen como en D-29; la auditoría añade la acción `activate_business`. No se envía ningún correo (D-9): el dueño ve el estado al abrir la app. Migración `EstadoDeNegocio` (parte de T186) | Da el control de quién usa la plataforma que se pidió sin bloquear a quien solo quiere entrar como empleado a otro negocio, y reutiliza el mecanismo de suspensión en vez de crear otro | Bloquear toda la cuenta hasta activarla: impide que alguien se registre solo para ser empleado. Registro solo por invitación del super administrador: más fricción y más trabajo de panel. Que los negocios adicionales también nazcan pendientes: más revisiones manuales sin beneficio |
| D-31 | **Paquetes de la Fase 8 del móvil** (concreta las categorías de D-12). Dependencias aprobadas el 2026-10-09 en `mobile/`: `http` (cliente HTTP oficial de Dart; sus tests usan `MockClient` del propio paquete), `flutter_secure_storage` (el token de acceso y el de renovación viven en el Keystore de Android y el llavero de iOS, nunca en la base de Drift, plan 3.2) y `connectivity_plus` (aviso de que volvió la red, para el disparador de T095). Las versiones se fijan con `^` al instalarlas. Reglas de uso: el cliente HTTP se escribe a mano contra `shared/openapi.json` (D-17) detrás de una interfaz propia que los tests sustituyen; `connectivity_plus` solo dice si hay una interfaz de red, no si el servidor responde, así que un envío que falle sigue el camino de T094 (la cola se conserva y se reintenta); el acceso a internet se declara en el manifiesto de Android y el tráfico sin cifrar (`http://`) solo se permite en las compilaciones de depuración: una compilación de producción exige `https://` (la dirección del servidor se decide en la Fase 11). Sin más paquetes de red, de estado de sesión ni de reintentos | Los tres son los de uso estándar en Flutter, con mantenimiento activo, y cubren exactamente lo que piden T087, T088 y T095 sin añadir capas (principio 9). Guardar los tokens en el almacenamiento seguro del sistema evita que un respaldo o una lectura de la base los exponga | `HttpClient` de `dart:io`: no añade paquete, pero obliga a un servidor falso propio en los tests y a más código de bajo nivel. `dio`: trae interceptores y reintentos que no hacen falta (la sincronización ya tiene su propia lógica de reintento). Tokens en `shared_preferences` o en la base: sin cifrar. Detectar la red haciendo ping al servidor: gasta datos y batería sin necesidad |
| D-32 | **Registro con código de invitación** (complementa a D-28 y RF-1). `POST /api/auth/register` acepta **una de dos formas**: la de siempre (`email`, `password`, `businessName`, `amountMode`, `quantityMode`) o la de una persona invitada (`email`, `password`, `invitationCode`, sin datos de negocio). Con las dos mezcladas responde 400 `registration_ambiguous` (RF-107); sin negocio ni código sigue dando `business_name_required` (RF-78). La forma con código es **una sola transacción**: valida que el código esté pendiente, crea el usuario, crea la membresía de empleado y marca la invitación `accepted` (la misma lógica de aceptar de D-28, sin duplicarla); si algo falla (código inválido, correo ya registrado) no se crea nada y el código **no se consume**. Código inexistente, usado o cancelado: el mismo `invalid_invitation_code` de D-28 (404) sin revelar el negocio. Como todavía no hay usuario, el límite de intentos del código (10 por minuto de D-28) se aplica **por origen de la conexión** con el mismo limitador de ASP.NET (sin paquetes nuevos). La respuesta es la de siempre (`userId`, `businessId`, este último el del negocio al que entró) y sigue sin devolver tokens: la app inicia sesión a continuación. La cuenta no es dueña de nada y por eso no tiene negocio pendiente (RF-102 no aplica); si luego crea un negocio propio nace `pending`, porque no es dueña de ninguno activo (RF-104, D-30). Si el negocio invitado está pendiente o suspendido, entra igualmente y verá el aviso de D-30. En el móvil y la web el registro ofrece la opción «Me invitaron con un código», que oculta el nombre del negocio y sus modos y pide el código; sin conexión no se puede, igual que cualquier registro (RF-3). El código canjeado en el registro no cambia nada para quien ya tiene cuenta: sigue canjeando desde elegir negocio (RF-93) | Quien solo viene a trabajar como empleado no tiene que inventar un negocio ni quedar como dueño de un negocio sobrante; y el canje sigue exigiendo una identidad (la que se crea en el mismo acto), así que no hay cuentas implícitas | Registrar primero con negocio y canjear después (dejaba un negocio sobrante pendiente). Registro sin negocio y sin código (cuentas vacías que nadie pidió). Canje de código sin cuenta (descartado en D-28). Un código de activación emitido por el super administrador para poder registrarse: no se incluye; D-30 lo descartó por la fricción de panel y no cambia lo que hoy controla el super administrador, que es qué negocios se activan |
| D-18 | Historial ordenado por la fecha de creación del dispositivo, con desempate por orden de llegada al servidor | Refleja cuándo ocurrió la venta aunque se sincronice tarde | Orden por llegada al servidor: confundiría al usuario con ventas hechas sin conexión |

## 7. Estrategia de tests
Principio 8: tests primero y todo en verde antes de avanzar.

| Nivel | Qué cubre | Herramientas |
|---|---|---|
| Dominio (unitarios, sin UI ni red) | Dinero y redondeo, saldo, validaciones (nombre, teléfono, nota, montos, cantidades), permisos por rol, reglas de ajustes | xUnit; `flutter test`; `ng test` |
| Vectores compartidos | `shared/` ejecutado por las tres plataformas: redondeo, saldo, teléfono, resumen | Los mismos JSON en los tres proyectos |
| Persistencia local | Consultas de saldo, archivado, anulación sobre base en memoria | Drift con base en memoria |
| Integración API | Aplicación de operaciones contra PostgreSQL real: idempotencia, conflictos, aislamiento entre negocios, rol, cursor, empleado removido | xUnit + contenedor PostgreSQL de pruebas |
| Sincronización de extremo a extremo | Dos "dispositivos" simulados: fiados concurrentes, edición en conflicto, corte a medio lote, descarga inicial | Pruebas de integración con el dominio real de móvil y API |
| Web | Servicios y reglas de lectura; comportamiento sin conexión | `ng test` |
| Administración | Comando de restablecimiento: cambia la contraseña, escribe la auditoría y no expone datos de negocios | xUnit sobre la capa de aplicación |
| Respaldo | La copia se genera, rota a 3 y se restaura en una base vacía | Script de verificación en el despliegue |
| Manuales | Los 9 demos de "Criterios de finalización" de la spec | Lista de comprobación |

## 8. Cobertura de RF por módulo
| RF | Dónde se cubre |
|---|---|
| 1–6, 78–80 | Identity y Businesses (API), Session y Business admin (móvil), Core services y equipo y ajustes (web) |
| 7–9 | Businesses (API), Business admin (móvil), equipo y ajustes (web) |
| 10–13, 67–71, 92–94 | Invitations (API), Business admin (móvil), equipo y ajustes (web), §4.5 |
| 81–82 | Admin tooling, D-19 |
| 95–104 | Admin tooling, Platform admin, panel web de administración, D-29, D-30 |
| 105–107 | Identity (API), Session y Business admin (móvil), Core services (web), D-32 |
| RNF-8 | Backups, D-20 |
| 14–23, 72–77, 85 | Clients, Avatar, vectores de teléfono, §4.4 |
| 24–27, 86 | Catalog, lista de unidades en shared/ |
| 28–39, 83–84, 87–89 | Ledger, Domain (dinero, redondeo y unidades) |
| 40–42 | Domain (saldo), Local store |
| 43–47 | Ledger, §4.4 |
| 48–50 | Permisos en Domain y comprobación en servidor, aislamiento por `business_id` |
| 51–58 | Local store, Outbox, Sync (móvil y API), §4 |
| 59–62 | Web hosting y Feature modules de web, §4.4 |
| 63–66 | Reports (API), Summary (móvil), vectores compartidos |

## 9. Brechas detectadas en la spec (todas resueltas)
Se detectaron al planificar y se resolvieron con el usuario el 2026-10-02. La spec se actualizó con su aprobación.

| ID | Brecha | Resolución | Dónde quedó |
|---|---|---|---|
| G-1 | No había recuperación de contraseña | Fuera del MVP para el usuario; el administrador del servidor la restablece con una operación manual, con auditoría y sin acceso a datos de negocios | RF-81, RF-82, D-19, fuera de alcance |
| G-2 | El negocio no tenía nombre | Nombre obligatorio al crear y editable por los dueños; se añadió crear un negocio adicional | RF-1, RF-78 a RF-80 |
| G-3 | Faltaba el redondeo con montos decimales y el máximo de decimales de la cantidad | Redondeo al centavo (.5 sube); cantidad con hasta 3 decimales | RF-83, RF-84, D-2 |
| G-4 | Fiado sin conexión a un cliente archivado por otro dispositivo | Se acepta; el cliente sigue archivado con el saldo actualizado | RF-76, RF-85 |
| G-5 | Redacción de RF-47 incoherente con abonos generales | Reescrita | RF-47 |
| G-6 | RNF-1 decía "toda" la funcionalidad sin conexión | Acotado: cuentas, negocios, invitaciones, equipo y ajustes requieren conexión | RNF-1, D-3 |
| G-7 | Empleado removido sin sincronizar | Su último lote se acepta sin caducidad; el borrado remoto queda fuera de alcance | RF-12, §4.5 |
| G-8 | Respaldo del propio servidor | Copia diaria fuera de la máquina, con rotación de 3 | RNF-8, D-20 |

Pendiente de definir al desplegar: el destino concreto de las copias [NECESITA ACLARACIÓN: ¿dónde se guardan las copias fuera del servidor?].

## 10. Riesgos
- **Reloj del dispositivo**: el orden del historial depende de él. Un reloj mal ajustado altera el orden, no los saldos.
- **Rechazos tras trabajar sin conexión**: si cambian los permisos de un usuario mientras está desconectado, sus operaciones pueden rechazarse al sincronizar. Se muestran en la app para que el usuario las revise.
- **Rendimiento del resumen en móviles modestos**: es una consulta agregada sobre la base local; se mide en la validación con un volumen de prueba [NECESITA ACLARACIÓN: ¿cuántos clientes y movimientos debe soportar cómodamente un negocio típico?].

## 11. Fuera de este plan
Las tareas (<30 min, con RF y "Hecho cuando"), la planificación por fases del despliegue y cualquier código. Siguiente fase: tareas, una vez aprobado este plan.
