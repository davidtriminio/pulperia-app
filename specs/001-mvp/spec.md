# Spec 001 — MVP: administrador de deudas (fiados) para pulperías

## Contexto y objetivo
Las pulperías fían a sus clientes y hoy llevan esas deudas en cuadernos o de memoria. Eso provoca olvidos, discusiones sobre cuánto se debe y por qué, y pérdida total si el cuaderno se extravía. El MVP permite registrar fiados y abonos, saber en todo momento cuánto debe cada cliente y qué compró, y conservar una copia de seguridad de esa información.

La prioridad es la app móvil: debe funcionar siempre, con o sin conexión, porque es la herramienta del mostrador. El cliente web ofrece las mismas operaciones y permisos, pero requiere conexión. El servidor sincroniza los dispositivos y guarda el respaldo.

## Usuarios / actores
- **Dueño**: crea el negocio y tiene control total, incluida la gestión de usuarios, la anulación de movimientos y el archivado de clientes. Un negocio puede tener varios dueños.
- **Empleado**: atiende el mostrador; puede registrar y consultar, pero no anular movimientos, archivar clientes ni gestionar usuarios o el negocio.
- Una misma persona puede pertenecer a varios negocios, con un rol distinto en cada uno.
- **Administrador del servidor**: persona que opera el servidor. Siempre debe existir al menos uno. Su única intervención sobre las cuentas es restablecer contraseñas, fuera de las apps.
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
- Panel o rol de superadministración dentro de las apps.
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
- Demo manual de ajustes del negocio: un negocio con enteros y otro con decimales y cantidades fraccionarias muestran los montos esperados.
- Demo manual de respaldo: comprobar que existen las 3 copias diarias más recientes fuera del servidor y que una se puede restaurar.
- Demo manual de restablecimiento: el administrador del servidor restablece una contraseña, la cuenta puede entrar y queda el registro de quién y cuándo.
- Ningún RF de esta spec queda sin implementar y nada fuera de ella está implementado.

## Dudas abiertas
Ninguna. Todas las dudas quedaron resueltas.
