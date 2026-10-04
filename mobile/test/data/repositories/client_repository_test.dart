import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/domain/client/client_validation.dart';

import '../../support/db_fixtures.dart';

ClientDraft draft({
  String name = 'Ana López',
  String? note,
  String? phone,
  String? address,
  String? characterId = 'char-01',
  String? skinId = 'skin-1',
  String? backgroundId = 'bg-01',
}) => ClientDraft(
  name: name,
  note: note,
  phone: phone,
  address: address,
  characterId: characterId,
  skinId: skinId,
  backgroundId: backgroundId,
);

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late ClientRepository repo;

  ClientRepository newRepo() =>
      ClientRepository(db, newId: () => 'id-${++idCounter}', now: () => clock);

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 3, 10, 0, 0);
    idCounter = 0;
    repo = newRepo();
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
  });
  tearDown(() => db.close());

  Future<List<OutboxOp>> outbox() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  group('crear un cliente (RF-14, RF-51)', () {
    test('guarda el cliente con sus datos, versión 1 y autoría', () async {
      final result = await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(
          note: 'Paga los viernes',
          phone: '90000000',
          address: 'Frente a la iglesia',
          characterId: 'char-07',
          skinId: 'skin-3',
          backgroundId: 'bg-12',
        ),
      );

      final saved = (result as ClientSaved).client;
      final stored = await db.select(db.clients).getSingle();
      expect(stored.id, saved.id);
      expect(stored.businessId, 'b-1');
      expect(stored.name, 'Ana López');
      expect(stored.characterId, 'char-07');
      expect(stored.skinId, 'skin-3');
      expect(stored.backgroundId, 'bg-12');
      expect(stored.phone, '90000000');
      expect(stored.address, 'Frente a la iglesia');
      expect(stored.note, 'Paga los viernes');
      expect(stored.archived, isFalse);
      expect(stored.version, 1);
      expect(stored.createdBy, 'u-1');
      expect(stored.createdAt.isAtSameMomentAs(clock), isTrue);
      expect(stored.updatedAt.isAtSameMomentAs(clock), isTrue);
    });

    test('encola en la misma operación un client.create pendiente', () async {
      final result = await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(phone: '90000000'),
      );

      final client = (result as ClientSaved).client;
      final ops = await outbox();
      expect(ops.length, 1);
      expect(ops.single.type, 'client.create');
      expect(ops.single.entityId, client.id);
      expect(ops.single.businessId, 'b-1');
      expect(ops.single.status, 'pending');
      expect(ops.single.baseVersion, isNull);
      expect(ops.single.errorCode, isNull);
      expect(ops.single.createdAt.isAtSameMomentAs(clock), isTrue);
      expect(
        ops.single.opId,
        isNot(client.id),
        reason: 'la operación tiene su propio id',
      );
      expect(jsonDecode(ops.single.payload), {
        'name': 'Ana López',
        'characterId': 'char-01',
        'skinId': 'skin-1',
        'backgroundId': 'bg-01',
        'phone': '90000000',
        'address': null,
        'note': null,
      });
    });

    test('si falla el encolado, no queda el cliente guardado', () async {
      // El id de la operación será 'id-2'; ya existe, así que el encolado falla.
      await insertOutboxOp(db, 'id-2', 'b-1');

      await expectLater(
        repo.create(businessId: 'b-1', userId: 'u-1', draft: draft()),
        throwsA(isA<Exception>()),
      );

      expect(await db.select(db.clients).get(), isEmpty);
      expect(
        (await outbox()).length,
        1,
        reason: 'solo la operación preexistente',
      );
    });

    test('un borrador inválido no escribe nada y dice qué falla', () async {
      final result = await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: '  ', phone: '12345', characterId: null),
      );

      final issues = (result as ClientRejected).issues;
      expect(
        [for (final i in issues) i.code],
        ['name_required', 'phone_invalid_format', 'avatar_character_required'],
      );
      expect(await db.select(db.clients).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });

    test('dos clientes con el mismo nombre se pueden guardar (RF-17 es solo un aviso)', () async {
      await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: 'Juan Pérez'),
      );
      await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: 'Juan Pérez'),
      );

      expect((await db.select(db.clients).get()).length, 2);
    });

    test('varias creaciones se encolan en orden', () async {
      await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: 'Ana'),
      );
      await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: 'Beto'),
      );
      await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: 'Carla'),
      );

      final names = [
        for (final o in await outbox()) (jsonDecode(o.payload) as Map)['name'],
      ];
      expect(names, ['Ana', 'Beto', 'Carla']);
    });

    test(
      'un teléfono, dirección o nota vacíos se guardan como ausentes',
      () async {
        await repo.create(
          businessId: 'b-1',
          userId: 'u-1',
          draft: draft(phone: '', address: '', note: ''),
        );

        final stored = await db.select(db.clients).getSingle();
        expect(stored.phone, isNull);
        expect(stored.address, isNull);
        expect(stored.note, isNull);
      },
    );

    test('el nombre se guarda sin espacios exteriores', () async {
      await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: '  Ana López \t'),
      );

      expect((await db.select(db.clients).getSingle()).name, 'Ana López');
    });

    test('un negocio que no existe lanza error y no deja nada', () async {
      await expectLater(
        repo.create(businessId: 'no-existe', userId: 'u-1', draft: draft()),
        throwsA(isA<Exception>()),
      );

      expect(await db.select(db.clients).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });
  });

  group('editar un cliente (RF-19, RF-51)', () {
    late String clientId;

    setUp(() async {
      final created = await repo.create(
        businessId: 'b-1',
        userId: 'u-1',
        draft: draft(name: 'Ana', phone: '90000000', note: 'Nota inicial'),
      );
      clientId = (created as ClientSaved).client.id;
      clock = DateTime.utc(2026, 10, 4, 12, 30, 0);
    });

    test(
      'cambia los datos, sube la versión y marca la fecha de edición',
      () async {
        final result = await repo.update(
          businessId: 'b-1',
          userId: 'u-2',
          clientId: clientId,
          draft: draft(
            name: 'Ana María López',
            phone: '80000000',
            address: 'Barrio Abajo',
            note: null,
            characterId: 'char-20',
            skinId: 'skin-5',
            backgroundId: 'bg-03',
          ),
        );

        expect(result, isA<ClientSaved>());
        final stored = await db.select(db.clients).getSingle();
        expect(stored.name, 'Ana María López');
        expect(stored.phone, '80000000');
        expect(stored.address, 'Barrio Abajo');
        expect(stored.note, isNull);
        expect(stored.characterId, 'char-20');
        expect(stored.skinId, 'skin-5');
        expect(stored.backgroundId, 'bg-03');
        expect(stored.version, 2);
        expect(stored.updatedAt.isAtSameMomentAs(clock), isTrue);
      },
    );

    test('conserva quién y cuándo lo creó, y que no está archivado', () async {
      await repo.update(
        businessId: 'b-1',
        userId: 'u-2',
        clientId: clientId,
        draft: draft(name: 'Otro'),
      );

      final stored = await db.select(db.clients).getSingle();
      expect(stored.createdBy, 'u-1');
      expect(
        stored.createdAt.isAtSameMomentAs(DateTime.utc(2026, 10, 3, 10)),
        isTrue,
      );
      expect(stored.archived, isFalse);
    });

    test('encola un client.update pendiente con la versión base y el contenido nuevo', () async {
      await repo.update(
        businessId: 'b-1',
        userId: 'u-2',
        clientId: clientId,
        draft: draft(name: 'Ana María', phone: '80000000'),
      );

      final ops = await outbox();
      expect(ops.length, 2, reason: 'la creación y la edición');
      final op = ops.last;
      expect(op.type, 'client.update');
      expect(op.entityId, clientId);
      expect(op.status, 'pending');
      expect(op.baseVersion, 1);
      expect(op.createdAt.isAtSameMomentAs(clock), isTrue);
      expect(jsonDecode(op.payload), {
        'name': 'Ana María',
        'characterId': 'char-01',
        'skinId': 'skin-1',
        'backgroundId': 'bg-01',
        'phone': '80000000',
        'address': null,
        'note': null,
      });
    });

    test('ediciones seguidas encadenan las versiones base', () async {
      await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: clientId,
        draft: draft(name: 'Uno'),
      );
      await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: clientId,
        draft: draft(name: 'Dos'),
      );
      await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: clientId,
        draft: draft(name: 'Tres'),
      );

      final updates = (await outbox())
          .where((o) => o.type == 'client.update')
          .toList();
      expect([for (final o in updates) o.baseVersion], [1, 2, 3]);
      expect((await db.select(db.clients).getSingle()).version, 4);
    });

    test('editar no toca el historial de movimientos (RF-19)', () async {
      await insertFiado(db, 'f-1', 'b-1', clientId, total: 5000);
      await insertPayment(db, 'a-1', 'b-1', clientId, amount: 2000);

      await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: clientId,
        draft: draft(name: 'Nuevo nombre'),
      );

      final fiado = await db.select(db.fiados).getSingle();
      final payment = await db.select(db.payments).getSingle();
      expect([fiado.id, fiado.clientId, fiado.total], ['f-1', clientId, 5000]);
      expect(
        [payment.id, payment.clientId, payment.amount],
        ['a-1', clientId, 2000],
      );
    });

    test('un borrador inválido no cambia nada ni encola', () async {
      final result = await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: clientId,
        draft: draft(name: '', note: 'x' * 301),
      );

      expect(
        [for (final i in (result as ClientRejected).issues) i.code],
        ['name_required', 'note_too_long'],
      );
      final stored = await db.select(db.clients).getSingle();
      expect(stored.name, 'Ana');
      expect(stored.version, 1);
      expect((await outbox()).length, 1, reason: 'solo la creación');
    });

    test('un cliente que no existe', () async {
      final result = await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: 'no-existe',
        draft: draft(),
      );

      expect(result, isA<ClientNotFound>());
      expect((await outbox()).length, 1);
    });

    test(
      'un cliente de otro negocio se trata como inexistente (principio 6)',
      () async {
        final result = await repo.update(
          businessId: 'b-2',
          userId: 'u-1',
          clientId: clientId,
          draft: draft(name: 'Intruso'),
        );

        expect(result, isA<ClientNotFound>());
        final stored = await db.select(db.clients).getSingle();
        expect(stored.name, 'Ana');
        expect(stored.version, 1);
      },
    );

    test('si falla el encolado, el cliente queda como estaba', () async {
      // La próxima operación se llamará 'id-2' (la creación usó id-1 e id-2? ver abajo).
      final next = 'id-${idCounter + 1}';
      await insertOutboxOp(db, next, 'b-1');

      await expectLater(
        repo.update(
          businessId: 'b-1',
          userId: 'u-1',
          clientId: clientId,
          draft: draft(name: 'No debe guardarse'),
        ),
        throwsA(isA<Exception>()),
      );

      final stored = await db.select(db.clients).getSingle();
      expect(stored.name, 'Ana');
      expect(stored.version, 1);
      expect(
        stored.updatedAt.isAtSameMomentAs(DateTime.utc(2026, 10, 3, 10)),
        isTrue,
      );
    });

    test('se puede editar un cliente archivado y sigue archivado', () async {
      await (db.update(db.clients)..where((c) => c.id.equals(clientId))).write(
        const ClientsCompanion(archived: Value(true)),
      );

      final result = await repo.update(
        businessId: 'b-1',
        userId: 'u-1',
        clientId: clientId,
        draft: draft(name: 'Archivada'),
      );

      expect(result, isA<ClientSaved>());
      final stored = await db.select(db.clients).getSingle();
      expect(stored.name, 'Archivada');
      expect(stored.archived, isTrue);
    });
  });
}
