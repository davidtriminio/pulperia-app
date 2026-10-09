import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/session/business_service.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late MemorySessionStore store;
  late SessionService sessions;
  late BusinessService businesses;

  setUp(() async {
    db = openDb();
    api = FakeApi();
    store = MemorySessionStore();
    sessions = SessionService(api: api, store: store, now: () => api.now);
    businesses = BusinessService(
      sessions: sessions,
      api: api,
      db: db,
      now: () => api.now,
    );
    await sessions.login('ana@correo.com', 'contrasena1');
    api.calls.clear();
  });

  tearDown(() => db.close());

  group('listar los negocios del usuario (RF-5, RF-6)', () {
    test(
      'trae los del servidor con su rol y los guarda en el teléfono',
      () async {
        api.businesses = [
          remoteBusiness('b-1'),
          remoteBusiness(
            'b-2',
            name: 'Abarrotes Beto',
            role: Role.employee,
            amountMode: AmountMode.integer,
            quantityMode: QuantityMode.integer,
          ),
        ];

        final list = await businesses.refresh();

        expect(list.map((b) => (b.id, b.role)), [
          ('b-1', Role.owner),
          ('b-2', Role.employee),
        ]);
        final rows = await db.select(db.businesses).get();
        expect(rows.map((b) => b.name).toSet(), {
          'Pulpería Ana',
          'Abarrotes Beto',
        });
        final beto = rows.firstWhere((b) => b.id == 'b-2');
        expect((beto.amountMode, beto.quantityMode), ('integer', 'integer'));
        final memberships = await db.select(db.memberships).get();
        expect(
          memberships.map((m) => (m.userId, m.businessId, m.role)).toSet(),
          {('u-1', 'b-1', 'owner'), ('u-1', 'b-2', 'employee')},
        );
      },
    );

    test(
      'repetir la consulta no duplica nada y refleja los cambios del servidor',
      () async {
        api.businesses = [remoteBusiness('b-1')];
        await businesses.refresh();
        api.businesses = [
          remoteBusiness(
            'b-1',
            name: 'Pulpería Ana (nueva)',
            role: Role.employee,
            amountMode: AmountMode.integer,
          ),
        ];

        await businesses.refresh();

        final row = await db.select(db.businesses).getSingle();
        expect(
          (row.name, row.amountMode, row.quantityMode),
          ('Pulpería Ana (nueva)', 'integer', 'fractional'),
        );
        expect((await db.select(db.memberships).getSingle()).role, 'employee');
      },
    );

    test('sin conexión falla y lo guardado sigue disponible', () async {
      api.businesses = [remoteBusiness('b-1')];
      await businesses.refresh();
      api.offline = true;

      await expectLater(businesses.refresh(), throwsA(isA<NetworkException>()));
      final local = await businesses.local();

      expect(local.map((b) => b.id), ['b-1']);
    });

    test('lo guardado solo incluye los negocios de este usuario', () async {
      api.businesses = [remoteBusiness('b-1')];
      await businesses.refresh();
      // Otro usuario del mismo teléfono con otro negocio.
      await insertBusiness(db, 'b-otro', name: 'Ajeno');
      await db
          .into(db.memberships)
          .insert(
            MembershipsCompanion.insert(
              userId: 'u-2',
              businessId: 'b-otro',
              role: 'owner',
            ),
          );

      final local = await businesses.local();

      expect(local.map((b) => b.id), ['b-1']);
    });

    test('sin sesión no hay nada que listar', () async {
      await sessions.logout();

      await expectLater(
        businesses.refresh(),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(await businesses.local(), isEmpty);
    });
  });

  group('crear un negocio adicional (RF-79)', () {
    test(
      'lo crea en el servidor y lo deja guardado, con el usuario como dueño',
      () async {
        final created = await businesses.create(
          name: 'Segunda sucursal',
          amountMode: AmountMode.integer,
          quantityMode: QuantityMode.integer,
        );

        expect(created.name, 'Segunda sucursal');
        expect(created.role, Role.owner);
        expect((await businesses.local()).map((b) => b.id), [created.id]);
      },
    );

    test('sin conexión no se crea nada', () async {
      api.offline = true;

      await expectLater(
        businesses.create(
          name: 'X',
          amountMode: AmountMode.integer,
          quantityMode: QuantityMode.integer,
        ),
        throwsA(isA<NetworkException>()),
      );
      expect(await businesses.local(), isEmpty);
    });
  });

  group('elegir el negocio activo (RF-6)', () {
    test('queda recordado en la sesión y en la base local', () async {
      await businesses.select(remoteBusiness('b-7', name: 'Elegida'));

      expect(store.session?.activeBusiness?.id, 'b-7');
      expect((await db.select(db.businesses).getSingle()).name, 'Elegida');
    });

    test('cambiar de negocio reemplaza al anterior', () async {
      await businesses.select(remoteBusiness('b-1'));
      await businesses.select(remoteBusiness('b-2', name: 'Otro'));

      expect(store.session?.activeBusiness?.id, 'b-2');
      expect(await db.select(db.businesses).get(), hasLength(2));
    });

    test('elegir no necesita red', () async {
      api.offline = true;

      await businesses.select(remoteBusiness('b-1'));

      expect(store.session?.activeBusiness?.id, 'b-1');
      expect(api.calls, isEmpty);
    });
  });
}
