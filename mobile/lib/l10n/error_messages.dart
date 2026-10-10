import '../data/remote/models.dart';
import '../data/session/session_service.dart';
import 'strings.dart';

/// El mensaje en español de un fallo al hablar con el servidor (RNF-5). Cada
/// código estable de la API tiene su texto; uno desconocido da un mensaje
/// genérico. Una prueba recorre todos los códigos de la API y falla si alguno
/// no tiene mensaje (T120).
String errorMessage(Object error) => switch (error) {
  NetworkException() => Strings.errorOffline,
  SessionExpiredException() => Strings.errorSessionExpired,
  WrongAccountException() => Strings.errorWrongAccount,
  ApiException(:final status, :final code) =>
    errorMessageForCode(code) ??
        (status >= 500 ? Strings.errorServer : Strings.errorUnexpected),
  _ => Strings.errorUnexpected,
};

/// El mensaje de un código de la API (de una respuesta de error o del rechazo
/// de una operación), o null si no se conoce.
String? errorMessageForCode(String code) => _byCode[code];

const _byCode = <String, String>{
  // Cuentas y sesión.
  'invalid_credentials': Strings.errorInvalidCredentials,
  'email_taken': Strings.errorEmailTaken,
  'email_invalid': Strings.errorEmailInvalid,
  'password_too_short': Strings.errorPasswordTooShort,
  'password_too_long': Strings.errorPasswordTooLong,
  'business_name_required': Strings.errorBusinessNameRequired,
  'invalid_refresh_token': Strings.errorSessionExpired,
  'unauthorized': Strings.errorSessionExpired,
  'account_not_found': 'No encontramos esa cuenta.',
  'too_many_attempts':
      'Demasiados intentos. Espera un minuto e inténtalo de nuevo.',
  // Negocio, equipo e invitaciones.
  'business_not_found': 'No encontramos ese negocio.',
  'business_required': 'Elige un negocio para continuar.',
  'forbidden': 'No tienes permiso para hacer esto.',
  'name_required': 'El nombre es obligatorio.',
  'mode_downgrade_not_allowed': 'No se puede pasar de decimales a enteros: cambiaría cómo se leen los registros que ya existen.',
  'amount_mode_invalid': 'El modo de montos no es válido.',
  'quantity_mode_invalid': 'El modo de cantidades no es válido.',
  'already_member': 'Esa persona ya pertenece al negocio.',
  'invitation_already_pending':
      'Ya hay una invitación pendiente para ese correo.',
  'invitation_not_found': 'La invitación ya no existe.',
  'invitation_not_invitee': 'Esa invitación no es para tu cuenta.',
  'invitation_not_pending': 'La invitación ya no está pendiente.',
  'invalid_invitation_code': 'El código no es válido o ya se usó.',
  'registration_ambiguous': 'Elige una sola forma de registrarte: con un negocio nuevo o con un código.',
  'team_already_owner': 'Esa persona ya es dueña del negocio.',
  'team_last_owner': 'El negocio debe tener al menos un dueño.',
  'team_member_not_active': 'Esa persona ya no es parte del equipo.',
  'team_member_not_found': 'No encontramos a esa persona en el equipo.',
  // Solicitudes y cambios enviados por la sincronización.
  'invalid_request': 'La solicitud no es válida.',
  'invalid_payload': 'Los datos del cambio no son válidos.',
  'unknown_operation':
      'La app envió un tipo de cambio que el servidor no conoce.',
  'batch_too_large': 'Se intentaron enviar demasiados cambios a la vez.',
  'op_id_in_use': 'Ese cambio ya se había usado en otro negocio.',
  'entity_already_exists': 'Ese registro ya existía.',
  'base_version_required': 'Falta la versión del registro que se editó.',
  'version_conflict':
      'Otra persona modificó este registro antes y se conservó su versión.',
  // Clientes, productos, fiados y abonos.
  'client_not_found': 'El cliente ya no existe en el negocio.',
  'product_not_found': 'El producto ya no existe en el negocio.',
  'fiado_not_found': 'El fiado ya no existe.',
  'payment_not_found': 'El abono ya no existe.',
  'product_name_required': 'El nombre del producto es obligatorio.',
  'product_unit_unknown': 'La unidad de venta del producto no es válida.',
  'item_unit_unknown':
      'La unidad de venta de un producto del fiado no es válida.',
  'phone_invalid_format': 'El teléfono no es válido.',
  'note_too_long': 'La nota es demasiado larga.',
  'description_too_long': 'La descripción de un producto es demasiado larga.',
  'fiado_empty': 'El fiado no tiene ningún producto ni monto.',
  'too_many_items': 'El fiado tiene demasiados productos.',
  'duplicate_item_id': 'El fiado tiene un producto repetido por error.',
  'subtotal_mismatch': 'El subtotal no coincide con la cantidad y el precio.',
  'total_mismatch': 'El total no coincide con la suma de los productos.',
  'amount_invalid_format': 'El monto no tiene un formato válido.',
  'amount_not_positive': 'El monto debe ser mayor que cero.',
  'amount_not_whole': 'El monto debe ser un número entero.',
  'amount_too_many_decimals': 'El monto tiene demasiados decimales.',
  'amount_too_large': 'El monto es demasiado grande.',
  'quantity_invalid_format': 'La cantidad no tiene un formato válido.',
  'quantity_not_positive': 'La cantidad debe ser mayor que cero.',
  'quantity_not_whole': 'La cantidad debe ser un número entero.',
  'quantity_too_many_decimals': 'La cantidad tiene demasiados decimales.',
  'quantity_too_large': 'La cantidad es demasiado grande.',
};
