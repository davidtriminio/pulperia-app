/// Qué está mal en los datos de una cuenta o de un negocio (RF-1, RF-2, RF-78). El servidor
/// vuelve a comprobarlo todo; esto solo evita ir a la red por un error evidente.
export type AccountError =
  | 'emailRequired'
  | 'emailInvalid'
  | 'passwordRequired'
  | 'passwordTooShort'
  | 'passwordTooLong'
  | 'businessNameRequired';

/// Largo mínimo y máximo de la contraseña (D-27). Sin reglas de composición.
export const minPasswordLength = 8;
export const maxPasswordLength = 128;

export const accountErrorMessages: Record<AccountError, string> = {
  emailRequired: 'Escribe tu correo',
  emailInvalid: 'El correo no es válido',
  passwordRequired: 'Escribe tu contraseña',
  passwordTooShort: 'La contraseña debe tener al menos 8 caracteres',
  passwordTooLong: 'La contraseña es muy larga',
  businessNameRequired: 'El nombre del negocio es obligatorio',
};

/// El correo (se recorta): obligatorio y con forma `algo@algo`, igual que el servidor.
export function validateEmail(email: string): AccountError | null {
  const trimmed = email.trim();
  if (trimmed === '') return 'emailRequired';
  const at = trimmed.indexOf('@');
  const valid =
    at > 0 && at < trimmed.length - 1 && trimmed.indexOf('@', at + 1) < 0 && !/\s/.test(trimmed);
  return valid ? null : 'emailInvalid';
}

/// La contraseña tal cual se escribió (los espacios cuentan).
export function validatePassword(password: string): AccountError | null {
  if (password === '') return 'passwordRequired';
  if (password.length < minPasswordLength) return 'passwordTooShort';
  if (password.length > maxPasswordLength) return 'passwordTooLong';
  return null;
}

/// El nombre del negocio es obligatorio (RF-78).
export function validateBusinessName(name: string): AccountError | null {
  return name.trim() === '' ? 'businessNameRequired' : null;
}
