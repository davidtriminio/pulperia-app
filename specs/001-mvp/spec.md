# Spec 001 — MVP: administrador de deudas (fiados) para pulperías

## Contexto y objetivo
Las pulperías fían a sus clientes y hoy llevan esas deudas en cuadernos o de memoria. Eso provoca olvidos, discusiones sobre cuánto se debe y por qué, y pérdida total si el cuaderno se extravía. El MVP permite registrar fiados y abonos, saber en todo momento cuánto debe cada cliente y qué compró, y conservar una copia de seguridad de esa información.

La prioridad es la app móvil: debe funcionar siempre, con o sin conexión, porque es la herramienta del mostrador. El cliente web ofrece las mismas operaciones y permisos, pero requiere conexión. El servidor sincroniza los dispositivos y guarda el respaldo.

## Usuarios / actores
- **Dueño**: crea el negocio y tiene control total, incluida la gestión de usuarios, la anulación de movimientos y el archivado de clientes. Un negocio puede tener varios dueños.
- **Empleado**: atiende el mostrador; puede registrar y consultar, pero no anular movimientos, archivar clientes ni gestionar usuarios o el negocio.
- Una misma persona puede pertenecer a varios negocios, con un rol distinto en cada uno.
- **Administrador del servidor**: persona que opera el servidor. Siempre debe existir al menos uno. Marca y retira a los super administradores y restablece contraseñas con comandos en el servidor, fuera de las apps.
- **Super administrador**: cuenta marcada por el administrador del servidor que gestiona la plataforma desde un panel web aparte: activa los negocios nuevos, ve los negocios y las cuentas con cifras de uso, suspende o reactiva negocios y cuentas, restablece contraseñas y consulta la auditoría. **Nunca ve ni modifica los datos de un negocio** (clientes, productos, fiados, abonos, equipo ni ajustes). Siempre debe existir al menos uno.
- **Cliente fiado**: persona a quien se fía. No usa el sistema; es un registro dentro del negocio.

## Historias de usuario
- H1: Como dueño o empleado quiero registrar un fiado a un cliente, con o sin detalle de productos, para saber qué se llevó y cuánto debe.
- H2: Como dueño o empleado quiero registrar un abono de un cliente para reducir su saldo sin tener que decidir a qué ítem corresponde.
- H3: Como dueño o empleado quiero ver el saldo y el historial de un cliente para resolver dudas sobre qué debe y por qué.
- H4: Como dueño quiero anular un movimiento erróneo, dejando constancia, para corregir errores sin perder trazabilidad.
- H5: Como dueño o empleado quiero trabajar sin conexión en el móvil y que los datos se sincronicen después para no depender de internet en el mostrador.
- H6: Como dueño quiero invitar empleados a mi negocio para que atiendan fiados desde su propio dispositivo.
- H7: Como dueño quiero ver la deuda total del negocio y los mayores deudores para saber cuánto dinero tengo en la calle.
- H8: Como dueño quiero recuperar mis datos en un dispositivo nuevo para no perder mi cartera de deudas si se daña o se pierde el teléfono.
- H9: Como dueño o empleado quiero distinguir a clientes con el mismo nombre mediante un avatar personalizable (personaje, tono de piel y fondo) para no fiar a la persona equivocada.
- H10: Como dueño quiero archivar clientes que ya no compran para mantener limpia la lista sin perder su historial.
- H11: Como dueño con más de una pulpería quiero pertenecer a varios negocios y elegir con cuál trabajo.
- H12: Como dueño quiero que mi negocio use montos y cantidades enteros o con decimales, según cómo vende, para que el sistema se adapte a mi forma de trabajar.
- H13: Como dueño o empleado quiero guardar el teléfono, la dirección y una nota de cada cliente para recordar quién es y cómo localizarlo.
- H14: Como dueño quiero promover a un empleado a dueño para que un socio comparta la administración y el negocio nunca quede sin administrador.
- H15: Como usuario que olvidó su contraseña quiero que el administrador del servidor pueda restablecerla para no perder el acceso a mi negocio.
- H16: Como dueño quiero invitar a una persona dándole un código por el medio que prefiera (por ejemplo WhatsApp o en persona), aunque no use el correo con el que la invito, para que entre a mi negocio sin depender del correo.
- H17: Como super administrador quiero ver y gestionar los negocios y las cuentas de la plataforma, sin ver sus fiados, para dar soporte, frenar abusos y conocer el uso del sistema.
- H18: Como super administrador quiero activar a los dueños nuevos antes de que usen la plataforma para controlar quién la usa.

## Requisitos funcionales (criterios de aceptación en EARS)

### Cuentas y negocios
- RF-1: CUANDO una persona crea una cuenta con su correo electrónico y el nombre de su primer negocio, EL SISTEMA creará ese negocio y la asignará a él como dueño.
- RF-78: SI el nombre de un negocio está vacío, ENTONCES EL SISTEMA rechazará la creación e indicará que el nombre es obligatorio.
- RF-79: CUANDO un usuario con sesión iniciada crea un negocio nuevo con nombre, EL SISTEMA lo creará y lo asignará a él como dueño.
- RF-80: CUANDO un dueño cambia el nombre del negocio, EL SISTEMA aplicará el nuevo nombre para todos los usuarios del negocio.
- RF-81: CUANDO el administrador del servidor restablece la contraseña de una cuenta, EL SISTEMA registrará quién lo hizo y cuándo.
- RF-82: EL SISTEMA no expondrá datos de ningún negocio durante el restablecimiento de una contraseña.
- RF-2: EL SISTEMA identificará a cada usuario por su correo electrónico.
- RF-3: EL SISTEMA exigirá conexión para crear una cuenta y para el primer inicio de sesión en un dispositivo.
- RF-4: MIENTRAS un dispositivo tenga una sesión iniciada, EL SISTEMA permitirá usar la app móvil sin conexión durante un tiempo indefinido.
- RF-5: CUANDO un usuario pertenece a más de un negocio, EL SISTEMA le pedirá elegir el negocio con el que trabaja y le permitirá cambiar de negocio.
- RF-6: EL SISTEMA aplicará a un usuario el rol que tenga en el negocio con el que trabaja en ese momento.
- RF-7: CUANDO el dueño crea el negocio, EL SISTEMA le pedirá elegir si los montos son enteros o con 2 decimales, y si las cantidades son enteras o fraccionarias.
- RF-8: CUANDO el dueño cambia un ajuste de montos o cantidades de más restrictivo a más permisivo (de enteros a decimales), EL SISTEMA aplicará el cambio sin modificar los registros existentes.
- RF-9: SI el dueño intenta cambiar un ajuste de montos o cantidades de decimales a enteros, ENTONCES EL SISTEMA rechazará el cambio.
- RF-10: CUANDO un dueño invita a una persona por su correo electrónico, EL SISTEMA creará una invitación pendiente asociada a ese correo, vigente hasta que se acepte o un dueño la cancele.
- RF-67: CUANDO una persona con una invitación pendiente inicia sesión, o crea su cuenta con ese correo, EL SISTEMA le mostrará la invitación para que la acepte o la rechace.
- RF-68: CUANDO una persona acepta una invitación, EL SISTEMA la agregará al negocio con el rol de empleado, sin importar si ya pertenece a otros negocios.
- RF-69: CUANDO un dueño cancela una invitación pendiente, EL SISTEMA impedirá que pueda aceptarse.
- RF-70: CUANDO un dueño promueve a un empleado a dueño, EL SISTEMA le concederá todos los permisos de dueño en ese negocio.
- RF-71: SI una acción dejaría al negocio sin ningún dueño, ENTONCES EL SISTEMA rechazará la acción.
- RF-11: CUANDO el dueño quita a un empleado, EL SISTEMA impedirá que ese usuario siga accediendo a los datos del negocio.
- RF-12: CUANDO un empleado removido sincroniza cambios que registró antes de conocer su remoción, EL SISTEMA los aceptará, sin límite de tiempo desde la remoción, y a continuación le retirará el acceso.
- RF-13: SI un empleado intenta invitar usuarios, quitar usuarios o gestionar el negocio, ENTONCES EL SISTEMA rechazará la acción.

### Clientes
- RF-14: CUANDO un usuario crea un cliente con nombre y con un avatar compuesto por un personaje, un tono de piel y un color de fondo, EL SISTEMA lo registrará dentro del negocio con saldo cero.
- RF-72: EL SISTEMA ofrecerá 24 personajes, 6 tonos de piel y 12 colores de fondo para componer el avatar.
- RF-15: SI se intenta crear un cliente sin nombre, ENTONCES EL SISTEMA rechazará la creación e indicará que el nombre es obligatorio.
- RF-16: SI se intenta crear un cliente sin personaje, tono de piel o fondo elegidos, ENTONCES EL SISTEMA rechazará la creación e indicará qué falta elegir.
- RF-17: SI el nombre de un cliente nuevo coincide con el de otro cliente del negocio (ignorando mayúsculas y espacios exteriores), ENTONCES EL SISTEMA avisará de la coincidencia y permitirá continuar solo si el usuario lo confirma.
- RF-18: EL SISTEMA no exigirá que los avatares de dos clientes sean distintos.
- RF-19: CUANDO un usuario edita el nombre, el avatar, el teléfono, la dirección o la nota de un cliente, EL SISTEMA conservará el historial de movimientos de ese cliente sin cambios.
- RF-73: EL SISTEMA permitirá guardar en cada cliente un teléfono, una dirección y una nota, todos opcionales.
- RF-74: SI la nota de un cliente supera los 300 caracteres, ENTONCES EL SISTEMA rechazará el valor e indicará el límite.
- RF-77: SI el teléfono de un cliente no tiene exactamente 8 dígitos numéricos o no empieza por 2, 3, 8 o 9, ENTONCES EL SISTEMA rechazará el valor e indicará el formato esperado.
- RF-20: CUANDO el dueño archiva un cliente, aunque tenga saldo pendiente, EL SISTEMA lo ocultará de la lista normal y conservará su historial.
- RF-21: SI un empleado intenta archivar un cliente, ENTONCES EL SISTEMA rechazará la acción.
- RF-22: EL SISTEMA ofrecerá una vista de clientes archivados con su saldo.
- RF-23: CUANDO un dueño restaura un cliente archivado, EL SISTEMA lo devolverá a la lista normal con su historial y su saldo.
- RF-75: MIENTRAS un cliente esté archivado, EL SISTEMA permitirá registrarle abonos.
- RF-76: SI un usuario intenta registrar un fiado a un cliente que su dispositivo muestra como archivado, ENTONCES EL SISTEMA rechazará el registro e indicará que el cliente debe restaurarse primero.
- RF-85: CUANDO se sincroniza un fiado registrado en un dispositivo que aún no conocía el archivado del cliente, EL SISTEMA lo aceptará y el cliente seguirá archivado con el saldo actualizado.

### Catálogo de productos
- RF-24: CUANDO un usuario crea un producto con nombre y precio, EL SISTEMA lo agregará al catálogo del negocio.
- RF-25: CUANDO un usuario cambia el precio de un producto del catálogo, EL SISTEMA no modificará ningún ítem de fiado ya registrado.
- RF-26: CUANDO un usuario archiva un producto, EL SISTEMA dejará de ofrecerlo al registrar fiados y conservará su nombre y precio en los ítems ya registrados.
- RF-27: EL SISTEMA no permitirá borrar un producto del catálogo.
- RF-86: EL SISTEMA ofrecerá una lista fija de unidades de venta (unidad, libra, onza, kilo, docena, litro, galón, caja, bolsa y paquete), y cada producto del catálogo tendrá una; la unidad por omisión es "unidad".
- RF-87: CUANDO el usuario elige un producto del catálogo para un ítem, EL SISTEMA propondrá la unidad del producto y permitirá cambiarla solo para ese ítem; un ítem que no pertenece al catálogo también lleva una unidad, "unidad" por omisión.
- RF-88: CUANDO se registra un ítem de fiado, EL SISTEMA guardará su unidad junto con la cantidad y el precio unitario de ese momento, de modo que cambiar la unidad de un producto o archivarlo no altere los ítems ya registrados.
- RF-89: EL SISTEMA tratará la unidad solo como una etiqueta: el precio unitario es por esa unidad y la cantidad se expresa en ella, sin convertir entre unidades y sin cambiar el cálculo del subtotal ni las reglas de cantidad del negocio (RF-35, RF-84).
- RF-90: CUANDO un usuario cambia el precio de un producto, EL SISTEMA guardará junto al producto el precio anterior y la fecha del cambio (sustituyendo los que hubiera) y los mostrará en el catálogo; cambiar solo el nombre o la unidad no los modifica.
- RF-91: SI el nombre de un producto, con su unidad, coincide con el de otro producto no archivado del negocio (ignorando mayúsculas y espacios exteriores), ENTONCES EL SISTEMA avisará de la coincidencia y permitirá continuar solo si el usuario lo confirma, u ofrecerá ir a cambiar el precio del existente; aplica al crear un producto y al cambiar su nombre o su unidad.
- RF-92: CUANDO un dueño crea una invitación, con o sin el correo de la persona, EL SISTEMA le asignará un código de invitación de un solo uso, que el dueño podrá ver mientras la invitación esté pendiente para entregarlo a la persona por el medio que prefiera.
- RF-93: CUANDO una persona con sesión iniciada canjea el código de una invitación pendiente, EL SISTEMA la agregará al negocio con el rol de empleado y marcará la invitación como aceptada, sin importar si su correo coincide con el invitado ni si ya pertenece a otros negocios.
- RF-94: SI el código no existe, ya se usó o su invitación fue cancelada, ENTONCES EL SISTEMA rechazará el canje con el mismo mensaje, sin revelar nada de ningún negocio, y limitará los intentos fallidos de cada usuario.
- RF-95: EL SISTEMA permitirá marcar una cuenta como super administrador y retirarle la marca solo con un comando del servidor, nunca desde una app ni desde el panel, y no permitirá retirar la marca al último super administrador.
- RF-96: SI una cuenta que no es super administrador intenta usar una función de administración de la plataforma, ENTONCES EL SISTEMA rechazará la petición; las sesiones de un super administrador duran menos que las de los demás usuarios.
- RF-97: CUANDO un super administrador lista o busca negocios y cuentas, EL SISTEMA mostrará por negocio su nombre, los correos de sus dueños, el número de miembros, la fecha de creación, su estado (pendiente de activación, activo o suspendido), la fecha de su última sincronización y el total de clientes, productos, fiados y abonos; y por cuenta su correo, fecha de alta, estado y negocios a los que pertenece, sin mostrar nombres de clientes ni de productos, montos, deudas ni ningún otro dato de un negocio; y permitirá filtrar los negocios por estado, en particular los pendientes de activación.
- RF-98: CUANDO un super administrador suspende un negocio indicando un motivo, EL SISTEMA conservará todos sus datos, rechazará sus peticiones y sincronizaciones con un código estable hasta que se reactive, y los dispositivos seguirán funcionando sin conexión con lo que ya tienen.
- RF-99: CUANDO un super administrador suspende una cuenta indicando un motivo, EL SISTEMA cerrará sus sesiones y no le permitirá iniciar sesión hasta que se reactive, sin tocar los negocios a los que pertenece.
- RF-100: CUANDO un super administrador restablece la contraseña de una cuenta desde el panel, EL SISTEMA generará una contraseña nueva, la mostrará una sola vez, cerrará las sesiones de la cuenta y lo registrará como en RF-81.
- RF-101: EL SISTEMA registrará cada acción de un super administrador (quién, cuándo, qué, sobre qué cuenta o negocio y el motivo) en la auditoría, que el panel permitirá consultar y que ninguna acción puede borrar ni editar.
- RF-102: CUANDO una persona se registra y crea su primer negocio, EL SISTEMA creará ese negocio pendiente de activación: su dueño podrá iniciar sesión y ver su estado, pero el negocio rechazará con un código estable cualquier registro de datos o sincronización hasta que un super administrador lo active; la cuenta seguirá pudiendo usar cualquier otro negocio activo al que pertenezca.
- RF-103: CUANDO un super administrador activa un negocio pendiente, EL SISTEMA lo habilitará para trabajar con normalidad y lo registrará en la auditoría; si en cambio lo rechaza indicando un motivo, el negocio quedará suspendido (RF-98).
- RF-104: CUANDO una persona que ya es dueña de al menos un negocio activo crea un negocio adicional (RF-79), EL SISTEMA lo creará activo, sin pasar por la activación.
- RF-105: CUANDO una persona crea una cuenta con su correo electrónico y un código de invitación pendiente, en lugar del nombre de un negocio, EL SISTEMA creará la cuenta sin ningún negocio propio, la agregará al negocio de la invitación con el rol de empleado como en RF-93, marcará la invitación como aceptada e iniciará su sesión; la cuenta no será dueña de ningún negocio.
- RF-106: SI el código del registro no existe, ya se usó o su invitación fue cancelada, ENTONCES EL SISTEMA rechazará el registro con el mismo mensaje que RF-94, sin crear la cuenta, sin consumir ningún código y sin revelar nada de ningún negocio, y limitará los intentos fallidos de cada origen.
- RF-107: SI una solicitud de registro trae a la vez el nombre de un negocio y un código de invitación, ENTONCES EL SISTEMA la rechazará indicando que debe elegirse uno solo.

### Fiados
- RF-28: CUANDO un usuario registra un fiado con uno o más ítems (descripción, cantidad y precio unitario), EL SISTEMA guardará cada ítem con la cantidad y el precio unitario vigentes en ese momento.
- RF-29: CUANDO un usuario registra un fiado indicando solo un monto total, sin detalle de ítems, EL SISTEMA lo aceptará y lo sumará al saldo del cliente.
- RF-30: CUANDO el usuario elige un producto del catálogo para un ítem, EL SISTEMA propondrá el precio del catálogo y permitirá cambiarlo solo para ese ítem.
- RF-31: EL SISTEMA permitirá registrar un ítem de fiado que no pertenezca al catálogo.
- RF-32: SI el monto, la cantidad o el precio de un fiado es cero o negativo, ENTONCES EL SISTEMA rechazará el registro e indicará el campo inválido.
- RF-33: SI el fiado no tiene ítems ni monto total, ENTONCES EL SISTEMA rechazará el registro.
- RF-34: MIENTRAS el negocio tenga montos enteros, EL SISTEMA redondeará al lempira entero más cercano el subtotal de cada ítem (los .5 suben) y guardará el valor redondeado.
- RF-83: MIENTRAS el negocio tenga montos con 2 decimales, EL SISTEMA redondeará al centavo más cercano (los .5 suben) el subtotal de cada ítem y guardará el valor redondeado.
- RF-84: MIENTRAS el negocio tenga cantidades fraccionarias, SI la cantidad tiene más de 3 decimales, ENTONCES EL SISTEMA rechazará el valor.
- RF-35: MIENTRAS el negocio tenga cantidades enteras, SI el usuario ingresa una cantidad con fracción, ENTONCES EL SISTEMA rechazará el valor.
- RF-36: SI un monto ingresado tiene decimales mientras el negocio tiene montos enteros, ENTONCES EL SISTEMA rechazará el valor.

### Abonos
- RF-37: CUANDO un usuario registra un abono con un monto mayor que cero para un cliente, EL SISTEMA lo restará del saldo total del cliente sin asociarlo a ningún ítem concreto.
- RF-38: SI el monto de un abono es cero o negativo, ENTONCES EL SISTEMA rechazará el registro.
- RF-39: SI el abono supera el saldo actual del cliente, ENTONCES EL SISTEMA lo aceptará y mostrará la diferencia como saldo a favor del cliente.

### Saldo e historial
- RF-40: EL SISTEMA calculará el saldo de un cliente como la suma de sus fiados vigentes menos la suma de sus abonos vigentes.
- RF-41: CUANDO un usuario abre un cliente, EL SISTEMA mostrará su saldo y el historial cronológico de fiados (con su detalle de ítems, si lo tienen) y abonos, incluyendo los anulados con marca visible de anulación.
- RF-42: MIENTRAS el saldo de un cliente sea negativo, EL SISTEMA lo mostrará etiquetado como saldo a favor y no como deuda.

### Anulación y corrección
- RF-43: CUANDO el dueño anula un fiado o un abono, EL SISTEMA conservará el registro marcado como anulado, con fecha, hora y usuario que lo anuló.
- RF-44: CUANDO se anula un fiado o un abono, EL SISTEMA excluirá ese movimiento del saldo del cliente.
- RF-45: SI un empleado intenta anular un fiado o un abono, ENTONCES EL SISTEMA rechazará la acción.
- RF-46: EL SISTEMA no permitirá editar ni eliminar definitivamente un fiado o un abono ya registrado.
- RF-47: SI un fiado se anula en un dispositivo y el cliente tiene abonos registrados en otro dispositivo, ENTONCES EL SISTEMA conservará esos abonos y mostrará como saldo a favor el excedente sobre los fiados vigentes.

### Permisos y trazabilidad
- RF-48: EL SISTEMA permitirá al empleado registrar fiados y abonos, crear y editar clientes, administrar el catálogo y consultar el saldo de todos los clientes del negocio.
- RF-49: EL SISTEMA registrará en cada fiado, abono y anulación qué usuario lo realizó.
- RF-50: EL SISTEMA no mostrará ni sincronizará datos de un negocio a usuarios que no pertenezcan a él.

### Funcionamiento sin conexión y sincronización (móvil)
- RF-51: MIENTRAS el dispositivo móvil no tenga conexión, EL SISTEMA permitirá crear, consultar y anular clientes, fiados y abonos, y mostrará los saldos actualizados con esos cambios.
- RF-52: CUANDO el dispositivo móvil recupera la conexión, EL SISTEMA enviará los cambios pendientes y recibirá los cambios hechos por otros dispositivos del negocio.
- RF-53: SI un envío de cambios se repite por un corte o reintento, ENTONCES EL SISTEMA no duplicará ningún fiado, abono ni anulación.
- RF-54: SI dos dispositivos registran fiados o abonos distintos para el mismo cliente sin conexión, ENTONCES EL SISTEMA conservará todos los registros y el saldo será la suma de ellos.
- RF-55: SI dos dispositivos modifican el mismo registro sin conexión, ENTONCES EL SISTEMA conservará la versión del servidor.
- RF-56: SI la sincronización falla, ENTONCES EL SISTEMA conservará los cambios pendientes en el dispositivo y lo intentará de nuevo cuando haya conexión.
- RF-57: MIENTRAS haya cambios sin sincronizar, EL SISTEMA lo indicará al usuario.
- RF-58: CUANDO un usuario inicia sesión en un dispositivo nuevo, EL SISTEMA descargará todos los datos del negocio con el que trabaja.

### Cliente web
- RF-59: EL SISTEMA ofrecerá en la web las mismas operaciones, reglas y permisos que en la app móvil.
- RF-60: CUANDO un usuario realiza una acción en la web, EL SISTEMA la guardará directamente en el servidor.
- RF-61: SI la web no tiene conexión, ENTONCES EL SISTEMA no permitirá registrar cambios e informará de que se requiere conexión.
- RF-62: CUANDO un cambio hecho en la web llega a un móvil en su siguiente sincronización, EL SISTEMA lo tratará con las mismas reglas de conflicto que un cambio de otro móvil.

### Resumen del negocio
- RF-63: CUANDO un usuario abre el resumen del negocio, EL SISTEMA mostrará la deuda total, calculada como la suma de los saldos positivos de los clientes no archivados.
- RF-64: CUANDO un usuario abre el resumen del negocio, EL SISTEMA mostrará aparte el saldo a favor total de los clientes no archivados.
- RF-65: CUANDO un usuario abre el resumen del negocio, EL SISTEMA mostrará la lista de clientes no archivados con mayor saldo adeudado, ordenada de mayor a menor.
- RF-66: EL SISTEMA calculará el resumen en el móvil con los datos locales, incluidos los cambios aún no sincronizados.

## Requisitos no funcionales
- RNF-1: Toda la funcionalidad de la app móvil sobre clientes, catálogo, fiados, abonos, anulaciones, archivado y resumen debe poder usarse con el dispositivo sin ninguna conexión (modo avión), una vez iniciada la sesión. La gestión de cuentas, negocios, invitaciones, equipo y ajustes del negocio requiere conexión.
- RNF-2: Los montos se manejan con exactitud decimal; el saldo no debe diferir ni en un centavo de la suma manual de sus movimientos.
- RNF-3: La moneda es el lempira para todos los negocios.
- RNF-4: Las fechas y horas se almacenan y se intercambian en UTC y se muestran en la hora local del usuario.
- RNF-5: Todos los mensajes al usuario están en español.
- RNF-6: Un negocio nunca debe poder ver, modificar ni recibir datos de otro negocio.
- RNF-7: La sincronización envía y recibe solo lo cambiado desde la última sincronización, no la totalidad de los datos.
- RNF-8: EL SISTEMA realizará una copia diaria de la base de datos del servidor, guardada fuera de la máquina donde corre, y conservará las 3 copias más recientes.

## Casos límite
- Mismo cliente con fiados y abonos creados en dos dispositivos sin conexión: se conservan todos (RF-54).
- Abono sobre un fiado anulado en otro dispositivo: se conserva y queda saldo a favor (RF-47).
- Abono mayor que la deuda: saldo a favor, no error (RF-39).
- Reintento de sincronización tras corte a la mitad: sin duplicados (RF-53).
- Cambio de precio o de unidad en el catálogo tras fiar: no altera lo ya registrado (RF-25, RF-88).
- Un producto vendido por docena con cantidad "2": son 2 docenas al precio de la docena; el sistema no la convierte en 24 unidades (RF-89).
- Empleado removido con cambios sin sincronizar: se aceptan sin límite de tiempo y luego pierde el acceso; si nunca se conecta, sus datos locales permanecen en su teléfono (RF-12).
- Cliente archivado en un dispositivo mientras otro, sin conexión, le registra un fiado: el fiado se acepta y el cliente sigue archivado (RF-85).
- Cantidad con más de 3 decimales: se rechaza (RF-84).
- Dos clientes con el mismo nombre: se avisa y se permite con confirmación; el avatar ayuda a distinguirlos pero puede repetirse (RF-17, RF-18).
- Cantidad fraccionaria con montos enteros: el subtotal se redondea al entero más cercano (RF-34).
- Cliente archivado con saldo pendiente: no cuenta en el resumen pero sí aparece en la vista de archivados; admite abonos pero no fiados (RF-22, RF-63, RF-75, RF-76).
- Invitación a un correo sin cuenta o con cuenta en otro negocio: queda pendiente hasta que la persona la acepte (RF-10, RF-67, RF-68).
- Último dueño que intenta salir o ser quitado: se rechaza (RF-71).
- Nota de cliente de más de 300 caracteres: se rechaza (RF-74).
- Teléfono con otro formato (menos o más de 8 dígitos, prefijo distinto de 2, 3, 8 o 9, letras): se rechaza (RF-77).
- Cambio de montos de decimales a enteros: no se permite, para no dejar saldos inconsistentes (RF-9).
- Acción en la web mientras otro móvil tiene cambios sin sincronizar sobre el mismo registro: gana el servidor (RF-62).
- Código de invitación compartido por error: cualquier persona con sesión que lo canjee antes entra como empleado; el dueño lo evita cancelando la invitación mientras esté pendiente (RF-69) y puede quitar al empleado después (RF-71).
- Super administrador que es también dueño o empleado de un negocio: sus funciones de plataforma y su trabajo en el negocio van separados; en el negocio solo ve lo que le corresponde por su rol.
- Negocio suspendido con operaciones sin sincronizar en los teléfonos: se conservan en la cola y se envían cuando se reactive el negocio (RF-98).
- Dueño con el negocio pendiente de activación: puede iniciar sesión, ve el aviso y no puede registrar datos; los datos que ya tuviera en el teléfono no existen porque nunca pudo registrar ninguno (RF-102). Una invitación a su negocio sigue siendo posible, pero quien la acepte tampoco podrá trabajar hasta que se active.
- Una persona que se registra solo para entrar a otro negocio como empleado: su propio negocio queda pendiente y no le estorba, porque sigue usando el negocio activo al que pertenece (RF-102).

## Fuera de alcance
- Límite de crédito por cliente, con aviso o bloqueo.
- Recordatorios o cobros por WhatsApp, SMS u otros canales.
- Inventario o control de stock.
- Conversión entre unidades de medida (por ejemplo, docena a unidades) y existencias por unidad.
- Fechas de vencimiento o promesas de pago por deuda.
- Intereses, recargos o mora.
- Aplicar un abono a ítems o fiados específicos.
- Editar fiados o abonos ya registrados, y eliminarlos definitivamente.
- Pasarelas de pago o cobro electrónico.
- Que el cliente fiado acceda al sistema o consulte su propia deuda.
- Avatares con foto tomada o subida por el usuario (queda para una iteración posterior).
- Acciones desde la app sobre el teléfono del cliente (llamar, enviar mensajes): solo se guarda como dato.
- Transferir la propiedad en un solo paso: se resuelve con la promoción a dueño.
- Caducidad automática de invitaciones.
- Recuperación de contraseña por parte del propio usuario (por correo u otro medio).
- Un rol o menú de superadministración dentro de las apps de las pulperías (el panel de la plataforma es aparte).
- Que el super administrador vea o edite datos de un negocio, o entre a un negocio como si fuera un usuario.
- Planes, cobros o facturación de la plataforma.
- Avisos por correo o mensaje cuando un negocio se activa, se rechaza o se suspende: el dueño ve el estado al abrir la app.
- Autenticación de dos factores para el super administrador.
- Borrado remoto de los datos locales de un empleado removido.
- Teléfonos de otros países o con código de país: el formato actual es el de Honduras y podrá ampliarse después.
- Funcionamiento de la web sin conexión.
- Otras monedas distintas del lempira.
- Inicio de sesión por teléfono o por proveedores externos.
- Caducidad de la sesión por inactividad sin conexión.
- Importar datos desde cuadernos, hojas de cálculo u otros sistemas.
- Facturación o comprobantes fiscales.

## Criterios de finalización
- Cada RF y RNF tiene al menos una prueba automatizada en verde, o una verificación manual documentada cuando no sea automatizable.
- Demo manual del flujo principal en un teléfono en modo avión: crear cliente con avatar personalizado (personaje, tono y fondo), teléfono, dirección y nota, fiar con detalle, fiar monto libre, abonar, ver saldo e historial.
- Demo manual de sincronización con dos dispositivos: ambos fían al mismo cliente sin conexión, se sincronizan y el saldo coincide en los dos.
- Demo manual de recuperación: iniciar sesión en un dispositivo nuevo y ver todos los datos del negocio.
- Demo manual de permisos: un empleado no puede anular, archivar ni gestionar usuarios; el dueño sí.
- Demo manual de la web: realizar las mismas operaciones principales y comprobar que aparecen en el móvil tras sincronizar.
- Demo manual del super administrador: marcar una cuenta con el comando, entrar al panel, activar el negocio pendiente de un dueño recién registrado (y comprobar que antes de eso no podía registrar nada), ver un negocio con sus cifras sin ningún dato de fiados, suspenderlo y comprobar que su sincronización se rechaza, reactivarlo, y ver las acciones en la auditoría.
- Demo manual de ajustes del negocio: un negocio con enteros y otro con decimales y cantidades fraccionarias muestran los montos esperados.
- Demo manual de respaldo: comprobar que existen las 3 copias diarias más recientes fuera del servidor y que una se puede restaurar.
- Demo manual de restablecimiento: el administrador del servidor restablece una contraseña, la cuenta puede entrar y queda el registro de quién y cuándo.
- Ningún RF de esta spec queda sin implementar y nada fuera de ella está implementado.

## Dudas abiertas
Ninguna. Todas las dudas quedaron resueltas.
