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
  static const clientNotFound = 'El cliente ya no existe';
  static const saveError = 'No se pudo guardar';

  static const clientDetail = 'Cliente';
  static const editAction = 'Editar';
  static const archivedBadge = 'Archivado';
  static const historyTitle = 'Historial';
  static const historyEmpty = 'Aún no hay movimientos';
  static const entryFiado = 'Fiado';
  static const entryPayment = 'Abono';
  static const annulled = 'Anulado';
  static const annulledOn = 'Anulado el';

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
  static const registerPayment = 'Abonar';
  static const fieldPaymentAmount = 'Monto del abono';
  static const currentBalance = 'Saldo actual';
  static const balanceAfter = 'Quedaría';

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
  static const catalogEmpty = 'Aún no hay productos';
}
