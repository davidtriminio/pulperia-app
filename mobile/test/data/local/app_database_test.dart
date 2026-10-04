import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';

final created = DateTime.utc(2026, 10, 2, 15, 30, 45);

AppDatabase openDb() => AppDatabase(NativeDatabase.memory());

Future<void> insertBusiness(
  AppDatabase db,
  String id, {
  String name = 'Pulpería Don Chepe',
}) => db
    .into(db.businesses)
    .insert(
      BusinessesCompanion.insert(
        id: id,
        name: name,
        amountMode: 'two_decimals',
        quantityMode: 'fractional',
        createdAt: created,
      ),
    );

Future<void> insertClient(
  AppDatabase db,
  String id,
  String businessId, {
  String name = 'Ana',
}) => db
    .into(db.clients)
    .insert(
      ClientsCompanion.insert(
        id: id,
        businessId: businessId,
        name: name,
        characterId: 'char-01',
        skinId: 'skin-1',
        backgroundId: 'bg-01',
        createdBy: 'u-1',
        createdAt: created,
        updatedAt: created,
      ),
    );

Future<void> insertProduct(
  AppDatabase db,
  String id,
  String businessId, {
  int price = 2500,
}) => db
    .into(db.products)
    .insert(
      ProductsCompanion.insert(
        id: id,
        businessId: businessId,
        name: 'Arroz',
        price: price,
        createdBy: 'u-1',
        createdAt: created,
      ),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = openDb());
  tearDown(() => db.close());

  group('se guarda y se lee un registro de cada tabla (RF-51)', () {
    test('negocio', () async {
      await insertBusiness(db, 'b-1');

      final business = await db.select(db.businesses).getSingle();
      expect(business.id, 'b-1');
      expect(business.name, 'Pulpería Don Chepe');
      expect(business.amountMode, 'two_decimals');
      expect(business.quantityMode, 'fractional');
      expect(business.createdAt.isAtSameMomentAs(created), isTrue);
    });

    test('pertenencia del usuario a un negocio', () async {
      await insertBusiness(db, 'b-1');
      await db
          .into(db.memberships)
          .insert(
            MembershipsCompanion.insert(
              userId: 'u-1',
              businessId: 'b-1',
              role: 'owner',
            ),
          );

      final membership = await db.select(db.memberships).getSingle();
      expect(membership.userId, 'u-1');
      expect(membership.businessId, 'b-1');
      expect(membership.role, 'owner');
    });

    test('cliente, con sus valores por defecto', () async {
      await insertBusiness(db, 'b-1');
      await insertClient(db, 'c-1', 'b-1', name: 'Ana López');

      final client = await db.select(db.clients).getSingle();
      expect(client.id, 'c-1');
      expect(client.businessId, 'b-1');
      expect(client.name, 'Ana López');
      expect(client.characterId, 'char-01');
      expect(client.skinId, 'skin-1');
      expect(client.backgroundId, 'bg-01');
      expect(client.phone, isNull);
      expect(client.address, isNull);
      expect(client.note, isNull);
      expect(client.archived, isFalse);
      expect(client.version, 1);
      expect(client.createdBy, 'u-1');
      expect(client.createdAt.isAtSameMomentAs(created), isTrue);
      expect(client.updatedAt.isAtSameMomentAs(created), isTrue);
    });

    test('cliente con teléfono, dirección y nota', () async {
      await insertBusiness(db, 'b-1');
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'c-1',
              businessId: 'b-1',
              name: 'Ana',
              characterId: 'char-24',
              skinId: 'skin-6',
              backgroundId: 'bg-12',
              phone: const Value('90000000'),
              address: const Value('Frente a la iglesia'),
              note: const Value('Paga los viernes'),
              createdBy: 'u-1',
              createdAt: created,
              updatedAt: created,
            ),
          );

      final client = await db.select(db.clients).getSingle();
      expect(client.phone, '90000000');
      expect(client.address, 'Frente a la iglesia');
      expect(client.note, 'Paga los viernes');
    });

    test('producto, con el precio en la unidad menor', () async {
      await insertBusiness(db, 'b-1');
      await insertProduct(db, 'p-1', 'b-1', price: 1250);

      final product = await db.select(db.products).getSingle();
      expect(product.id, 'p-1');
      expect(product.businessId, 'b-1');
      expect(product.name, 'Arroz');
      expect(product.price, 1250);
      expect(product.archived, isFalse);
      expect(product.version, 1);
      expect(product.createdBy, 'u-1');
      expect(product.createdAt.isAtSameMomentAs(created), isTrue);
    });
  });

  group('todo dato pertenece a un negocio (principio 6)', () {
    test('clientes, productos y pertenencias tienen business_id', () {
      final tables = {
        'clients': db.clients.$columns,
        'products': db.products.$columns,
        'memberships': db.memberships.$columns,
      };

      tables.forEach((name, columns) {
        expect(
          [for (final c in columns) c.name],
          contains('business_id'),
          reason: name,
        );
      });
    });

    test('un cliente de un negocio que no existe se rechaza', () async {
      expect(insertClient(db, 'c-1', 'no-existe'), throwsA(isA<Exception>()));
    });

    test('un producto de un negocio que no existe se rechaza', () async {
      expect(insertProduct(db, 'p-1', 'no-existe'), throwsA(isA<Exception>()));
    });

    test('una pertenencia a un negocio que no existe se rechaza', () async {
      expect(
        db
            .into(db.memberships)
            .insert(
              MembershipsCompanion.insert(
                userId: 'u-1',
                businessId: 'no-existe',
                role: 'owner',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('filtrar por negocio no mezcla los datos de dos negocios', () async {
      await insertBusiness(db, 'b-1', name: 'Uno');
      await insertBusiness(db, 'b-2', name: 'Dos');
      await insertClient(db, 'c-1', 'b-1', name: 'Ana');
      await insertClient(db, 'c-2', 'b-2', name: 'Beto');
      await insertProduct(db, 'p-1', 'b-1');
      await insertProduct(db, 'p-2', 'b-2');

      final clients = await (db.select(
        db.clients,
      )..where((c) => c.businessId.equals('b-1'))).get();
      final products = await (db.select(
        db.products,
      )..where((p) => p.businessId.equals('b-2'))).get();

      expect([for (final c in clients) c.id], ['c-1']);
      expect([for (final p in products) p.id], ['p-2']);
    });
  });

  group('restricciones', () {
    test(
      'no se repite el id de un negocio, de un cliente ni de un producto',
      () async {
        await insertBusiness(db, 'b-1');
        await insertClient(db, 'c-1', 'b-1');
        await insertProduct(db, 'p-1', 'b-1');

        expect(insertBusiness(db, 'b-1'), throwsA(isA<Exception>()));
        expect(insertClient(db, 'c-1', 'b-1'), throwsA(isA<Exception>()));
        expect(insertProduct(db, 'p-1', 'b-1'), throwsA(isA<Exception>()));
      },
    );

    test('un usuario no pertenece dos veces al mismo negocio', () async {
      await insertBusiness(db, 'b-1');
      final insert = MembershipsCompanion.insert(
        userId: 'u-1',
        businessId: 'b-1',
        role: 'owner',
      );
      await db.into(db.memberships).insert(insert);

      expect(db.into(db.memberships).insert(insert), throwsA(isA<Exception>()));
    });

    test('un usuario puede pertenecer a varios negocios con roles distintos (RF-5)', () async {
      await insertBusiness(db, 'b-1');
      await insertBusiness(db, 'b-2');
      await db
          .into(db.memberships)
          .insert(
            MembershipsCompanion.insert(
              userId: 'u-1',
              businessId: 'b-1',
              role: 'owner',
            ),
          );
      await db
          .into(db.memberships)
          .insert(
            MembershipsCompanion.insert(
              userId: 'u-1',
              businessId: 'b-2',
              role: 'employee',
            ),
          );

      final roles = await db.select(db.memberships).get();
      expect(
        {for (final m in roles) m.businessId: m.role},
        {'b-1': 'owner', 'b-2': 'employee'},
      );
    });

    test('el rol solo puede ser owner o employee', () async {
      await insertBusiness(db, 'b-1');

      expect(
        db
            .into(db.memberships)
            .insert(
              MembershipsCompanion.insert(
                userId: 'u-1',
                businessId: 'b-1',
                role: 'admin',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('los modos del negocio solo admiten los valores definidos', () async {
      Future<void> insertWith(String amountMode, String quantityMode) => db
          .into(db.businesses)
          .insert(
            BusinessesCompanion.insert(
              id: 'b-x',
              name: 'X',
              amountMode: amountMode,
              quantityMode: quantityMode,
              createdAt: created,
            ),
          );

      expect(insertWith('decimals', 'fractional'), throwsA(isA<Exception>()));
      expect(insertWith('integer', 'decimals'), throwsA(isA<Exception>()));
      await insertWith('integer', 'integer');
      expect((await db.select(db.businesses).get()).length, 1);
    });

    test('el precio de un producto debe ser positivo', () async {
      await insertBusiness(db, 'b-1');

      expect(
        insertProduct(db, 'p-0', 'b-1', price: 0),
        throwsA(isA<Exception>()),
      );
      expect(
        insertProduct(db, 'p-n', 'b-1', price: -100),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('fechas', () {
    test(
      'se guardan como texto en UTC y se leen como el mismo instante',
      () async {
        final local = DateTime.utc(2026, 1, 15, 3, 4, 5).toLocal();
        await insertBusiness(db, 'b-1');
        await db
            .into(db.clients)
            .insert(
              ClientsCompanion.insert(
                id: 'c-1',
                businessId: 'b-1',
                name: 'Ana',
                characterId: 'char-01',
                skinId: 'skin-1',
                backgroundId: 'bg-01',
                createdBy: 'u-1',
                createdAt: local,
                updatedAt: local,
              ),
            );

        final client = await db.select(db.clients).getSingle();

        expect(
          client.createdAt.isAtSameMomentAs(DateTime.utc(2026, 1, 15, 3, 4, 5)),
          isTrue,
        );

        final raw = await db
            .customSelect('SELECT created_at FROM clients')
            .getSingle();
        expect(raw.read<String>('created_at'), '2026-01-15T03:04:05.000Z');
      },
    );
  });
}
