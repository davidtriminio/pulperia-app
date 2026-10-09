import '../data/remote/models.dart';
import '../data/session/session_service.dart';
import 'strings.dart';

/// El mensaje en español de un fallo al hablar con el servidor (RNF-5). Cada
/// código estable de la API tiene su texto; uno desconocido da un mensaje
/// genérico. T120 comprueba que no quede ningún código sin traducir.
String errorMessage(Object error) => switch (error) {
  NetworkException() => Strings.errorOffline,
  SessionExpiredException() => Strings.errorSessionExpired,
  ApiException(:final code) => _byCode[code] ?? Strings.errorUnexpected,
  _ => Strings.errorUnexpected,
};

const _byCode = <String, String>{
  'invalid_credentials': Strings.errorInvalidCredentials,
  'email_taken': Strings.errorEmailTaken,
  'email_invalid': Strings.errorEmailInvalid,
  'password_too_short': Strings.errorPasswordTooShort,
  'password_too_long': Strings.errorPasswordTooLong,
  'business_name_required': Strings.errorBusinessNameRequired,
  'invalid_refresh_token': Strings.errorSessionExpired,
  'unauthorized': Strings.errorSessionExpired,
};
