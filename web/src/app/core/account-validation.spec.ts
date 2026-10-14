import { validateBusinessName, validateEmail, validatePassword } from './account-validation';

describe('validación de cuenta y negocio (RF-1, RF-2, RF-78)', () => {
  it('el correo es obligatorio y tiene forma algo@algo', () => {
    expect(validateEmail('')).toBe('emailRequired');
    expect(validateEmail('   ')).toBe('emailRequired');
    expect(validateEmail('ana')).toBe('emailInvalid');
    expect(validateEmail('ana@')).toBe('emailInvalid');
    expect(validateEmail('@correo.com')).toBe('emailInvalid');
    expect(validateEmail('a b@correo.com')).toBe('emailInvalid');
    expect(validateEmail('a@b@c.com')).toBe('emailInvalid');
    expect(validateEmail(' ana@correo.com ')).toBeNull();
  });

  it('la contraseña tiene entre 8 y 128 caracteres y cuenta tal cual', () => {
    expect(validatePassword('')).toBe('passwordRequired');
    expect(validatePassword('1234567')).toBe('passwordTooShort');
    expect(validatePassword('12345678')).toBeNull();
    expect(validatePassword('a'.repeat(128))).toBeNull();
    expect(validatePassword('a'.repeat(129))).toBe('passwordTooLong');
    expect(validatePassword('        ')).toBeNull();
  });

  it('el nombre del negocio no puede estar vacío', () => {
    expect(validateBusinessName('')).toBe('businessNameRequired');
    expect(validateBusinessName('   ')).toBe('businessNameRequired');
    expect(validateBusinessName('Pulpería Ana')).toBeNull();
  });
});
