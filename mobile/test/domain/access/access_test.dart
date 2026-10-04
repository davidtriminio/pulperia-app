import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/domain/access/access.dart';

void main() {
  group('Role', () {
    test('se identifica con ids estables', () {
      expect(Role.fromId('owner'), Role.owner);
      expect(Role.fromId('employee'), Role.employee);
    });

    test('un id desconocido lanza ArgumentError', () {
      expect(() => Role.fromId('admin'), throwsArgumentError);
    });
  });

  group('permisos del dueño', () {
    test('el dueño puede hacerlo todo', () {
      for (final permission in Permission.values) {
        expect(can(Role.owner, permission), isTrue, reason: '$permission');
      }
    });
  });

  group('permisos del empleado (RF-13, RF-21, RF-45, RF-48)', () {
    const allowed = {
      Permission.viewClients,
      Permission.createClient,
      Permission.editClient,
      Permission.registerFiado,
      Permission.registerPayment,
      Permission.manageCatalog,
      Permission.viewSummary,
    };
    const denied = {
      Permission.annulMovement,
      Permission.archiveClient,
      Permission.restoreClient,
      Permission.manageTeam,
      Permission.manageBusinessSettings,
    };

    test('puede registrar fiados y abonos, crear y editar clientes, administrar el catálogo y consultar saldos (RF-48)', () {
      for (final permission in allowed) {
        expect(can(Role.employee, permission), isTrue, reason: '$permission');
      }
    });

    test('no puede anular fiados ni abonos (RF-45)', () {
      expect(can(Role.employee, Permission.annulMovement), isFalse);
    });

    test('no puede archivar ni restaurar clientes (RF-21)', () {
      expect(can(Role.employee, Permission.archiveClient), isFalse);
      expect(can(Role.employee, Permission.restoreClient), isFalse);
    });

    test('no puede gestionar el equipo ni los ajustes del negocio (RF-13)', () {
      expect(can(Role.employee, Permission.manageTeam), isFalse);
      expect(can(Role.employee, Permission.manageBusinessSettings), isFalse);
    });

    test('lo permitido y lo denegado cubren todos los permisos, sin repetir ninguno', () {
      expect(allowed.intersection(denied), isEmpty);
      expect({...allowed, ...denied}, Permission.values.toSet());
    });

    test('exactamente los permisos denegados son los que can rechaza', () {
      final rejected = {
        for (final p in Permission.values)
          if (!can(Role.employee, p)) p,
      };

      expect(rejected, denied);
    });
  });

  group('comprobación para la interfaz', () {
    test('un rol nulo (sin negocio activo) no puede hacer nada', () {
      for (final permission in Permission.values) {
        expect(canOrNone(null, permission), isFalse, reason: '$permission');
      }
    });

    test('con rol, canOrNone coincide con can', () {
      for (final role in Role.values) {
        for (final permission in Permission.values) {
          expect(canOrNone(role, permission), can(role, permission));
        }
      }
    });
  });
}
