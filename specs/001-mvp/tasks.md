# Tareas 001 — MVP: administrador de deudas (fiados) para pulperías

Estado: BORRADOR, pendiente de aprobación. Deriva de `plan.md` (aprobado) y cubre `spec.md` (RF-1 a RF-104, RNF-1 a RNF-8).

## Cómo se trabaja
- **Una unidad de trabajo es un bloque** de tareas relacionadas, con una rama y un PR. Se trabaja el bloque entero, tarea a tarea, y se para al cerrarlo (en el paso del PR) o antes si algo bloquea: un test que no pasa, una laguna de la spec, una dependencia no aprobada o una tarea de más de 30 minutos.
- **Tests primero** en cada tarea: se escriben los tests, se ven fallar, se implementa y se ejecuta la suite del proyecto tocado. Una tarea no se marca hecha con la suite en rojo.
- Cada tarea cabe en menos de 30 minutos. Si una crece, se divide antes de seguir.
- Las tareas van en orden de dependencia. Salvo que se indique `Dep:`, cada tarea depende solo de las anteriores de su fase y las fases dependen de las anteriores.
- **Un commit por tarea**, en Conventional Commits con el scope que corresponda (`api`, `mobile`, `web`, `specs`, `docs`, `repo`), con la casilla de la tarea marcada en ese mismo commit.
- El PR del bloque se fusiona con "rebase and merge" para conservar un commit por tarea, y solo con CI en verde. Las tareas delicadas (sincronización, permisos, API/servidor, seguridad, migraciones) llevan rama y PR propios.
- Los vectores de `shared/` se leen desde los tests de cada plataforma; ninguna plataforma redefine esos casos.

## Bloqueos externos
- **T140**: necesita que decidas dónde se guardan las copias fuera del servidor.

## Fase 0 — Andamiaje
- [x] **T001** Crear la solución .NET en `api/` con proyectos Domain, Application, Infrastructure, Api y Tests. RF: —. *Hecho cuando:* `dotnet test api` ejecuta y pasa con un test de humo.
- [x] **T002** Crear el proyecto Flutter en `mobile/`. RF: —. *Hecho cuando:* `flutter test` (en `mobile/`) pasa con un test de humo.
- [x] **T003** Crear el proyecto Angular en `web/` con Tailwind CSS. RF: —. *Hecho cuando:* `ng test` (en `web/`) pasa con un test de humo.
- [x] **T004** Completar la sección "Comandos" de `AGENTS.md` con los comandos reales. RF: —. Dep: T001–T003. *Hecho cuando:* cada comando listado se ejecutó con éxito.
- [x] **T005** Crear `shared/` con un README que describe el formato de los vectores (entrada y salida esperada) y cómo los lee cada plataforma. RF: —. *Hecho cuando:* el README existe y define el formato con un ejemplo.

## Fase 1 — Datos compartidos (`shared/`)
- [x] **T006** Vectores de subtotal con montos enteros. RF: 34. *Hecho cuando:* incluye al menos 10 casos: .5 que sube, 0.25×30, cantidad entera, 0.499, valores grandes.
- [x] **T007** Vectores de subtotal con 2 decimales. RF: 83. *Hecho cuando:* incluye al menos 10 casos, entre ellos 0.333×12.50 y .5 de centavo.
- [x] **T008** Vectores de saldo. RF: 39, 40, 42, 44, 47. *Hecho cuando:* cubre solo fiados, fiados con abonos, abono mayor que la deuda, movimientos anulados y fiado anulado con abonos.
- [x] **T009** Vectores de teléfono. RF: 77. *Hecho cuando:* los válidos incluyen 90000000, 80000000, 30000000 y 20000000, y los inválidos cubren 7 y 9 dígitos, prefijos 1/4/5/6/7, letras y espacios.
- [x] **T010** Vectores de resumen. RF: 63, 64, 65. *Hecho cuando:* cubre saldos positivos, saldo a favor, clientes archivados excluidos y empates en el orden.
- [x] **T011** Paleta de avatares. RF: 72. *Hecho cuando:* define exactamente 24 personajes, 6 tonos y 12 fondos con identificadores estables.
- [x] **T012** Vectores de validación de cliente. RF: 15, 17, 74. *Hecho cuando:* cubre nombre vacío, nota de 300 y 301 caracteres, y homónimos que difieren en mayúsculas y espacios exteriores.
- [x] **T013** Vectores de modos de negocio. RF: 8, 9, 32, 35, 36, 84. *Hecho cuando:* cubre las transiciones permitidas y prohibidas, y montos o cantidades válidos e inválidos por modo, incluida una cantidad con 4 decimales.

## Fase 2 — Dominio del móvil (Dart, sin UI ni red)
- [x] **T014** Tipo de dinero en unidad menor (suma, resta, comparación). RF: —; RNF-2. *Hecho cuando:* tests en verde y ninguna aparición de `double` en el dominio de montos.
- [x] **T015** Tipo de cantidad en milésimas y su lectura. RF: 84. Dep: T013. *Hecho cuando:* pasan los vectores de cantidad.
- [x] **T016** Subtotal con montos enteros. RF: 34. Dep: T006, T014, T015. *Hecho cuando:* pasan todos los vectores de T006.
- [x] **T017** Subtotal con 2 decimales. RF: 83. Dep: T007. *Hecho cuando:* pasan todos los vectores de T007.
- [x] **T018** Validación de montos y cantidades según los modos del negocio. RF: 32, 35, 36. Dep: T013. *Hecho cuando:* pasan los vectores de modos.
- [x] **T019** Reglas de cambio de ajustes del negocio. RF: 8, 9. Dep: T013. *Hecho cuando:* enteros→decimales se acepta y decimales→enteros se rechaza, en montos y en cantidades.
- [x] **T020** Validación de fiado (con ítems, solo total, vacío, valores en cero o negativos). RF: 28, 29, 32, 33. Dep: T016–T018. *Hecho cuando:* cada caso devuelve el error esperado, y un fiado con ítems conserva cantidad y precio de cada uno.
- [x] **T021** Validación de abono. RF: 37, 38. Dep: T014. *Hecho cuando:* un abono de cero o negativo se rechaza.
- [x] **T022** Cálculo de saldo. RF: 39, 40, 42, 44, 47. Dep: T008. *Hecho cuando:* pasan los vectores de saldo.
- [x] **T023** Validación de cliente (nombre, avatar completo, nota, teléfono). RF: 15, 16, 74, 77. Dep: T009, T011, T012. *Hecho cuando:* pasan los vectores correspondientes.
- [x] **T024** Detección de homónimo. RF: 17. Dep: T012. *Hecho cuando:* los homónimos se detectan ignorando mayúsculas y espacios exteriores.
- [x] **T025** Matriz de permisos por rol. RF: 13, 21, 45, 48. *Hecho cuando:* el empleado no puede anular, archivar, gestionar equipo ni ajustes, y puede el resto; el dueño puede todo.
- [x] **T026** Resumen del negocio. RF: 63, 64, 65. Dep: T010, T022. *Hecho cuando:* pasan los vectores de resumen.
- [x] **T027** Orden del historial por fecha del dispositivo con desempate estable. RF: 41. *Hecho cuando:* dos movimientos con la misma fecha salen siempre en el mismo orden.
- [x] **T028** Composición y validación de avatar. RF: 14, 72. Dep: T011. *Hecho cuando:* rechaza identificadores fuera de la paleta.

## Fase 3 — Base local y cola del móvil (Drift)
- [x] **T029** Esquema local de negocios, pertenencias, clientes y productos, todos con `business_id`. RF: 51. *Hecho cuando:* una base en memoria se crea y guarda un registro de cada tabla.
- [x] **T030** Esquema local de fiados, ítems de fiado y abonos. RF: 51. *Hecho cuando:* se guardan y se leen con sus relaciones.
- [x] **T031** Esquema local de la cola (outbox) y del cursor de sincronización. RF: 51, 57. *Hecho cuando:* se guardan operaciones con su estado (pendiente, enviada, rechazada).
- [x] **T032** Repositorio de clientes: crear y editar, encolando la operación en la misma transacción. RF: 14, 19, 51. Dep: T023, T031. *Hecho cuando:* si falla el encolado, no queda el cliente guardado.
- [x] **T033** Repositorio de clientes: archivar y restaurar, listas normal y de archivados. RF: 20, 22, 23. *Hecho cuando:* un archivado sale de la lista normal, aparece en archivados con su saldo y vuelve al restaurarlo.
- [x] **T034** Repositorio de productos: crear, cambiar precio, archivar; sin borrar. RF: 24, 25, 26, 27. *Hecho cuando:* cambiar el precio no altera ítems ya guardados y archivar no los borra.
- [x] **T035** Repositorio de fiados: crear con ítems o solo total. RF: 25, 28, 29, 31, 49, 51. Dep: T020. *Hecho cuando:* el fiado y su operación se guardan juntos, con el usuario que lo registró; un ítem sin producto del catálogo se acepta.
- [x] **T036** Repositorio de fiados: rechazo para clientes archivados. RF: 76. *Hecho cuando:* el intento falla con el error esperado y no deja operación en la cola.
- [x] **T037** Repositorio de abonos: crear, también para clientes archivados. RF: 37, 75. Dep: T021. *Hecho cuando:* un abono a un archivado se guarda y reduce su saldo.
- [x] **T038** Anulación de fiados y abonos con usuario y fecha. RF: 43, 44, 45, 46, 49. Dep: T025. *Hecho cuando:* el movimiento anulado se conserva, no cuenta en el saldo, el empleado no puede anular y no existe operación de borrar ni de editar.
- [x] **T039** Consultas de saldo e historial. RF: 40, 41, 42. Dep: T022, T027. *Hecho cuando:* el historial incluye anulados marcados y el saldo negativo se identifica como saldo a favor.
- [x] **T040** Consulta del resumen sobre datos locales. RF: 66. Dep: T026. *Hecho cuando:* incluye cambios aún no sincronizados.

## Fase 3a — Proceso e ids
- [x] **T152** Integración continua en GitHub Actions (D-22). RF: —. *Hecho cuando:* `.github/workflows/ci.yml` se dispara en pull_request y push hacia `develop` y `main`; ejecuta los jobs api (`dotnet test api`), mobile (`flutter pub get`, código de Drift al día con `build_runner` y `git diff --exit-code`, `flutter analyze`, `flutter test`) y web (`pnpm install --frozen-lockfile`, `pnpm test --watch=false`, `pnpm build`) solo si cambian sus rutas; un job final `ci-ok` siempre se ejecuta y falla si falla alguno; las acciones de terceros van fijadas por SHA y los permisos son `contents: read`; existe `.github/pull_request_template.md`; y una ejecución real termina en verde.
- [x] **T153** Generador de ids UUID v7 (D-21). RF: —. Dep: D-21. *Hecho cuando:* una función única `newId()` en `mobile/lib/data/` devuelve UUID v7 en minúsculas con el paquete `uuid`, y los tests comprueban formato válido, versión 7 y variante correctas, 100 000 ids sin repetirse y orden creciente por tiempo; y los repositorios existentes reciben el generador por inyección, con generadores deterministas en sus tests.

## Fase 3b — Tramo de prueba del móvil, sin servidor (para probar la app pronto)
Orden de ejecución por bloques: A (T153, T040a, T040b), B (T100, T101, T102, T104), C (T106, T107, T108), D (T109 a T112 y T115), la Fase 3c (unidades de venta) y E (T040c, que está al final de la Fase 3c). Tras la prueba manual se añadió la Fase 3d (fiar rápido). Lleva a esta altura las pantallas de clientes, fiados, abonos y catálogo, que antes estaban en la Fase 9, para poder usar la app en el emulador, en modo avión, antes de construir la API. Se usa un negocio y un usuario de desarrollo fijos (T040a) que T088 reemplaza por la sesión real. Las tareas T100, T101, T102, T104, T106 a T112 y T115 se movieron aquí sin cambiar su contenido; solo se les añadió `Dep:`.

- [x] **T040a** Sesión simulada solo para desarrollo: un negocio de prueba y un usuario dueño, con los modos de montos y cantidades definidos por constantes. RF: —. Dep: T040. *Hecho cuando:* en depuración la app arranca con ese negocio y usuario activos, y un test comprueba que en modo release no están disponibles. Se elimina en T088.
- [x] **T040b** Cableado de la app: añadir Riverpod (D-11) y los proveedores de la base local, del negocio activo y del usuario activo. RF: —. Dep: T040a, T153. *Hecho cuando:* los ids se generan con `newId()` y un test de widget lee el negocio activo desde un `ProviderScope` con una base en memoria.
- [x] **T100** Navegación, tema y textos en español. RF: —; RNF-5. Dep: T040b. *Hecho cuando:* ninguna cadena visible está en otro idioma y la navegación llega a cada sección.
- [x] **T101** Widget de avatar compuesto (personaje, tono y fondo). RF: 14, 72. Dep: T028, T040b. *Hecho cuando:* test de widget con varias combinaciones.
- [x] **T102** Formato de personaje con tono parametrizable y 3 personajes de prueba. RF: 72. Dep: T040b. *Hecho cuando:* los 3 se ven con los 6 tonos y 12 fondos en un test de widget.
- [x] **T104** Selector de avatar. RF: 14, 16. Dep: T101, T102. *Hecho cuando:* no se puede continuar sin elegir personaje, tono y fondo.
- [x] **T106** Lista de clientes con saldo. RF: 20, 42. Dep: T040a, T040b, T033, T039, T100. *Hecho cuando:* los archivados no aparecen y el saldo a favor se distingue de la deuda.
- [x] **T107** Crear y editar cliente con teléfono, dirección, nota y aviso de homónimo. RF: 14–19, 73, 74, 77. Dep: T032, T104, T024. *Hecho cuando:* un homónimo muestra el aviso y solo continúa si se confirma.
- [x] **T108** Detalle de cliente con saldo e historial. RF: 41, 42. Dep: T039, T106. *Hecho cuando:* los anulados aparecen con marca visible.
- [x] **T109** Formulario de fiado con ítems. RF: 28, 32, 33, 34, 83, 84. Dep: T035, T020, T108. *Hecho cuando:* el subtotal se muestra redondeado según el modo del negocio.
- [x] **T110** Elegir producto del catálogo o escribir un ítem libre, y cambiar el precio solo para ese ítem. RF: 30, 31. Dep: T034, T109. *Hecho cuando:* el precio del catálogo no cambia al modificarlo en el ítem.
- [x] **T111** Fiado por monto total. RF: 29, 33. Dep: T035, T108. *Hecho cuando:* se registra sin ítems y suma al saldo.
- [x] **T112** Formulario de abono. RF: 37, 38, 39, 75. Dep: T037, T108. *Hecho cuando:* un abono mayor que la deuda deja saldo a favor y un cliente archivado sí admite abonos.
- [x] **T115** Catálogo: lista, alta, cambio de precio y archivado. RF: 24–27. Dep: T034, T100. *Hecho cuando:* empleado y dueño pueden administrarlo y no hay opción de borrar.

## Fase 3c — Unidades de venta (antes de la prueba manual)
Añade la unidad de venta (unidad, libra, docena…) a productos e ítems de fiado: RF-86 a RF-89 y D-23. Es solo una etiqueta, con una lista fija compartida; no convierte entre unidades ni cambia el cálculo. La prueba manual T040c se ejecuta al final de esta fase, para recorrer el flujo ya con unidades.

- [x] **T154** Lista de unidades de venta compartida y su dominio móvil. RF: 86, 89. *Hecho cuando:* `shared/vectors/units.json` define las 10 unidades (unidad, libra, onza, kilo, docena, litro, galón, caja, bolsa, paquete) con identificador estable y nombre, plural y abreviatura en español; el dominio móvil la lee en un test y coincide; un identificador fuera de la lista se rechaza y la unidad por omisión es `unit`.
- [x] **T155** Esquema local versión 2 con la unidad en productos e ítems de fiado. RF: 86, 88. Dep: T154. *Hecho cuando:* una base creada con la versión 1, con productos e ítems, migra a la versión 2 sin perder datos y deja `unit` en lo existente; el código de Drift se regenera y las pruebas de esquema pasan.
- [x] **T156** Repositorios con unidad: producto (crear y editar) e ítem de fiado. RF: 86, 87, 88. Dep: T155. *Hecho cuando:* cada ítem guarda la unidad que se le indica (la del producto, otra o `unit` si es libre); cambiar la unidad o el precio de un producto, o archivarlo, no altera los ítems ya guardados; una unidad inválida se rechaza; y la operación de la cola lleva la unidad.
- [x] **T157** Catálogo: elegir la unidad al crear o editar un producto y mostrarla en la lista. RF: 86. Dep: T156, T115. *Hecho cuando:* un test de widget crea un producto "por libra", lo ve en la lista con su unidad, cambia su unidad y la lista se actualiza.
- [x] **T158** Fiado: unidad por ítem, propuesta por el producto y editable solo para ese ítem. RF: 87, 89. Dep: T156, T109, T110. *Hecho cuando:* al elegir un producto el ítem propone su unidad, se puede cambiar sin tocar el producto, un ítem libre usa `unit` por omisión y el subtotal no cambia al cambiar la unidad.
- [x] **T159** Historial y detalle del cliente muestran la unidad de cada ítem. RF: 88, 89. Dep: T156, T108. *Hecho cuando:* el detalle muestra "2.5 libras × L 25.00" (con la unidad en singular solo cuando la cantidad es exactamente 1) y los ítems anteriores a la migración muestran "unidad".
- [x] **T040c** Prueba manual del tramo en el emulador, en modo avión: crear clientes con avatar, crear productos con unidad, fiar con ítems (con unidades) y por total, abonar, ver saldo e historial, y comprobar que todo sigue al reiniciar la app. RF: 14, 28, 29, 37, 40, 41, 86, 88; RNF-1. Dep: T106–T112, T115, T154–T159. *Hecho cuando:* se recorre el flujo sin errores y se anotan los cambios de pantalla que se quieren antes de seguir.

## Fase 3d — Fiar rápido (tras la prueba manual T040c)
Rediseña el registro de fiados y abonos para usar menos toques, a partir de lo anotado en T040c: el catálogo como cuadrícula con búsqueda, un carrito de filas compactas y montos rápidos. No cambia ningún RF ni las reglas del dominio (subtotal, redondeo, unidad y validación); solo la interfaz. El teclado manual se conserva siempre: los atajos solo rellenan el campo.

- [x] **T160** Carrito del fiado: estado sin pantalla para agregar un producto (cantidad 1), sumar, restar y quitar, con el total. RF: 28, 30, 31, 34, 83, 87. Dep: T109, T110. *Hecho cuando:* tests del estado comprueban que agregar el mismo producto suma 1 a su cantidad, que restar por debajo de 1 lo quita, que el subtotal y el total usan el redondeo del negocio y que el ítem copia nombre, precio y unidad del producto.
- [x] **T161** Cuadrícula del catálogo con búsqueda en la pantalla de fiar. RF: 26, 30. Dep: T160, T115. *Hecho cuando:* un test de widget muestra los productos activos del negocio como botones, filtra al escribir sin distinguir mayúsculas, no muestra archivados y un toque agrega el producto y otro suma 1.
- [x] **T162** Carrito con filas compactas y edición al tocar la fila. RF: 28, 30, 33, 87, 89. Dep: T160, T161. *Hecho cuando:* cada fila muestra nombre, − cantidad +, unidad y subtotal; tocar la fila abre la edición de precio, unidad, descripción y cantidad exacta; los errores salen en español por campo; y registrar guarda el fiado con sus ítems.
- [x] **T163** Ítem libre ("Otro") desde la misma pantalla. RF: 31, 87. Dep: T162. *Hecho cuando:* se agrega un ítem sin producto con descripción, precio y unidad "unidad" por omisión, y se guarda sin `productId`.
- [x] **T164** "Solo monto" con montos rápidos y campo manual. RF: 29, 33. Dep: T111. *Hecho cuando:* tocar un monto rápido rellena el campo, el campo sigue editable a mano y los errores de monto siguen saliendo en español.
- [x] **T165** Abono con "Saldo completo", montos rápidos y campo manual. RF: 37, 38, 39. Dep: T112. *Hecho cuando:* "Saldo completo" rellena justo la deuda del cliente (y no aparece si no debe nada), los montos rápidos rellenan el campo, y el campo sigue editable a mano.

## Fase 3e — Ajustes de fiar rápido (feedback sobre la Fase 3d)
Solo interfaz: no cambia ningún RF ni las reglas del dominio. Barras inferiores fijas con el total y "Registrar", y un catálogo de entrada limitado (8 productos frecuentes) con "Ver todos". Se conserva el un-toque-agrega, la búsqueda, los montos rápidos que solo rellenan el campo y el teclado manual. En el detalle del cliente, "Fiar" y "Abonar" ya estaban fijos.

- [x] **T166** Barra inferior fija en el formulario de fiado (total y "Registrar"). RF: 28, 29, 34. Dep: T162, T164. *Hecho cuando:* un test de widget comprueba que la barra sigue visible con muchas líneas en el carrito y con el teclado abierto, que el total se actualiza y que el error del formulario sale sobre la barra; y que en el detalle del cliente "Fiar" y "Abonar" siguen visibles con historial largo.
- [x] **T167** Barra inferior fija en el formulario de abono (monto y "Registrar abono"). RF: 37, 39. Dep: T165. *Hecho cuando:* un test comprueba que el botón sigue visible con el teclado abierto y que la vista previa del saldo se conserva.
- [x] **T168** Consulta de productos frecuentes del negocio: los más fiados (sin contar movimientos anulados ni productos archivados), completados con los más recientes si hay pocos, con tope de 8. RF: 26, 30. Dep: T109, T115. *Hecho cuando:* tests del repositorio comprueban el orden por veces fiado, que se excluyen anulados y archivados, que se completa con recientes y que se respeta el tope.
- [x] **T169** Pantalla de fiar con frecuentes y "Ver todos" (hoja con búsqueda y lista completa). RF: 26, 30. Dep: T161, T168. *Hecho cuando:* tests de widget comprueban que de entrada hay como máximo 8 productos, que "Ver todos" abre el catálogo completo y que un toque ahí agrega, que la búsqueda de la pantalla encuentra productos fuera de los frecuentes, que no aparecen archivados y que un toque agrega y otro suma 1.
- [x] **T170** Tarjeta del producto con − cantidad + para quitar y agregar desde la propia tarjeta, y tarjetas más cuidadas (sombra suave, botón + visible, estado seleccionado claro). RF: 30, 31. Dep: T169. *Hecho cuando:* tests de widget comprueban que una tarjeta sin agregar no muestra el botón −, que con el producto en el carrito muestra − cantidad +, que − resta 1 y quita la línea al llegar a cero, que + suma 1, que un toque en el cuerpo de la tarjeta sigue agregando, y que lo mismo funciona en la hoja "Ver todos".
- [x] **T171** Botón de borrar la línea entera en el carrito cuando la cantidad es mayor que 1. RF: 30, 31. Dep: T162. *Hecho cuando:* un test comprueba que con cantidad 1 no aparece, que con cantidad mayor que 1 aparece y que al tocarlo la línea se quita de una vez y el total se actualiza.

## Fase 3f — Productos: precio anterior y repetidos (móvil)
Añade RF-90 y RF-91 y D-24: el producto guarda su precio anterior y la fecha del cambio, y al guardar un producto con el mismo nombre y unidad que otro activo se avisa. No toca los ítems fiados ya registrados ni la operación de la cola.

- [x] **T174** Regla de dominio de producto repetido por nombre y unidad. RF: 91. Dep: T024, T034. *Hecho cuando:* tests comprueban que ignora mayúsculas y espacios exteriores, que otra unidad no es repetido, que los archivados no cuentan y que al editar un producto se excluye a sí mismo.
- [x] **T175** Aviso de producto repetido en el formulario del catálogo, con "Cambiar el precio del existente" y "Crear de todos modos". RF: 91. Dep: T174, T157. *Hecho cuando:* tests de widget comprueban que el aviso sale al crear y al cambiar nombre o unidad, que confirmar guarda, que la otra salida abre el producto existente y que sin repetido no sale aviso.
- [x] **T176** Vectores compartidos `shared/vectors/price-change.json` y regla móvil del precio anterior. RF: 90. Dep: T034. *Hecho cuando:* los casos pasan en móvil: un precio distinto guarda anterior y fecha; el mismo precio, solo el nombre o solo la unidad no los tocan; 20, 25 y de vuelta a 20 deja 25 como anterior.
- [x] **T177** Esquema local versión 3 con `previous_price` y `price_changed_at` en productos. RF: 90. Dep: T155, T176. *Hecho cuando:* una base creada con la versión 2, con productos, migra a la versión 3 sin perder datos y deja los dos campos en nulo; el código de Drift se regenera y las pruebas de esquema pasan.
- [x] **T178** El repositorio de productos guarda el precio anterior y la fecha al cambiar el precio. RF: 90, 25. Dep: T177. *Hecho cuando:* cambiar el precio guarda anterior y fecha, los ítems de fiado ya guardados no cambian y la operación en la cola conserva su forma.
- [x] **T179** El catálogo muestra "Antes: L 20.00" y la fecha del cambio. RF: 90. Dep: T178, T157. *Hecho cuando:* un test de widget comprueba que solo aparece en productos con cambio de precio y que el formato respeta el modo de montos del negocio.
- [x] **T182** Tarjetas del catálogo más cuidadas, con el estilo de las de cliente y de producto al fiar (esquinas redondeadas, sombra suave, unidad en una píldora, precio destacado y altura mínima uniforme). RF: 24, 86, 90. Dep: T179, T170. *Hecho cuando:* tests de widget comprueban que todas las tarjetas tienen la misma altura mínima con y sin precio anterior, que muestran nombre, unidad, precio y el precio anterior si existe, que un nombre muy largo no desborda en pantallas angostas, que un toque abre la edición y que archivar sigue funcionando.

## Fase 4 — Dominio de la API (.NET, sin EF ni HTTP)
- [x] **T041** Dinero y cantidad en unidad menor y milésimas. RF: 84; RNF-2. Dep: T013. *Hecho cuando:* pasan los vectores y no hay `double` ni `float` en el dominio.
- [x] **T042** Subtotales con ambos modos. RF: 34, 83. Dep: T006, T007. *Hecho cuando:* pasan los vectores de T006 y T007.
- [x] **T043** Validación de fiado y abono. RF: 28, 29, 32, 33, 35, 36, 37, 38. *Hecho cuando:* los casos coinciden con los del móvil (T020, T021).
- [x] **T044** Cálculo de saldo. RF: 39, 40, 42, 44, 47. Dep: T008. *Hecho cuando:* pasan los vectores de saldo.
- [x] **T045** Validación de cliente y producto. RF: 15, 16, 24, 74, 77, 86. Dep: T009, T011, T012, T154. *Hecho cuando:* pasan los vectores correspondientes y una unidad fuera de la lista compartida se rechaza.
- [x] **T046** Permisos por rol. RF: 13, 21, 45, 48. *Hecho cuando:* la matriz coincide con la del móvil (T025).
- [x] **T047** Resumen del negocio. RF: 63, 64, 65. Dep: T010. *Hecho cuando:* pasan los vectores de resumen.
- [x] **T048** Reglas de ajustes del negocio. RF: 7, 8, 9. Dep: T013. *Hecho cuando:* pasan los vectores de transiciones.
- [x] **T049** Reglas de equipo: promoción, baja y último dueño. RF: 70, 71. *Hecho cuando:* toda acción que dejaría el negocio sin dueño se rechaza.
- [x] **T050** Reglas de invitación: estados y transiciones. RF: 10, 67, 68, 69. *Hecho cuando:* solo se puede aceptar o rechazar una invitación pendiente y una cancelada no se acepta.
- [x] **T180** Regla del precio anterior en el dominio de la API, contra los mismos vectores. RF: 90. Dep: T176. *Hecho cuando:* pasan los casos de `shared/vectors/price-change.json`.

## Fase 5 — Persistencia y aplicación de operaciones (API)
- [x] **T051** Persistencia de usuarios, negocios, pertenencias e invitaciones con migración. RF: 1, 2, 10. Dep: T049, T050. *Hecho cuando:* una prueba de integración contra PostgreSQL real crea y lee cada tabla.
- [x] **T052** Persistencia de clientes y productos. RF: 14, 24. *Hecho cuando:* integración contra PostgreSQL real.
- [x] **T053** Persistencia de fiados, ítems y abonos. RF: 28, 37. *Hecho cuando:* integración contra PostgreSQL real.
- [x] **T054** Persistencia de `change_log`, `processed_ops`, contador por negocio y `admin_audit`. RF: 53, 81. *Hecho cuando:* integración contra PostgreSQL real.
- [x] **T055** Aislamiento por `business_id`. RF: 50; RNF-6. *Hecho cuando:* una prueba con dos negocios demuestra que ninguna consulta devuelve datos del otro.
- [x] **T056** Aplicar operaciones de cliente (crear, editar con versión, archivar, restaurar). RF: 14–23, 55, 73. Dep: T045, T052. *Hecho cuando:* una edición con versión desfasada se rechaza con código de conflicto.
- [x] **T057** Aplicar operaciones de producto (crear, cambiar precio, archivar). RF: 24, 25, 26, 27, 86. *Hecho cuando:* no existe operación de borrar producto.
- [x] **T058** Aplicar la creación de fiado. RF: 28–36, 49, 83, 84, 85, 87, 88. Dep: T043, T053. *Hecho cuando:* cada fiado guarda el usuario que lo registró y un fiado a un cliente archivado se acepta si lo originó un dispositivo que no conocía el archivado.
- [x] **T059** Aplicar la creación de abono. RF: 37, 38, 39, 49, 75. *Hecho cuando:* un abono mayor que la deuda se acepta y deja saldo a favor, y cada abono guarda el usuario que lo registró.
- [x] **T060** Aplicar anulaciones de fiado y abono, idempotentes. RF: 43, 44, 46, 47, 49. *Hecho cuando:* cada anulación guarda usuario y fecha, y anular dos veces el mismo movimiento no cambia nada ni falla.
- [x] **T061** Comprobar permisos de rol en cada operación. RF: 13, 21, 45, 48. Dep: T046. *Hecho cuando:* un empleado que intenta anular o archivar recibe rechazo.
- [x] **T062** Registrar cada operación aplicada en `change_log` con su `seq`, de forma atómica. RF: 52. *Hecho cuando:* una falla a mitad de operación no deja `seq` huérfano.
- [x] **T181** Columnas `previous_price` y `price_changed_at` en `products`, aplicadas al procesar `product.update`, y devueltas por la sincronización y por la consulta de productos. RF: 90. Dep: T180. *Hecho cuando:* un cambio de precio sincronizado deja el anterior y la fecha, un cambio de solo nombre no los toca y el pull los entrega al móvil.

## Fase 6 — Cuentas, negocios y equipo (API)
- [x] **T063** Registro con correo, contraseña y nombre de negocio. RF: 1, 2, 78. Dep: T051. *Hecho cuando:* crea usuario, negocio y pertenencia de dueño; sin nombre de negocio se rechaza.
- [x] **T064** Inicio de sesión, renovación y cierre de sesión. RF: 3, 4. *Hecho cuando:* el token de acceso caduca, el de renovación lo reemplaza y tras cerrar sesión deja de servir.
- [x] **T065** Crear negocio adicional y listar negocios con rol. RF: 5, 6, 79. *Hecho cuando:* un usuario con dos negocios los ve con su rol en cada uno.
- [x] **T066** Negocio activo en cada petición con comprobación de pertenencia. RF: 50, 6. *Hecho cuando:* una petición a un negocio ajeno recibe rechazo.
- [x] **T067** Leer y cambiar ajustes y nombre del negocio (solo dueño). RF: 7, 8, 9, 80. Dep: T048. *Hecho cuando:* pasar de decimales a enteros se rechaza y un empleado no puede cambiar nada.
- [x] **T068** Crear invitación, listar pendientes del usuario, aceptar y rechazar. RF: 10, 67, 68. Dep: T050. *Hecho cuando:* al aceptar entra como empleado aunque ya pertenezca a otros negocios.
- [x] **T069** Cancelar invitación. RF: 69. *Hecho cuando:* una invitación cancelada no puede aceptarse.
- [x] **T070** Listar equipo y promover a dueño. RF: 70. *Hecho cuando:* el promovido recibe todos los permisos de dueño.
- [x] **T071** Quitar usuario con protección del último dueño. RF: 11, 71. *Hecho cuando:* el usuario quitado pierde acceso y no se puede quitar al último dueño.
- [x] **T072** Rechazar gestión de equipo y negocio para empleados. RF: 13. *Hecho cuando:* todas las rutas de gestión devuelven rechazo a un empleado.
- [x] **T073** Comando del servidor para restablecer una contraseña, con auditoría. RF: 81, 82. Dep: T054. *Hecho cuando:* cambia la contraseña, escribe en `admin_audit` quién y cuándo, y su salida no muestra datos de negocios.
- [x] **T183** Código de invitación: columna `code` (migración `CodigoDeInvitacion`, `email` opcional), código al crear la invitación con o sin correo, visible en el listado del dueño, y `POST /api/invitations/redeem` con límite de intentos. RF: 10, 92, 93, 94; D-28. Dep: T068, T069. *Hecho cuando:* una invitación sin correo se activa con su código desde una cuenta cualquiera y entra como empleado; una con correo también se puede activar por código desde otro correo; un código usado, cancelado o inexistente da el mismo rechazo sin revelar el negocio; el invitado no ve el código en su lista; y el undécimo intento fallido en un minuto se rechaza.

## Fase 7 — Sincronización y consultas (API)
- [x] **T074** Endpoint de envío de lote con resultado por operación. RF: 52. Dep: T056–T062. *Hecho cuando:* cada operación del lote devuelve aplicada, duplicada o rechazada con código.
- [x] **T075** Idempotencia por `op_id`. RF: 53. *Hecho cuando:* reenviar el mismo lote tres veces deja un solo fiado, abono o anulación.
- [x] **T076** Conflicto de versión: gana el servidor. RF: 55. *Hecho cuando:* una edición con versión anterior se rechaza y no sobrescribe.
- [x] **T077** Fiados y abonos concurrentes del mismo cliente desde dos dispositivos. RF: 54. *Hecho cuando:* tras ambos envíos el saldo es la suma de todos.
- [x] **T078** Anulación de un fiado con abonos de otro dispositivo. RF: 47. *Hecho cuando:* los abonos se conservan y el saldo queda a favor.
- [x] **T079** Endpoint de cambios por cursor, paginado. RF: 52; RNF-7. *Hecho cuando:* devuelve solo lo posterior al cursor y en páginas.
- [x] **T080** Descarga inicial desde cursor cero. RF: 58. *Hecho cuando:* un cursor vacío entrega todo el negocio y nada de otros negocios.
- [x] **T081** Empleado removido: último lote y revocación. RF: 11, 12. *Hecho cuando:* su primer envío tras la baja se acepta, el siguiente se rechaza, y no hay límite de tiempo.
- [x] **T082** Prueba de fiado a cliente archivado por otro dispositivo. RF: 85. *Hecho cuando:* el fiado se acepta y el cliente sigue archivado con el saldo actualizado.
- [x] **T083** Endpoint de operación individual para la web. RF: 59, 60. *Hecho cuando:* una operación enviada se aplica y devuelve su resultado al instante.
- [x] **T084** Consultas de lectura: clientes con saldo, historial, archivados, productos. RF: 22, 41, 42, 59. *Hecho cuando:* cada consulta respeta el aislamiento del negocio.
- [x] **T085** Consulta del resumen. RF: 63, 64, 65. Dep: T047. *Hecho cuando:* pasan los vectores de resumen desde el servidor.
- [x] **T086** Contrato OpenAPI en `shared/`. RF: —; D-17. *Hecho cuando:* una prueba verifica que las respuestas reales coinciden con el contrato.

## Fase 8 — Sesión y sincronización del móvil
- [x] **T087** Cliente HTTP y modelos del contrato. RF: —. Dep: T086. *Hecho cuando:* tests contra respuestas de ejemplo del contrato.
- [ ] **T088** Sesión: registro, inicio de sesión y token en almacenamiento seguro. RF: 1, 2, 3, 78. *Hecho cuando:* la sesión sobrevive a reiniciar la app, sin conexión falla el primer inicio con mensaje en español y se elimina la sesión simulada de T040a.
- [ ] **T089** Negocios del usuario: listar, elegir y cambiar el activo. RF: 5, 6, 79. *Hecho cuando:* los datos mostrados corresponden siempre al negocio activo.
- [ ] **T090** Envío de la cola. RF: 52, 53, 56. *Hecho cuando:* aplicadas y duplicadas salen de la cola y rechazadas quedan visibles con su código.
- [ ] **T091** Recepción de cambios por cursor. RF: 52. *Hecho cuando:* aplicar dos veces la misma página no duplica nada.
- [ ] **T092** Descarga inicial en dispositivo nuevo. RF: 58. *Hecho cuando:* un dispositivo vacío queda con los mismos datos del negocio.
- [ ] **T093** Conflicto de versión: descartar la edición local y avisar. RF: 55. *Hecho cuando:* tras un rechazo por conflicto el registro local queda como el del servidor y se registra el aviso.
- [ ] **T094** Fallo de red o de servidor conserva la cola y reintenta. RF: 56. *Hecho cuando:* tras un fallo simulado, las operaciones siguen pendientes y se envían luego.
- [ ] **T095** Disparadores de sincronización: al abrir, al recuperar conexión y manual. RF: 52. *Hecho cuando:* cada disparador inicia exactamente una sincronización.
- [ ] **T096** Indicador de cambios sin sincronizar. RF: 57. *Hecho cuando:* se muestra con operaciones pendientes y desaparece al vaciarse la cola.
- [ ] **T097** Token de renovación caducado sin conexión. RF: 4; D-10. *Hecho cuando:* la app sigue usable, la cola se conserva y se pide iniciar sesión solo para sincronizar.
- [ ] **T098** Baja del negocio: borrar sus datos locales tras el último lote. RF: 11, 12. *Hecho cuando:* tras la baja no queda ningún dato de ese negocio en el dispositivo.
- [ ] **T099** Prueba de extremo a extremo con dos dispositivos simulados. RF: 47, 54, 85. *Hecho cuando:* fiados concurrentes, anulación con abono y fiado a cliente archivado terminan con el mismo saldo en ambos.

## Fase 9 — Interfaz del móvil (resto)
Las pantallas de clientes, fiados, abonos y catálogo se movieron a la Fase 3b.

- [x] **T103** Incorporar los 24 personajes finales, dibujados en código como los de T102. RF: 72. Dep: T102. *Hecho cuando:* existen los 24 y el test confirma que cada identificador de la paleta tiene su recurso.
- [ ] **T105** Pantallas de registro, inicio de sesión y elección de negocio. RF: 1–6, 78, 79. Dep: T088, T089. *Hecho cuando:* un usuario se registra, entra y elige negocio con mensajes de error en español.
- [x] **T113** Acción de anular, visible solo para el dueño. RF: 43, 44, 45. *Hecho cuando:* el empleado no ve la acción y el dueño anula con confirmación.
- [x] **T114** Archivar y restaurar cliente y vista de archivados. RF: 20–23, 76. *Hecho cuando:* solo el dueño ve las acciones y fiar a un archivado muestra que debe restaurarse primero.
- [x] **T172** Tarjetas de cliente más cuidadas: sombra suave, avatar y saldo mejor jerarquizados, estado archivado claro y altura uniforme, igual que las tarjetas de producto. RF: 20, 42. Dep: T106, T114. *Hecho cuando:* tests de widget comprueban que la tarjeta distingue deuda, saldo a favor y saldo cero, que un archivado se ve marcado en la vista de archivados y que un toque sigue abriendo el detalle.
- [x] **T173** Detalle del cliente rediseñado: cabecera con avatar, nombre y marca de archivado, saldo grande como protagonista y los datos de contacto como chips dentro de la misma tarjeta (sin tarjeta de contacto suelta); movimientos con el estilo de las tarjetas de producto y de cliente (sombra suave, icono tintado, monto con signo, ítems del fiado en un panel interior). RF: 41, 42. Dep: T108, T172. *Hecho cuando:* tests de widget comprueban que la cabecera muestra nombre, avatar, saldo y etiqueta (deuda, a favor, al día), que teléfono, dirección y nota salen como chips dentro de la cabecera solo si existen, que el archivado se marca, que los movimientos van en orden con signo (+ el fiado, − el abono), que los anulados siguen marcados y atenuados, que los ítems siguen visibles con su unidad y que nada desborda en pantallas angostas.
- [x] **T116** Resumen del negocio. RF: 63–66. *Hecho cuando:* muestra deuda total, saldo a favor total y mayores deudores, sin archivados.
- [ ] **T117** Equipo: invitar, cancelar, promover y quitar. RF: 10, 11, 13, 69, 70, 71. *Hecho cuando:* solo los dueños ven la sección y el último dueño no se puede quitar.
- [ ] **T118** Invitaciones recibidas: aceptar o rechazar. RF: 67, 68. *Hecho cuando:* se muestran al iniciar sesión y al aceptar el negocio aparece en la lista.
- [ ] **T184** Código de invitación en el móvil: invitar con o sin correo, ver y compartir el código desde la lista de invitaciones del dueño, y canjear un código recibido. RF: 92, 93, 94. Dep: T117, T118, T183. *Hecho cuando:* el dueño comparte el código con la hoja de compartir del teléfono, quien lo escribe (con o sin guion, en minúsculas) entra al negocio, y un código inválido muestra el mismo mensaje en español.
- [ ] **T119** Ajustes y nombre del negocio. RF: 7, 8, 9, 80. *Hecho cuando:* pasar de decimales a enteros no se ofrece.
- [ ] **T120** Mensajes de error en español para cada código de la API. RNF-5. *Hecho cuando:* una prueba recorre todos los códigos y ninguno queda sin mensaje.
- [x] **T121** Verificación del flujo principal en modo avión. RNF-1. *Hecho cuando:* en un dispositivo o emulador sin red se completa el flujo de clientes, fiados, abonos, anulación y resumen.

## Fase 10 — Cliente web
- [ ] **T122** Dominio web: validaciones de formulario con los vectores. RF: 15, 17, 32, 34, 35, 36, 74, 77, 83, 84. Dep: T006, T007, T009, T012, T013. *Hecho cuando:* pasan los vectores en `ng test`.
- [ ] **T123** Servicio de sesión, interceptor y detección de falta de conexión. RF: 3, 61. *Hecho cuando:* sin conexión toda escritura se bloquea con aviso en español.
- [ ] **T124** Servicios de operaciones y de consultas. RF: 59, 60. *Hecho cuando:* tests contra respuestas de ejemplo del contrato.
- [ ] **T125** Registro, inicio de sesión y elección de negocio. RF: 1–6, 78, 79. *Hecho cuando:* flujo completo con errores en español.
- [ ] **T126** Componente de avatar con la paleta compartida. RF: 14, 72. *Hecho cuando:* test con varias combinaciones.
- [ ] **T127** Lista de clientes y crear/editar con aviso de homónimo. RF: 14–19, 73, 74, 77. *Hecho cuando:* mismas reglas que el móvil.
- [ ] **T128** Detalle de cliente con historial. RF: 41, 42. *Hecho cuando:* los anulados aparecen marcados.
- [ ] **T129** Registrar fiado y abono. RF: 28–39, 75, 83, 84, 87, 88, 89. *Hecho cuando:* el subtotal redondeado coincide con los vectores.
- [ ] **T130** Anular movimientos (solo dueño). RF: 43, 44, 45. *Hecho cuando:* el empleado no ve la acción.
- [ ] **T131** Archivar, restaurar y vista de archivados. RF: 20–23, 76. *Hecho cuando:* solo el dueño archiva y restaura.
- [ ] **T132** Catálogo. RF: 24–27, 86. *Hecho cuando:* alta, precio y archivado funcionan sin opción de borrar.
- [ ] **T133** Resumen. RF: 63, 64, 65. *Hecho cuando:* coincide con el resultado del móvil para los mismos datos.
- [ ] **T134** Equipo y ajustes del negocio. RF: 7–13, 67–71, 80. *Hecho cuando:* solo los dueños acceden y el empleado recibe rechazo.
- [ ] **T185** Código de invitación en la web: invitar con o sin correo, ver y copiar el código, y canjear un código. RF: 92, 93, 94. Dep: T134, T183. *Hecho cuando:* el dueño copia el código de una invitación pendiente y quien lo canjea entra como empleado.
- [ ] **T135** Efecto de los cambios hechos en la web sobre los móviles. RF: 62. *Hecho cuando:* una prueba entre web simulada y móvil simulado muestra el cambio tras sincronizar.

## Fase 10b — Administración de la plataforma (super administrador)
Añade RF-95 a RF-104, D-29 y D-30 (activación de negocios). Va después de la sincronización y de la web, antes del despliegue. El panel nunca muestra datos de un negocio: solo metadatos y cifras agregadas.

- [ ] **T186** Migración `SuperAdministrador` y reglas de dominio: `is_super_admin`, suspensión de cuentas, estado del negocio (`pending`, `active`, `suspended`, D-30), `admin_audit` ampliada y solo de inserción, y la regla del último super administrador. RF: 95, 98, 99, 101, 102, 103. Dep: T054, T073. *Hecho cuando:* pruebas de dominio y de integración comprueban que no se puede retirar la marca al último super administrador, que la auditoría rechaza editar y borrar, y que el estado del negocio solo permite las transiciones válidas (pendiente a activo o suspendido, activo a suspendido, suspendido a activo).
- [ ] **T187** Comandos del servidor `admin grant-superadmin` y `admin revoke-superadmin`. RF: 95, 101. Dep: T186. *Hecho cuando:* marcar y retirar funciona por correo, queda auditado quién y cuándo, retirar al último se rechaza, y la salida no muestra datos de negocios.
- [ ] **T188** Rutas `/api/admin` solo para super administradores, con renovación de sesión más corta. RF: 96. Dep: T186, T064. *Hecho cuando:* un usuario normal y un token sin sesión reciben rechazo en todas las rutas de administración (una prueba recorre las rutas reales, como T072), un super administrador pasa, y su renovación caduca a las 12 horas.
- [ ] **T189** Listado y búsqueda de negocios y cuentas, y ficha de cada uno, con cifras agregadas. RF: 97, 82. Dep: T188. *Hecho cuando:* se encuentran por nombre o correo con paginación, la última sincronización y los conteos son correctos, y una prueba inspecciona todos los campos de todas las respuestas y comprueba que no hay nombres de clientes ni de productos, montos ni deudas.
- [ ] **T190** Suspender y reactivar un negocio con motivo. RF: 98, 101. Dep: T188, T074. *Hecho cuando:* un negocio suspendido rechaza con `business_suspended` sus peticiones, sus lotes y su pull sin perder datos, al reactivarlo todo vuelve a funcionar y la cola pendiente se aplica, y queda auditado con el motivo.
- [ ] **T191** Suspender y reactivar una cuenta con motivo. RF: 99, 101. Dep: T188. *Hecho cuando:* la cuenta suspendida no inicia sesión (`account_suspended`), sus sesiones abiertas dejan de servir, sus negocios siguen intactos, y al reactivarla puede entrar; queda auditado.
- [ ] **T192** Restablecer la contraseña de una cuenta desde el panel. RF: 100, 81. Dep: T188, T073. *Hecho cuando:* devuelve una contraseña nueva una sola vez, cierra las sesiones de la cuenta, queda auditado y el resultado no incluye datos de negocios.
- [ ] **T193** Consulta de la auditoría con paginación y filtros por cuenta, negocio y acción. RF: 101. Dep: T189–T192. *Hecho cuando:* muestra quién, cuándo, qué, sobre qué y el motivo de cada acción de los comandos y del panel, de la más reciente a la más antigua.
- [ ] **T194** Mensajes en español para `business_pending`, `business_suspended` y `account_suspended` en el móvil y la web, sin perder lo que el teléfono ya tiene. RF: 98, 99; RNF-5. Dep: T190, T191, T120. *Hecho cuando:* un negocio suspendido muestra el aviso, el teléfono sigue funcionando sin conexión y la cola se conserva hasta reactivarse.
- [ ] **T195** Panel web `/admin`: acceso solo para super administradores, listados y ficha de negocios y cuentas. RF: 96, 97. Dep: T189, T123. *Hecho cuando:* un usuario normal no ve ni abre la ruta, un super administrador busca y ve las cifras, y ninguna pantalla muestra datos de fiados.
- [ ] **T196** Panel web `/admin`: suspender, reactivar, restablecer contraseña y ver la auditoría. RF: 98, 99, 100, 101. Dep: T190–T193, T195. *Hecho cuando:* cada acción pide el motivo, confirma antes de ejecutar, muestra la contraseña nueva una sola vez y aparece en la auditoría.
- [ ] **T198** Activación de negocios: el negocio del registro nace pendiente (el adicional de un dueño activo nace activo), un negocio pendiente rechaza con `business_pending`, y el super administrador lista los pendientes y los activa. RF: 102, 103, 104, 97. Dep: T186, T188, T063, T065. *Hecho cuando:* un dueño recién registrado inicia sesión pero su negocio rechaza peticiones, lotes y pull con `business_pending` mientras sigue usando otro negocio activo; el super administrador lo ve en `GET /api/admin/businesses?status=pending`, lo activa y desde entonces trabaja con normalidad; un dueño activo crea un adicional que nace activo; y todo queda auditado.
- [ ] **T199** Móvil: aviso de negocio pendiente de activación al registrarse o iniciar sesión, sin ofrecer registrar datos, y entrada normal al activarse. RF: 102. Dep: T198, T105. *Hecho cuando:* un dueño nuevo ve "Tu negocio está pendiente de activación", puede elegir otro negocio activo si lo tiene, y tras la activación entra y sincroniza sin reinstalar.
- [ ] **T200** Panel web `/admin`: lista de negocios pendientes con el correo del dueño, y botones para activar o rechazar con motivo. RF: 103, 97. Dep: T198, T195, T196. *Hecho cuando:* el super administrador activa un pendiente desde el panel y lo rechaza con motivo, y ambas acciones aparecen en la auditoría.

## Fase 11 — Despliegue y respaldo
- [ ] **T136** Docker Compose con API y PostgreSQL. RF: —. *Hecho cuando:* `docker compose up` deja la API respondiendo y migrada.
- [ ] **T137** Entrega de la web estática desde el despliegue. RF: 59. *Hecho cuando:* la web carga y llega a la API.
- [ ] **T138** Servicio de copia diaria con rotación de 3. RNF-8. *Hecho cuando:* tras 4 ejecuciones quedan exactamente las 3 más recientes.
- [ ] **T139** Script de restauración en una base vacía. RNF-8. *Hecho cuando:* una copia restaurada pasa una consulta de integridad sobre los datos.
- [ ] **T140** Definir el destino de las copias fuera del servidor. RNF-8. Dep: tu decisión. *Hecho cuando:* queda documentado y el servicio de copia envía allí el archivo.
- [ ] **T141** Documentar el comando de restablecimiento de contraseña. RF: 81. *Hecho cuando:* un tercero lo ejecuta siguiendo solo la documentación.

## Fase 12 — Validación
- [ ] **T142** Recorrido RF por RF: qué test cubre cada uno y su resultado. RF: 1–104. *Hecho cuando:* existe una tabla con los 104 RF y los 8 RNF, cada uno con test o demo y resultado.
- [ ] **T143** Demo: flujo principal en modo avión. RNF-1. *Hecho cuando:* se completa sin errores en un teléfono o emulador sin red.
- [ ] **T144** Demo: dos dispositivos con fiados concurrentes. RF: 54. *Hecho cuando:* el saldo coincide en los dos.
- [ ] **T145** Demo: recuperación en dispositivo nuevo. RF: 58. *Hecho cuando:* se ven todos los datos del negocio.
- [ ] **T146** Demo: permisos de empleado y dueño. RF: 13, 21, 45, 48. *Hecho cuando:* el empleado no puede anular, archivar ni gestionar equipo.
- [ ] **T147** Demo: web con las operaciones principales. RF: 59–62. *Hecho cuando:* lo hecho en la web aparece en el móvil tras sincronizar.
- [ ] **T148** Demo: ajustes de negocio con enteros y con decimales. RF: 7, 8, 9, 34, 83. *Hecho cuando:* dos negocios muestran los montos esperados.
- [ ] **T149** Demo: respaldo y restauración. RNF-8. *Hecho cuando:* existen las 3 últimas copias y una se restaura.
- [ ] **T150** Demo: restablecimiento de contraseña. RF: 81, 82. *Hecho cuando:* la cuenta entra y queda el registro.
- [ ] **T197** Demo: super administrador. RF: 95–104. Dep: T187, T193, T196, T198, T200. *Hecho cuando:* se marca una cuenta con el comando, entra al panel, activa el negocio pendiente de un dueño nuevo, ve un negocio con sus cifras sin datos de fiados, lo suspende y su sincronización se rechaza, lo reactiva, y las acciones aparecen en la auditoría.
- [ ] **T151** Veredicto final: ¿spec cumplida? RF: todos. *Hecho cuando:* se emite el veredicto con los resultados de T142–T150 y T197.
