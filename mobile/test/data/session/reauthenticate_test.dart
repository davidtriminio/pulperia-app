import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';

import '../../support/fake_api.dart';

void main() {
  late FakeApi api;
  late MemorySessionStore store;
  late SessionService service;

  setUp(() {
    api = FakeApi();
    store = MemorySessionStore(
      StoredSession(
        userId: 'u-1',
        email: 'ana@correo.com',
        // La renovación ya caducó: solo falta volver a entrar (D-10).
        tokens: tokensAt(
          api.now.subtract(const Duration(days: 100)),
          refreshFor: const Duration(days: 90),
        ),
        activeBusiness: remoteBusiness('b-1'),
      ),
    );
    service = SessionService(api: api, store: store, now: () => api.now);
  });

  group('volver a entrar para sincronizar (D-10, RF-4)', () {
    test(
      'con la contraseña correcta renueva los tokens y conserva el negocio',
      () async {
        await expectLater(
          service.accessToken(),
          throwsA(isA<SessionExpiredException>()),
        );

        await service.reauthenticate('contrasena1');

        expect(await service.accessToken(), 'access-1');
        expect(store.session?.activeBusiness?.id, 'b-1');
        expect(store.session?.email, 'ana@correo.com');
      },
    );

    test(
      'contraseña mala: el error sube y la sesión queda como estaba',
      () async {
        api.passwords = {'ana@correo.com': 'la-buena'};
        final before = store.session;

        await expectLater(
          service.reauthenticate('la-mala'),
          throwsA(isA<ApiException>()),
        );

        expect(store.session, same(before));
      },
    );

    test('sin red falla sin tocar nada', () async {
      api.offline = true;
      final before = store.session;

      await expectLater(
        service.reauthenticate('contrasena1'),
        throwsA(isA<NetworkException>()),
      );

      expect(store.session, same(before));
    });

    test('si el servidor responde con otro usuario no se acepta', () async {
      api.userId = 'u-2';

      await expectLater(
        service.reauthenticate('contrasena1'),
        throwsA(isA<WrongAccountException>()),
      );
      expect(store.session?.userId, 'u-1');
    });
  });
}
