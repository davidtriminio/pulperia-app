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

  static const clientsEmpty = 'Aún no hay clientes';
  static const catalogEmpty = 'Aún no hay productos';
}
