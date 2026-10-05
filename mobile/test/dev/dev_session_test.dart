import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/dev/dev_session.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import '../support/db_fixtures.dart';

void main() {
  group('devSessionFor', () {
    test('en depuración da el negocio y el usuario dueño de prueba', () {
      final session = devSessionFor(isRelease: false);

      expect(session, isNotNull);
      expect(session!.role, Role.owner);
      expect(session.businessName, isNotEmpty);
      expect(session.businessId, isNotEmpty);
      expect(session.userId, isNotEmpty);
      expect(session.amountMode, AmountMode.twoDecimals);
      expect(session.quantityMode, QuantityMode.fractional);
    });

    test('en modo release no está disponible', () {
      expect(devSessionFor(isRelease: true), isNull);
    });

    test('por omisión usa el modo real de compilación', () {
      // Los tests corren en depuración: la sesión simulada existe.
      expect(devSessionFor(), isNotNull);
    });
  });

  group('seedDevSession', () {
    test('crea el negocio y la pertenencia del dueño', () async {
      final db = openDb();
      addTearDown(db.close);
      final session = devSessionFor(isRelease: false)!;

      await seedDevSession(db, session);

      final business = await db.select(db.businesses).getSingle();
      expect(business.id, session.businessId);
      expect(business.name, session.businessName);
      expect(business.amountMode, 'two_decimals');
      expect(business.quantityMode, 'fractional');
      final membership = await db.select(db.memberships).getSingle();
      expect(membership.userId, session.userId);
      expect(membership.businessId, session.businessId);
      expect(membership.role, 'owner');
    });

    test('es idempotente: sembrar dos veces no duplica ni falla', () async {
      final db = openDb();
      addTearDown(db.close);
      final session = devSessionFor(isRelease: false)!;

      await seedDevSession(db, session);
      await seedDevSession(db, session);

      expect(await db.select(db.businesses).get(), hasLength(1));
      expect(await db.select(db.memberships).get(), hasLength(1));
    });

    test('no sobrescribe cambios hechos al negocio', () async {
      final db = openDb();
      addTearDown(db.close);
      final session = devSessionFor(isRelease: false)!;
      await seedDevSession(db, session);
      await (db.update(db.businesses))
          .write(const BusinessesCompanion(name: Value('Renombrado')));

      await seedDevSession(db, session);

      expect((await db.select(db.businesses).getSingle()).name, 'Renombrado');
    });

    test('en modo release no escribe nada', () async {
      final db = openDb();
      addTearDown(db.close);

      await seedDevSession(db, devSessionFor(isRelease: true));

      expect(await db.select(db.businesses).get(), isEmpty);
      expect(await db.select(db.memberships).get(), isEmpty);
    });
  });
}
