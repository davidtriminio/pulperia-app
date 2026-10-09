/// Qué está mal en los datos de una cuenta o de un negocio (RF-1, RF-2, RF-78).
/// La interfaz lo traduce al español; el servidor vuelve a comprobarlo todo.
enum AccountError {
  emailRequired,
  emailInvalid,
  passwordRequired,
  passwordTooShort,
  passwordTooLong,
  businessNameRequired,
}

/// Largo mínimo y máximo de la contraseña (D-27). Sin reglas de composición.
const minPasswordLength = 8;
const maxPasswordLength = 128;

/// El correo (se recorta): obligatorio y con forma `algo@algo`, igual que el
/// servidor.
AccountError? validateEmail(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) {
    return AccountError.emailRequired;
  }
  final at = trimmed.indexOf('@');
  final valid =
      at > 0 &&
      at < trimmed.length - 1 &&
      trimmed.indexOf('@', at + 1) < 0 &&
      !trimmed.contains(RegExp(r'\s'));
  return valid ? null : AccountError.emailInvalid;
}

/// La contraseña tal cual se escribió (los espacios cuentan).
AccountError? validatePassword(String password) {
  if (password.isEmpty) {
    return AccountError.passwordRequired;
  }
  if (password.length < minPasswordLength) {
    return AccountError.passwordTooShort;
  }
  if (password.length > maxPasswordLength) {
    return AccountError.passwordTooLong;
  }
  return null;
}

/// El nombre del negocio es obligatorio (RF-78).
AccountError? validateBusinessName(String name) =>
    name.trim().isEmpty ? AccountError.businessNameRequired : null;
