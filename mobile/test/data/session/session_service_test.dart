import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import '../../support/fake_api.dart';

void main() {
  late FakeApi api;
  late MemorySessionStore store;
  late DateTime now;
  late SessionService service;

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 15);
    api = FakeApi(now: now);
    store = MemorySessionStore();
    service = SessionService(api: api, store: store, now: () => now);
  });

  group('iniciar sesión (RF-3)', () {
    test(
      'guarda al usuario y sus tokens en el almacenamiento seguro',
      () async {
        final session = await service.login('ana@correo.com', 'contrasena1');

        expect(session.userId, 'u-1');
        expect(session.email, 'ana@correo.com');
        expect(session.tokens.accessToken, 'access-1');
        expect(session.activeBusiness, isNull);
        expect(store.session?.tokens.refreshToken, 'refresh-1');
      },
    );

    test('el correo se recorta y se guarda en minúsculas', () async {
      final session = await service.login('  Ana@Correo.COM ', 'contrasena1');

      expect(session.email, 'ana@correo.com');
    });

    test(
      'credenciales malas: el error de la API sube y no se guarda nada',
      () async {
        api.passwords = {'ana@correo.com': 'la-buena'};

        await expectLater(
          service.login('ana@correo.com', 'la-mala'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'invalid_credentials',
            ),
          ),
        );
        expect(store.session, isNull);
      },
    );

    test('sin conexión el primer inicio falla y no se guarda nada', () async {
      api.offline = true;

      await expectLater(
        service.login('ana@correo.com', 'contrasena1'),
        throwsA(isA<NetworkException>()),
      );
      expect(store.session, isNull);
    });
  });

  group('registrarse con un código de invitación (RF-105, RF-106)', () {
    const business = RemoteBusiness(
      id: 'b-9',
      name: 'Abarrotes Cata',
      role: Role.employee,
      amountMode: AmountMode.integer,
      quantityMode: QuantityMode.integer,
    );

    setUp(() => api.redeemable = {'H4N8TW3R': business});

    test(
      'crea la cuenta sin negocio propio y deja la sesión iniciada',
      () async {
        final session = await service.registerWithInvitationCode(
          email: ' Dana@Correo.com ',
          password: 'contrasena1',
          invitationCode: 'h4n8-tw3r',
        );

        expect(api.calls, ['registerWithInvitationCode', 'login']);
        expect(session.email, 'dana@correo.com');
        expect(store.session?.tokens.accessToken, 'access-1');
        expect(api.businesses.map((b) => b.id), ['b-9']);
      },
    );

    test(
      'un código que no sirve: el error sube y no se inicia sesión',
      () async {
        await expectLater(
          service.registerWithInvitationCode(
            email: 'dana@correo.com',
            password: 'contrasena1',
            invitationCode: 'AAAA-AAAA',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'invalid_invitation_code',
            ),
          ),
        );
        expect(api.calls, ['registerWithInvitationCode']);
        expect(store.session, isNull);
      },
    );

    test('sin conexión no se crea nada', () async {
      api.offline = true;

      await expectLater(
        service.registerWithInvitationCode(
          email: 'dana@correo.com',
          password: 'contrasena1',
          invitationCode: 'H4N8-TW3R',
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(store.session, isNull);
    });
  });

  group('registrarse (RF-1, RF-2, RF-78)', () {
    test('crea la cuenta con su negocio y deja la sesión iniciada', () async {
      final session = await service.register(
        email: 'ana@correo.com',
        password: 'contrasena1',
        businessName: 'Pulpería Ana',
        amountMode: AmountMode.twoDecimals,
        quantityMode: QuantityMode.fractional,
      );

      // El registro no devuelve tokens: se inicia sesión a continuación.
      expect(api.calls, ['register', 'login']);
      expect(session.userId, 'u-1');
      expect(store.session?.tokens.accessToken, 'access-1');
      expect(api.businesses.single.name, 'Pulpería Ana');
    });

    test(
      'si el correo ya existe, el error sube y no se inicia sesión',
      () async {
        api.failures['register'] = const ApiException(409, 'email_taken', [
          'email_taken',
        ]);

        await expectLater(
          service.register(
            email: 'ana@correo.com',
            password: 'contrasena1',
            businessName: 'Pulpería Ana',
            amountMode: AmountMode.integer,
            quantityMode: QuantityMode.integer,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'email_taken'),
          ),
        );
        expect(api.calls, ['register']);
        expect(store.session, isNull);
      },
    );

    test('sin conexión no se crea nada', () async {
      api.offline = true;

      await expectLater(
        service.register(
          email: 'ana@correo.com',
          password: 'contrasena1',
          businessName: 'Pulpería Ana',
          amountMode: AmountMode.integer,
          quantityMode: QuantityMode.integer,
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(store.session, isNull);
    });
  });

  group('la sesión sobrevive a reiniciar la app (RF-3)', () {
    test('restaurar con un servicio nuevo devuelve la misma sesión', () async {
      await service.login('ana@correo.com', 'contrasena1');
      await service.saveActiveBusiness(remoteBusiness('b-1'));

      final restarted = SessionService(api: api, store: store, now: () => now);
      final restored = await restarted.restore();

      expect(restored?.userId, 'u-1');
      expect(restored?.email, 'ana@correo.com');
      expect(restored?.activeBusiness?.id, 'b-1');
      expect(restored?.tokens.refreshToken, 'refresh-1');
    });

    test('sin sesión guardada no hay nada que restaurar', () async {
      expect(await service.restore(), isNull);
    });

    test('restaurar no necesita red', () async {
      await service.login('ana@correo.com', 'contrasena1');
      api
        ..offline = true
        ..calls.clear();

      expect(await service.restore(), isNotNull);
      expect(api.calls, isEmpty);
    });
  });

  group('cerrar sesión', () {
    test('avisa al servidor con el token y borra lo guardado', () async {
      await service.login('ana@correo.com', 'contrasena1');

      await service.logout();

      expect(api.calls, ['login', 'logout']);
      expect(store.session, isNull);
    });

    test('sin conexión igualmente cierra la sesión del teléfono', () async {
      await service.login('ana@correo.com', 'contrasena1');
      api.offline = true;

      await service.logout();

      expect(store.session, isNull);
    });

    test('cerrar sin sesión no falla', () async {
      await service.logout();

      expect(api.calls, isEmpty);
    });
  });

  group('token de acceso vigente', () {
    test('devuelve el actual mientras no esté por caducar', () async {
      await service.login('ana@correo.com', 'contrasena1');

      expect(await service.accessToken(), 'access-1');
      expect(api.count('refresh'), 0);
    });

    test(
      'lo renueva poco antes de caducar y guarda los tokens nuevos',
      () async {
        await service.login('ana@correo.com', 'contrasena1');
        now = now.add(const Duration(minutes: 14, seconds: 45));

        final token = await service.accessToken();

        expect(token, 'access-2');
        expect(api.count('refresh'), 1);
        expect(store.session?.tokens.refreshToken, 'refresh-2');
      },
    );

    test('renovar sin conexión falla sin tocar lo guardado', () async {
      await service.login('ana@correo.com', 'contrasena1');
      now = now.add(const Duration(minutes: 20));
      api.offline = true;

      await expectLater(
        service.accessToken(),
        throwsA(isA<NetworkException>()),
      );
      expect(store.session?.tokens.accessToken, 'access-1');
    });

    test('con el token de renovación caducado pide iniciar sesión', () async {
      await service.login('ana@correo.com', 'contrasena1');
      now = now.add(const Duration(days: 91));

      await expectLater(
        service.accessToken(),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(api.count('refresh'), 0);
    });

    test('sin sesión pide iniciar sesión', () async {
      await expectLater(
        service.accessToken(),
        throwsA(isA<SessionExpiredException>()),
      );
    });
  });

  group('almacenamiento seguro', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('escribe y lee la sesión completa, con el negocio activo', () async {
      final secure = SecureSessionStore();
      final session = StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        tokens: tokensAt(now),
        activeBusiness: remoteBusiness('b-1'),
      );

      await secure.write(session);
      final read = await SecureSessionStore().read();

      expect(read?.userId, 'u-1');
      expect(
        read?.tokens.accessExpiresAt,
        now.add(const Duration(minutes: 15)),
      );
      expect(read?.activeBusiness?.name, 'Pulpería Ana');
      expect(read?.activeBusiness?.role.id, 'owner');
    });

    test('clear la borra', () async {
      final secure = SecureSessionStore();
      await secure.write(
        StoredSession(userId: 'u', email: 'a@b.c', tokens: tokensAt(now)),
      );

      await secure.clear();

      expect(await secure.read(), isNull);
    });

    test('un valor que no se entiende se trata como sin sesión', () async {
      FlutterSecureStorage.setMockInitialValues({'pulperia.session': 'basura'});

      expect(await SecureSessionStore().read(), isNull);
    });
  });
}
