/// Textos visibles de la app, todos en español (RNF-5). La interfaz no escribe
/// cadenas sueltas: las toma de aquí.
abstract final class Strings {
  static const appTitle = 'Pulpería';

  static const clients = 'Clientes';
  static const catalog = 'Catálogo';

  static const avatar = 'Avatar';
  static const avatarCharacter = 'Personaje';
  static const avatarSkin = 'Tono de piel';
  static const avatarBackground = 'Fondo';
  static const avatarStepCharacter = 'Personaje';
  static const avatarStepSkin = 'Piel';
  static const avatarStepBackground = 'Fondo';
  static const avatarChooseCharacterHint = 'Elige un personaje para continuar';
  static const avatarNext = 'Siguiente';
  static const avatarBack = 'Atrás';
  static const avatarDone = 'Listo';
  static const avatarMissingCharacter = 'Falta elegir el personaje';
  static const avatarMissingSkin = 'Falta elegir el tono de piel';
  static const avatarMissingBackground = 'Falta elegir el fondo';
  static const continueAction = 'Continuar';

  static const balanceDebt = 'Debe';
  static const balanceCredit = 'A favor';
  static const balanceSettled = 'Al día';
  static const loadError = 'No se pudo cargar la información';

  static const newClient = 'Nuevo cliente';
  static const editClient = 'Editar cliente';
  static const chooseAvatar = 'Elegir avatar';
  static const changeAvatar = 'Cambiar avatar';
  static const fieldName = 'Nombre';
  static const fieldPhone = 'Teléfono (opcional)';
  static const fieldAddress = 'Dirección (opcional)';
  static const fieldNote = 'Nota (opcional)';
  static const save = 'Guardar';
  static const cancel = 'Cancelar';
  static const nameRequired = 'El nombre es obligatorio';
  static const noteTooLong = 'La nota no puede superar los 300 caracteres';
  static const phoneInvalid =
      'El teléfono debe tener 8 dígitos y empezar por 2, 3, 8 o 9';
  static const homonymTitle = 'Ya hay un cliente con ese nombre';
  static const homonymBody =
      'Existe otro cliente con el mismo nombre en este negocio. '
      '¿Quieres guardar de todos modos?';
  static const homonymConfirm = 'Guardar de todos modos';
  static const duplicateProductTitle = 'Ya existe un producto igual';
  static const duplicateCreateConfirm = 'Crear de todos modos';
  static const duplicateOpenExisting = 'Cambiar el precio del existente';
  static const previousPriceLabel = 'Antes';
  static const priceChangedOn = 'cambió el';
  static const clientNotFound = 'El cliente ya no existe';
  static const saveError = 'No se pudo guardar';

  static const clientDetail = 'Cliente';
  static const editAction = 'Editar';
  static const archivedBadge = 'Archivado';
  static const archiveClientTitle = '¿Archivar este cliente?';
  static const archiveClientBody =
      'Saldrá de la lista de clientes, aunque tenga saldo pendiente. Su '
      'historial y su saldo se conservan y puedes restaurarlo cuando quieras.';
  static const archiveClientConfirm = 'Sí, archivar';
  static const archiveClientTooltip = 'Archivar cliente';
  static const restoreClientTooltip = 'Restaurar cliente';
  static const clientArchivedDone = 'Cliente archivado';
  static const clientRestoredDone = 'Cliente restaurado';
  static const archivedClientsAction = 'Archivados';
  static const archivedClientsTitle = 'Clientes archivados';
  static const archivedClientsEmpty = 'No hay clientes archivados';
  static const historyTitle = 'Historial';
  static const historyEmpty = 'Aún no hay movimientos';
  static const entryFiado = 'Fiado';
  static const entryPayment = 'Abono';
  static const annulled = 'Anulado';
  static const annulledOn = 'Anulado el';
  static const annulAction = 'Anular';
  static const annulFiadoTitle = '¿Anular este fiado?';
  static const annulPaymentTitle = '¿Anular este abono?';
  static const annulFiadoBody =
      'Dejará de contar en el saldo del cliente. El registro se conserva '
      'marcado como anulado, con la fecha y quién lo anuló. No se puede '
      'deshacer.';
  static const annulPaymentBody =
      'El abono dejará de restar del saldo del cliente. El registro se '
      'conserva marcado como anulado, con la fecha y quién lo anuló. No se '
      'puede deshacer.';
  static const annulConfirm = 'Sí, anular';
  static const annulKeep = 'No anular';
  static const annulDone = 'Movimiento anulado';

  static const amountNotPositive = 'El monto debe ser mayor que cero';
  static const amountNotWhole = 'Este negocio usa montos enteros, sin centavos';
  static const amountTooManyDecimals = 'Usa como máximo 2 decimales';
  static const amountInvalid =
      'Escribe un monto válido, por ejemplo 25 o 25.50';

  static const quantityNotPositive = 'La cantidad debe ser mayor que cero';
  static const quantityNotWhole = 'Este negocio usa cantidades enteras';
  static const quantityTooManyDecimals = 'Usa como máximo 3 decimales';
  static const quantityInvalid =
      'Escribe una cantidad válida, por ejemplo 2 o 0.5';
  static const quantityRequired = 'Indica la cantidad';
  static const subtotalZero =
      'El subtotal queda en cero: sube la cantidad o el precio';

  static const newFiado = 'Registrar fiado';
  static const registerFiado = 'Fiar';
  static const itemNumber = 'Ítem';
  static const fieldDescription = 'Descripción (opcional)';
  static const fieldQuantity = 'Cantidad';
  static const fieldUnitPrice = 'Precio unitario';
  static const subtotalLabel = 'Subtotal';
  static const totalLabel = 'Total';
  static const addItem = 'Agregar ítem';
  static const removeItem = 'Quitar ítem';
  static const clientArchivedFiado =
      'Este cliente está archivado: restáuralo antes de fiarle';
  static const fiadoEmpty = 'Agrega al menos un ítem';

  static const newPayment = 'Registrar abono';
  static const payFull = 'Saldo completo';
  static const registerPayment = 'Abonar';
  static const fieldPaymentAmount = 'Monto del abono';
  static const currentBalance = 'Saldo actual';
  static const balanceAfter = 'Quedaría';

  static const searchProducts = 'Buscar producto';
  static const noProductsFound = 'No hay productos con ese nombre';
  static const seeAllProducts = 'Ver todos';
  static const addAction = 'Agregar';
  static const allProducts = 'Todos los productos';
  static const doneAction = 'Listo';
  static const cartTitle = 'Lo que se lleva';
  static const cartEmptyHint = 'Toca un producto para agregarlo';
  static const freeItem = 'Ítem libre';
  static const editItem = 'Editar ítem';
  static const addFreeItem = 'Otro (ítem libre)';
  static const priceMissing = 'Falta el precio';
  static const lessOne = 'Quitar uno';
  static const moreOne = 'Agregar uno';
  static const fiadoMissingPrice = 'Falta el precio de algún ítem';

  static const modeItems = 'Con detalle';
  static const modeTotal = 'Solo monto';
  static const fieldTotal = 'Monto total';
  static const totalRequired = 'Indica el monto';
  static const pickFromCatalog = 'Elegir del catálogo';
  static const fromCatalog = 'Del catálogo';
  static const unlinkProduct = 'Quitar vínculo con el catálogo';

  static const fieldUnit = 'Unidad de venta';
  static const perUnit = 'por';

  static const newProduct = 'Nuevo producto';
  static const editProduct = 'Editar producto';
  static const fieldProductName = 'Nombre del producto';
  static const fieldPrice = 'Precio';
  static const productNameRequired = 'El nombre del producto es obligatorio';
  static const priceRequired = 'Indica el precio';
  static const archiveProduct = 'Archivar';
  static const archiveProductTitle = '¿Archivar este producto?';
  static const archiveProductBody =
      'Dejará de ofrecerse al fiar. Los fiados ya registrados no cambian.';
  static const productNotFound = 'El producto ya no existe';

  static const clientsEmpty = 'Aún no hay clientes';
  static const summary = 'Resumen';
  static const summaryDebtTotal = 'Total que te deben';
  static const summaryCreditTotal = 'Saldo a favor de clientes';
  static const summaryTopDebtors = 'Mayores deudores';
  static const summaryNoDebtors = 'Nadie debe nada por ahora';
  static const catalogEmpty = 'Aún no hay productos';

  // Sesión y errores de la API (T088; el recorrido completo de códigos es T120).
  static const errorOffline =
      'Sin conexión. Conéctate a internet para continuar.';
  static const errorUnexpected = 'Algo salió mal. Inténtalo de nuevo.';
  static const errorServer =
      'El servidor tuvo un problema. Inténtalo de nuevo en unos minutos.';
  static const errorInvalidCredentials = 'Correo o contraseña incorrectos';
  static const errorEmailTaken = 'Ya existe una cuenta con ese correo';
  static const errorEmailInvalid = 'El correo no es válido';
  static const errorPasswordTooShort = 'La contraseña es muy corta';
  static const errorPasswordTooLong = 'La contraseña es muy larga';
  static const errorBusinessNameRequired =
      'El nombre del negocio es obligatorio';
  static const errorSessionExpired =
      'Tu sesión terminó. Inicia sesión de nuevo.';
  static const signInRequired = 'Inicia sesión para continuar';

  // Registro, inicio de sesión y elección de negocio (T105).
  static const signInTitle = 'Inicia sesión';
  static const signInSubtitle = 'Entra para ver los fiados de tu negocio';
  static const signInAction = 'Entrar';
  static const createAccountTitle = 'Crea tu cuenta';
  static const createAccountSubtitle =
      'Registra tu negocio para llevar sus fiados';
  static const createAccountAction = 'Crear cuenta';
  static const registerHasCode = 'Me invitaron con un código';
  static const registerHasCodeHint =
      'Entrarás como empleado del negocio que te invitó, sin crear uno propio.';
  static const createAccountWithCodeSubtitle =
      'Crea tu cuenta para entrar al negocio que te invitó';
  static const goToRegister = 'Crear una cuenta';
  static const goToLogin = 'Ya tengo una cuenta';
  static const fieldEmail = 'Correo electrónico';
  static const fieldPassword = 'Contraseña';
  static const fieldBusinessName = 'Nombre del negocio';
  static const showPassword = 'Mostrar contraseña';
  static const hidePassword = 'Ocultar contraseña';
  static const emailRequired = 'Escribe tu correo';
  static const emailInvalid = 'El correo no es válido';
  static const passwordRequired = 'Escribe tu contraseña';
  static const passwordTooShort =
      'La contraseña debe tener al menos 8 caracteres';
  static const passwordTooLong = 'La contraseña es muy larga';
  static const passwordHint = 'Mínimo 8 caracteres';
  static const businessNameRequired = 'El nombre del negocio es obligatorio';
  static const amountModeTitle = 'Montos';
  static const amountModeInteger = 'Enteros';
  static const amountModeDecimals = 'Con centavos';
  static const amountModeHint = 'Ejemplo: L 25 o L 25.50';
  static const amountModeRequired = 'Elige cómo manejas los montos';
  static const quantityModeTitle = 'Cantidades';
  static const quantityModeInteger = 'Enteras';
  static const quantityModeFractional = 'Con decimales';
  static const quantityModeHint = 'Ejemplo: 2 libras o 0.5 libras';
  static const quantityModeRequired = 'Elige cómo manejas las cantidades';
  static const modesCannotReturn =
      'Más adelante podrás pasar de enteros a decimales, pero no al revés';

  static const chooseBusinessTitle = 'Elige tu negocio';
  static const chooseBusinessSubtitle = 'Con cuál quieres trabajar ahora';
  static const noBusinesses = 'Aún no perteneces a ningún negocio';
  static const noBusinessesHint =
      'Crea uno o pide que te inviten a uno existente';
  static const roleOwner = 'Dueño';
  static const roleEmployee = 'Empleado';
  static const createBusiness = 'Crear un negocio';
  static const newBusinessTitle = 'Nuevo negocio';
  static const createBusinessAction = 'Crear negocio';
  static const retry = 'Reintentar';
  static const businessPendingTitle = 'Tu negocio está pendiente de activación';
  static const businessPendingBody =
      'Lo revisa quien administra la plataforma. Cuando lo active podrás registrar clientes y fiados.';
  static const businessPendingQueue =
      'Lo que registraste en este teléfono está guardado y se enviará solo cuando se active.';
  static const businessStillPending =
      'Todavía no está activo. Inténtalo más tarde.';
  static const businessCheck = 'Comprobar ahora';
  static const businessSuspended =
      'Este negocio está suspendido. Sigues viendo lo que ya tienes y lo que registres se enviará cuando se reactive.';
  static const businessSuspendedShort = 'Negocio suspendido';
  static const accountSuspended =
      'Tu cuenta está suspendida. Comunícate con quien administra la plataforma.';
  static const statusPending = 'Pendiente de activación';
  static const statusSuspended = 'Suspendido';

  static const menu = 'Menú';
  static const switchBusiness = 'Cambiar de negocio';
  static const syncNow = 'Sincronizar ahora';
  static const menuRejected = 'Cambios no aplicados';
  static const rejectedTitle = 'Cambios no aplicados';
  static const rejectedIntro =
      'El servidor no aceptó estos cambios y no se vuelven a enviar solos. Puedes descartarlos.';
  static const rejectedEmpty = 'No hay cambios sin aplicar.';
  static const rejectedDiscard = 'Descartar';
  static const codeCopied = 'Código copiado';
  static const copyCode = 'Copiar código';
  static const inviteEmailOptional = 'Correo (opcional)';
  static const inviteHelp =
      'Sin correo, la persona entra escribiendo el código de la invitación.';
  static const redeemAction = 'Tengo un código';
  static const redeemTitle = 'Entrar con un código';
  static const redeemHint =
      'Escribe el código que te dio el dueño del negocio.';
  static const redeemSend = 'Entrar al negocio';
  static const fieldCode = 'Código';
  static const codeRequired = 'Escribe el código';
  static const invitedTo = 'Te invitaron a unirte a';
  static const acceptInvitation = 'Aceptar';
  static const rejectInvitation = 'Rechazar';
  static const menuTeam = 'Equipo';
  static const teamTitle = 'Equipo';
  static const teamMembers = 'Miembros';
  static const teamInvitations = 'Invitaciones pendientes';
  static const noInvitations = 'No hay invitaciones pendientes.';
  static const youMarker = '(tú)';
  static const promoteAction = 'Hacer dueño';
  static const promoteConfirmTitle = '¿Hacer dueño a esta persona?';
  static String promoteConfirmBody(String email) =>
      '$email podrá hacer todo en el negocio: ajustes, equipo, anular movimientos y archivar clientes.';
  static const removeAction = 'Quitar del negocio';
  static const removeConfirmTitle = '¿Quitar a esta persona?';
  static String removeConfirmBody(String email) =>
      '$email dejará de ver los datos del negocio. Si tiene cambios sin enviar, podrá enviarlos una última vez.';
  static const inviteAction = 'Invitar';
  static const inviteTitle = 'Invitar a una persona';
  static const inviteSend = 'Enviar invitación';
  static const inviteSent = 'Invitación enviada';
  static const invitationPending = 'Pendiente';
  static const codeOnlyInvitation = 'Solo con código';
  static const cancelInvitation = 'Cancelar invitación';
  static const keepInvitation = 'Mantenerla';
  static const cancelInvitationTitle = '¿Cancelar la invitación?';
  static String cancelInvitationBody(String? email) => email == null
      ? 'El código dejará de servir.'
      : '$email ya no podrá aceptarla.';
  static const settingsTitle = 'Ajustes del negocio';
  static const menuSettings = 'Ajustes del negocio';
  static const saveChanges = 'Guardar cambios';
  static const settingsOnline =
      'Los cambios de ajustes se hacen con conexión y los ven todos los usuarios del negocio.';
  static String pendingChanges(int count) =>
      count == 1 ? '1 sin enviar' : '$count sin enviar';
  static const syncNeedsLogin = 'Inicia sesión para sincronizar';
  static String businessRemoved(String name) =>
      'Ya no tienes acceso a "$name". Sus datos se borraron de este teléfono.';
  static const reauthTitle = 'Vuelve a entrar';
  static String reauthSubtitle(String email) =>
      'Tu sesión caducó mientras no había conexión. Tus cambios siguen guardados en este teléfono; escribe la contraseña de $email para enviarlos.';
  static const reauthAction = 'Entrar y sincronizar';
  static const errorWrongAccount =
      'Esa contraseña es de otra cuenta. Entra con la cuenta de este teléfono.';
  static String conflictsDiscarded(int count) => count == 1
      ? 'Se descartó 1 cambio tuyo: otra persona había modificado ese registro antes.'
      : 'Se descartaron $count cambios tuyos: otras personas habían modificado esos registros antes.';
  static const logout = 'Cerrar sesión';
  static const logoutConfirmTitle = '¿Cerrar sesión?';
  static const logoutConfirmBody = 'Para volver a entrar necesitarás conexión.';

  static const logoutBlockedTitle = 'Hay cambios sin enviar';
  static String logoutBlockedBody(int count) =>
      'Tienes $count ${count == 1 ? 'cambio sin enviar' : 'cambios sin enviar'} '
      'al servidor. '
      'Sincroniza antes de cerrar sesión: si otra persona entra en este '
      'teléfono, quedarían a su nombre.';
  static const understood = 'Entendido';
}
