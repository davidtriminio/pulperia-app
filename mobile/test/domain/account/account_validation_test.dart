import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/account/account_validation.dart';

void main() {
  group('correo (RF-2)', () {
    test('vacío o en blanco es obligatorio', () {
      expect(validateEmail(''), AccountError.emailRequired);
      expect(validateEmail('   '), AccountError.emailRequired);
    });

    test('debe tener forma de dirección: algo@algo', () {
      for (final bad in ['ana', 'ana@', '@correo.com', 'a b@correo.com']) {
        expect(validateEmail(bad), AccountError.emailInvalid, reason: bad);
      }
    });

    test('un correo válido, con espacios alrededor, se acepta', () {
      expect(validateEmail('ana@correo.com'), isNull);
      expect(validateEmail('  Ana@Correo.com '), isNull);
    });
  });

  group('contraseña (D-27)', () {
    test('vacía es obligatoria', () {
      expect(validatePassword(''), AccountError.passwordRequired);
    });

    test('de 8 a 128 caracteres', () {
      expect(validatePassword('1234567'), AccountError.passwordTooShort);
      expect(validatePassword('12345678'), isNull);
      expect(validatePassword('a' * 128), isNull);
      expect(validatePassword('a' * 129), AccountError.passwordTooLong);
    });

    test('los espacios cuentan: no se recorta', () {
      expect(validatePassword('        '), isNull);
    });
  });

  group('nombre del negocio (RF-78)', () {
    test('vacío o en blanco se rechaza', () {
      expect(validateBusinessName(''), AccountError.businessNameRequired);
      expect(validateBusinessName('   '), AccountError.businessNameRequired);
    });

    test('con texto se acepta', () {
      expect(validateBusinessName(' Pulpería Ana '), isNull);
    });
  });
}
