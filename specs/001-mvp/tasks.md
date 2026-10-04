# Tareas 001 — MVP: administrador de deudas (fiados) para pulperías

Estado: BORRADOR, pendiente de aprobación. Deriva de `plan.md` (aprobado) y cubre `spec.md` (RF-1 a RF-85, RNF-1 a RNF-8).

## Cómo se trabaja
- **Una tarea cada vez.** Al terminarla, se marca y se para.
- **Tests primero**: se escriben los tests de la tarea, se ven fallar, se implementa y se ejecuta la suite del proyecto tocado. Una tarea no se marca hecha con la suite en rojo.
- Cada tarea cabe en menos de 30 minutos. Si una crece, se divide antes de seguir.
- Las tareas van en orden de dependencia. Salvo que se indique `Dep:`, cada tarea depende solo de las anteriores de su fase y las fases dependen de las anteriores.
- Commit por tarea, en Conventional Commits con el scope que corresponda (`api`, `mobile`, `web`, `specs`, `docs`, `repo`).
- Los vectores de `shared/` se leen desde los tests de cada plataforma; ninguna plataforma redefine esos casos.

## Bloqueos externos
- **T103**: necesita las 24 ilustraciones de personajes. Es trabajo gráfico, no de código.
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
- [x] **T035** Repositorio de fiados: crear con ítems o solo total. RF: 8, 28, 29, 31, 49, 51. Dep: T020. *Hecho cuando:* el fiado y su operación se guardan juntos, con el usuario que lo registró; un ítem sin producto del catálogo se acepta.
- [x] **T036** Repositorio de fiados: rechazo para clientes archivados. RF: 76. *Hecho cuando:* el intento falla con el error esperado y no deja operación en la cola.
- [ ] **T037** Repositorio de abonos: crear, también para clientes archivados. RF: 37, 75. Dep: T021. *Hecho cuando:* un abono a un archivado se guarda y reduce su saldo.
- [ ] **T038** Anulación de fiados y abonos con usuario y fecha. RF: 43, 44, 45, 46, 49. Dep: T025. *Hecho cuando:* el movimiento anulado se conserva, no cuenta en el saldo, el empleado no puede anular y no existe operación de borrar ni de editar.
- [ ] **T039** Consultas de saldo e historial. RF: 40, 41, 42. Dep: T022, T027. *Hecho cuando:* el historial incluye anulados marcados y el saldo negativo se identifica como saldo a favor.
- [ ] **T040** Consulta del resumen sobre datos locales. RF: 66. Dep: T026. *Hecho cuando:* incluye cambios aún no sincronizados.

## Fase 3b — Tramo de prueba del móvil, sin servidor (para probar la app pronto)
Lleva a esta altura las pantallas de clientes, fiados, abonos y catálogo, que antes estaban en la Fase 9, para poder usar la app en el emulador, en modo avión, antes de construir la API. Se usa un negocio y un usuario de desarrollo fijos (T040a) que T088 reemplaza por la sesión real. Las tareas T100, T101, T102, T104, T106 a T112 y T115 se movieron aquí sin cambiar su contenido; solo se les añadió `Dep:`.

- [ ] **T040a** Sesión simulada solo para desarrollo: un negocio de prueba y un usuario dueño, con los modos de montos y cantidades definidos por constantes. RF: —. Dep: T040. *Hecho cuando:* en depuración la app arranca con ese negocio y usuario activos, y un test comprueba que en modo release no están disponibles. Se elimina en T088.
- [ ] **T040b** Cableado de la app: añadir Riverpod (D-11) y los proveedores de la base local, del negocio activo y del usuario activo. RF: —. Dep: T040a. *Hecho cuando:* un test de widget lee el negocio activo desde un `ProviderScope` con una base en memoria.
- [ ] **T100** Navegación, tema y textos en español. RF: —; RNF-5. Dep: T040b. *Hecho cuando:* ninguna cadena visible está en otro idioma y la navegación llega a cada sección.
- [ ] **T101** Widget de avatar compuesto (personaje, tono y fondo). RF: 14, 72. Dep: T028, T040b. *Hecho cuando:* test de widget con varias combinaciones.
- [ ] **T102** Formato de personaje con tono parametrizable y 3 personajes de prueba. RF: 72. Dep: T040b. *Hecho cuando:* los 3 se ven con los 6 tonos y 12 fondos en un test de widget.
- [ ] **T104** Selector de avatar. RF: 14, 16. Dep: T101, T102. *Hecho cuando:* no se puede continuar sin elegir personaje, tono y fondo.
- [ ] **T106** Lista de clientes con saldo. RF: 20, 42. Dep: T040a, T040b, T033, T039, T100. *Hecho cuando:* los archivados no aparecen y el saldo a favor se distingue de la deuda.
- [ ] **T107** Crear y editar cliente con teléfono, dirección, nota y aviso de homónimo. RF: 14–19, 73, 74, 77. Dep: T032, T104, T024. *Hecho cuando:* un homónimo muestra el aviso y solo continúa si se confirma.
- [ ] **T108** Detalle de cliente con saldo e historial. RF: 41, 42. Dep: T039, T106. *Hecho cuando:* los anulados aparecen con marca visible.
- [ ] **T109** Formulario de fiado con ítems. RF: 28, 32, 33, 34, 83, 84. Dep: T035, T020, T108. *Hecho cuando:* el subtotal se muestra redondeado según el modo del negocio.
- [ ] **T110** Elegir producto del catálogo o escribir un ítem libre, y cambiar el precio solo para ese ítem. RF: 30, 31. Dep: T034, T109. *Hecho cuando:* el precio del catálogo no cambia al modificarlo en el ítem.
- [ ] **T111** Fiado por monto total. RF: 29, 33. Dep: T035, T108. *Hecho cuando:* se registra sin ítems y suma al saldo.
- [ ] **T112** Formulario de abono. RF: 37, 38, 39, 75. Dep: T037, T108. *Hecho cuando:* un abono mayor que la deuda deja saldo a favor y un cliente archivado sí admite abonos.
- [ ] **T115** Catálogo: lista, alta, cambio de precio y archivado. RF: 24–27. Dep: T034, T100. *Hecho cuando:* empleado y dueño pueden administrarlo y no hay opción de borrar.
- [ ] **T040c** Prueba manual del tramo en el emulador, en modo avión: crear clientes con avatar, fiar con ítems y por total, abonar, ver saldo e historial, y comprobar que todo sigue al reiniciar la app. RF: 14, 28, 29, 37, 40, 41; RNF-1. Dep: T106–T112, T115. *Hecho cuando:* se recorre el flujo sin errores y se anotan los cambios de pantalla que se quieren antes de seguir.

## Fase 4 — Dominio de la API (.NET, sin EF ni HTTP)
- [ ] **T041** Dinero y cantidad en unidad menor y milésimas. RF: 84; RNF-2. Dep: T013. *Hecho cuando:* pasan los vectores y no hay `double` ni `float` en el dominio.
- [ ] **T042** Subtotales con ambos modos. RF: 34, 83. Dep: T006, T007. *Hecho cuando:* pasan los vectores de T006 y T007.
- [ ] **T043** Validación de fiado y abono. RF: 28, 29, 32, 33, 35, 36, 37, 38. *Hecho cuando:* los casos coinciden con los del móvil (T020, T021).
- [ ] **T044** Cálculo de saldo. RF: 39, 40, 42, 44, 47. Dep: T008. *Hecho cuando:* pasan los vectores de saldo.
- [ ] **T045** Validación de cliente y producto. RF: 15, 16, 24, 74, 77. Dep: T009, T011, T012. *Hecho cuando:* pasan los vectores correspondientes.
- [ ] **T046** Permisos por rol. RF: 13, 21, 45, 48. *Hecho cuando:* la matriz coincide con la del móvil (T025).
- [ ] **T047** Resumen del negocio. RF: 63, 64, 65. Dep: T010. *Hecho cuando:* pasan los vectores de resumen.
- [ ] **T048** Reglas de ajustes del negocio. RF: 7, 8, 9. Dep: T013. *Hecho cuando:* pasan los vectores de transiciones.
- [ ] **T049** Reglas de equipo: promoción, baja y último dueño. RF: 70, 71. *Hecho cuando:* toda acción que dejaría el negocio sin dueño se rechaza.
- [ ] **T050** Reglas de invitación: estados y transiciones. RF: 10, 67, 68, 69. *Hecho cuando:* solo se puede aceptar o rechazar una invitación pendiente y una cancelada no se acepta.

## Fase 5 — Persistencia y aplicación de operaciones (API)
- [ ] **T051** Persistencia de usuarios, negocios, pertenencias e invitaciones con migración. RF: 1, 2, 10. Dep: T049, T050. *Hecho cuando:* una prueba de integración contra PostgreSQL real crea y lee cada tabla.
- [ ] **T052** Persistencia de clientes y productos. RF: 14, 24. *Hecho cuando:* integración contra PostgreSQL real.
- [ ] **T053** Persistencia de fiados, ítems y abonos. RF: 28, 37. *Hecho cuando:* integración contra PostgreSQL real.
- [ ] **T054** Persistencia de `change_log`, `processed_ops`, contador por negocio y `admin_audit`. RF: 53, 81. *Hecho cuando:* integración contra PostgreSQL real.
- [ ] **T055** Aislamiento por `business_id`. RF: 50; RNF-6. *Hecho cuando:* una prueba con dos negocios demuestra que ninguna consulta devuelve datos del otro.
- [ ] **T056** Aplicar operaciones de cliente (crear, editar con versión, archivar, restaurar). RF: 14–23, 55, 73. Dep: T045, T052. *Hecho cuando:* una edición con versión desfasada se rechaza con código de conflicto.
- [ ] **T057** Aplicar operaciones de producto (crear, cambiar precio, archivar). RF: 24, 25, 26, 27. *Hecho cuando:* no existe operación de borrar producto.
- [ ] **T058** Aplicar la creación de fiado. RF: 28–36, 49, 83, 84, 85. Dep: T043, T053. *Hecho cuando:* cada fiado guarda el usuario que lo registró y un fiado a un cliente archivado se acepta si lo originó un dispositivo que no conocía el archivado.
- [ ] **T059** Aplicar la creación de abono. RF: 37, 38, 39, 49, 75. *Hecho cuando:* un abono mayor que la deuda se acepta y deja saldo a favor, y cada abono guarda el usuario que lo registró.
- [ ] **T060** Aplicar anulaciones de fiado y abono, idempotentes. RF: 43, 44, 46, 47, 49. *Hecho cuando:* cada anulación guarda usuario y fecha, y anular dos veces el mismo movimiento no cambia nada ni falla.
- [ ] **T061** Comprobar permisos de rol en cada operación. RF: 13, 21, 45, 48. Dep: T046. *Hecho cuando:* un empleado que intenta anular o archivar recibe rechazo.
- [ ] **T062** Registrar cada operación aplicada en `change_log` con su `seq`, de forma atómica. RF: 52. *Hecho cuando:* una falla a mitad de operación no deja `seq` huérfano.

## Fase 6 — Cuentas, negocios y equipo (API)
- [ ] **T063** Registro con correo, contraseña y nombre de negocio. RF: 1, 2, 78. Dep: T051. *Hecho cuando:* crea usuario, negocio y pertenencia de dueño; sin nombre de negocio se rechaza.
- [ ] **T064** Inicio de sesión, renovación y cierre de sesión. RF: 3, 4. *Hecho cuando:* el token de acceso caduca, el de renovación lo reemplaza y tras cerrar sesión deja de servir.
- [ ] **T065** Crear negocio adicional y listar negocios con rol. RF: 5, 6, 79. *Hecho cuando:* un usuario con dos negocios los ve con su rol en cada uno.
- [ ] **T066** Negocio activo en cada petición con comprobación de pertenencia. RF: 50, 6. *Hecho cuando:* una petición a un negocio ajeno recibe rechazo.
- [ ] **T067** Leer y cambiar ajustes y nombre del negocio (solo dueño). RF: 7, 8, 9, 80. Dep: T048. *Hecho cuando:* pasar de decimales a enteros se rechaza y un empleado no puede cambiar nada.
- [ ] **T068** Crear invitación, listar pendientes del usuario, aceptar y rechazar. RF: 10, 67, 68. Dep: T050. *Hecho cuando:* al aceptar entra como empleado aunque ya pertenezca a otros negocios.
- [ ] **T069** Cancelar invitación. RF: 69. *Hecho cuando:* una invitación cancelada no puede aceptarse.
- [ ] **T070** Listar equipo y promover a dueño. RF: 70. *Hecho cuando:* el promovido recibe todos los permisos de dueño.
- [ ] **T071** Quitar usuario con protección del último dueño. RF: 11, 71. *Hecho cuando:* el usuario quitado pierde acceso y no se puede quitar al último dueño.
- [ ] **T072** Rechazar gestión de equipo y negocio para empleados. RF: 13. *Hecho cuando:* todas las rutas de gestión devuelven rechazo a un empleado.
- [ ] **T073** Comando del servidor para restablecer una contraseña, con auditoría. RF: 81, 82. Dep: T054. *Hecho cuando:* cambia la contraseña, escribe en `admin_audit` quién y cuándo, y su salida no muestra datos de negocios.

## Fase 7 — Sincronización y consultas (API)
- [ ] **T074** Endpoint de envío de lote con resultado por operación. RF: 52. Dep: T056–T062. *Hecho cuando:* cada operación del lote devuelve aplicada, duplicada o rechazada con código.
- [ ] **T075** Idempotencia por `op_id`. RF: 53. *Hecho cuando:* reenviar el mismo lote tres veces deja un solo fiado, abono o anulación.
- [ ] **T076** Conflicto de versión: gana el servidor. RF: 55. *Hecho cuando:* una edición con versión anterior se rechaza y no sobrescribe.
- [ ] **T077** Fiados y abonos concurrentes del mismo cliente desde dos dispositivos. RF: 54. *Hecho cuando:* tras ambos envíos el saldo es la suma de todos.
- [ ] **T078** Anulación de un fiado con abonos de otro dispositivo. RF: 47. *Hecho cuando:* los abonos se conservan y el saldo queda a favor.
- [ ] **T079** Endpoint de cambios por cursor, paginado. RF: 52; RNF-7. *Hecho cuando:* devuelve solo lo posterior al cursor y en páginas.
- [ ] **T080** Descarga inicial desde cursor cero. RF: 58. *Hecho cuando:* un cursor vacío entrega todo el negocio y nada de otros negocios.
- [ ] **T081** Empleado removido: último lote y revocación. RF: 11, 12. *Hecho cuando:* su primer envío tras la baja se acepta, el siguiente se rechaza, y no hay límite de tiempo.
- [ ] **T082** Prueba de fiado a cliente archivado por otro dispositivo. RF: 85. *Hecho cuando:* el fiado se acepta y el cliente sigue archivado con el saldo actualizado.
- [ ] **T083** Endpoint de operación individual para la web. RF: 59, 60. *Hecho cuando:* una operación enviada se aplica y devuelve su resultado al instante.
- [ ] **T084** Consultas de lectura: clientes con saldo, historial, archivados, productos. RF: 22, 41, 42, 59. *Hecho cuando:* cada consulta respeta el aislamiento del negocio.
- [ ] **T085** Consulta del resumen. RF: 63, 64, 65. Dep: T047. *Hecho cuando:* pasan los vectores de resumen desde el servidor.
- [ ] **T086** Contrato OpenAPI en `shared/`. RF: —; D-17. *Hecho cuando:* una prueba verifica que las respuestas reales coinciden con el contrato.

## Fase 8 — Sesión y sincronización del móvil
- [ ] **T087** Cliente HTTP y modelos del contrato. RF: —. Dep: T086. *Hecho cuando:* tests contra respuestas de ejemplo del contrato.
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

- [ ] **T103** Incorporar los 24 personajes finales. RF: 72. Dep: T102 e ilustraciones. *Hecho cuando:* existen los 24 y el test confirma que cada identificador de la paleta tiene su recurso.
- [ ] **T105** Pantallas de registro, inicio de sesión y elección de negocio. RF: 1–6, 78, 79. Dep: T088, T089. *Hecho cuando:* un usuario se registra, entra y elige negocio con mensajes de error en español.
- [ ] **T113** Acción de anular, visible solo para el dueño. RF: 43, 44, 45. *Hecho cuando:* el empleado no ve la acción y el dueño anula con confirmación.
- [ ] **T114** Archivar y restaurar cliente y vista de archivados. RF: 20–23, 76. *Hecho cuando:* solo el dueño ve las acciones y fiar a un archivado muestra que debe restaurarse primero.
- [ ] **T116** Resumen del negocio. RF: 63–66. *Hecho cuando:* muestra deuda total, saldo a favor total y mayores deudores, sin archivados.
- [ ] **T117** Equipo: invitar, cancelar, promover y quitar. RF: 10, 11, 13, 69, 70, 71. *Hecho cuando:* solo los dueños ven la sección y el último dueño no se puede quitar.
- [ ] **T118** Invitaciones recibidas: aceptar o rechazar. RF: 67, 68. *Hecho cuando:* se muestran al iniciar sesión y al aceptar el negocio aparece en la lista.
- [ ] **T119** Ajustes y nombre del negocio. RF: 7, 8, 9, 80. *Hecho cuando:* pasar de decimales a enteros no se ofrece.
- [ ] **T120** Mensajes de error en español para cada código de la API. RNF-5. *Hecho cuando:* una prueba recorre todos los códigos y ninguno queda sin mensaje.
- [ ] **T121** Verificación del flujo principal en modo avión. RNF-1. *Hecho cuando:* en un dispositivo o emulador sin red se completa el flujo de clientes, fiados, abonos, anulación y resumen.

## Fase 10 — Cliente web
- [ ] **T122** Dominio web: validaciones de formulario con los vectores. RF: 15, 17, 32, 34, 35, 36, 74, 77, 83, 84. Dep: T006, T007, T009, T012, T013. *Hecho cuando:* pasan los vectores en `ng test`.
- [ ] **T123** Servicio de sesión, interceptor y detección de falta de conexión. RF: 3, 61. *Hecho cuando:* sin conexión toda escritura se bloquea con aviso en español.
- [ ] **T124** Servicios de operaciones y de consultas. RF: 59, 60. *Hecho cuando:* tests contra respuestas de ejemplo del contrato.
- [ ] **T125** Registro, inicio de sesión y elección de negocio. RF: 1–6, 78, 79. *Hecho cuando:* flujo completo con errores en español.
- [ ] **T126** Componente de avatar con la paleta compartida. RF: 14, 72. *Hecho cuando:* test con varias combinaciones.
- [ ] **T127** Lista de clientes y crear/editar con aviso de homónimo. RF: 14–19, 73, 74, 77. *Hecho cuando:* mismas reglas que el móvil.
- [ ] **T128** Detalle de cliente con historial. RF: 41, 42. *Hecho cuando:* los anulados aparecen marcados.
- [ ] **T129** Registrar fiado y abono. RF: 28–39, 75, 83, 84. *Hecho cuando:* el subtotal redondeado coincide con los vectores.
- [ ] **T130** Anular movimientos (solo dueño). RF: 43, 44, 45. *Hecho cuando:* el empleado no ve la acción.
- [ ] **T131** Archivar, restaurar y vista de archivados. RF: 20–23, 76. *Hecho cuando:* solo el dueño archiva y restaura.
- [ ] **T132** Catálogo. RF: 24–27. *Hecho cuando:* alta, precio y archivado funcionan sin opción de borrar.
- [ ] **T133** Resumen. RF: 63, 64, 65. *Hecho cuando:* coincide con el resultado del móvil para los mismos datos.
- [ ] **T134** Equipo y ajustes del negocio. RF: 7–13, 67–71, 80. *Hecho cuando:* solo los dueños acceden y el empleado recibe rechazo.
- [ ] **T135** Efecto de los cambios hechos en la web sobre los móviles. RF: 62. *Hecho cuando:* una prueba entre web simulada y móvil simulado muestra el cambio tras sincronizar.

## Fase 11 — Despliegue y respaldo
- [ ] **T136** Docker Compose con API y PostgreSQL. RF: —. *Hecho cuando:* `docker compose up` deja la API respondiendo y migrada.
- [ ] **T137** Entrega de la web estática desde el despliegue. RF: 59. *Hecho cuando:* la web carga y llega a la API.
- [ ] **T138** Servicio de copia diaria con rotación de 3. RNF-8. *Hecho cuando:* tras 4 ejecuciones quedan exactamente las 3 más recientes.
- [ ] **T139** Script de restauración en una base vacía. RNF-8. *Hecho cuando:* una copia restaurada pasa una consulta de integridad sobre los datos.
- [ ] **T140** Definir el destino de las copias fuera del servidor. RNF-8. Dep: tu decisión. *Hecho cuando:* queda documentado y el servicio de copia envía allí el archivo.
- [ ] **T141** Documentar el comando de restablecimiento de contraseña. RF: 81. *Hecho cuando:* un tercero lo ejecuta siguiendo solo la documentación.

## Fase 12 — Validación
- [ ] **T142** Recorrido RF por RF: qué test cubre cada uno y su resultado. RF: 1–85. *Hecho cuando:* existe una tabla con los 85 RF y los 8 RNF, cada uno con test o demo y resultado.
- [ ] **T143** Demo: flujo principal en modo avión. RNF-1. *Hecho cuando:* se completa sin errores en un teléfono o emulador sin red.
- [ ] **T144** Demo: dos dispositivos con fiados concurrentes. RF: 54. *Hecho cuando:* el saldo coincide en los dos.
- [ ] **T145** Demo: recuperación en dispositivo nuevo. RF: 58. *Hecho cuando:* se ven todos los datos del negocio.
- [ ] **T146** Demo: permisos de empleado y dueño. RF: 13, 21, 45, 48. *Hecho cuando:* el empleado no puede anular, archivar ni gestionar equipo.
- [ ] **T147** Demo: web con las operaciones principales. RF: 59–62. *Hecho cuando:* lo hecho en la web aparece en el móvil tras sincronizar.
- [ ] **T148** Demo: ajustes de negocio con enteros y con decimales. RF: 7, 8, 9, 34, 83. *Hecho cuando:* dos negocios muestran los montos esperados.
- [ ] **T149** Demo: respaldo y restauración. RNF-8. *Hecho cuando:* existen las 3 últimas copias y una se restaura.
- [ ] **T150** Demo: restablecimiento de contraseña. RF: 81, 82. *Hecho cuando:* la cuenta entra y queda el registro.
- [ ] **T151** Veredicto final: ¿spec cumplida? RF: todos. *Hecho cuando:* se emite el veredicto con los resultados de T142–T150.
