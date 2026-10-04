import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/client/client_validation.dart';
import 'package:pulperia_mobile/domain/ledger/balance.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';

ClientDraft draft(String name) => ClientDraft(
  name: name,
  characterId: 'char-01',
  skinId: 'skin-1',
  backgroundId: 'bg-01',
);

void main() {
  late AppDatabase db;
  late DateTime clock;
  late int idCounter;
  late ClientRepository repo;

  setUp(() async {
    db = openDb();
    clock = DateTime.utc(2026, 10, 3, 10);
    idCounter = 0;
    repo = ClientRepository(
      db,
      newId: () => 'id-${++idCounter}',
      now: () => clock,
    );
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
  });
  tearDown(() => db.close());

  Future<String> createClient(String name, {String businessId = 'b-1'}) async {
    final result = await repo.create(
      businessId: businessId,
      userId: 'u-1',
      draft: draft(name),
    );
    return (result as ClientSaved).client.id;
  }

  Future<List<OutboxOp>> outbox() => (db.select(
    db.outboxOps,
  )..orderBy([(o) => OrderingTerm.asc(o.localSeq)])).get();

  Future<Client> clientRow(String id) =>
      (db.select(db.clients)..where((c) => c.id.equals(id))).getSingle();

  Future<void> advance() async => clock = clock.add(const Duration(hours: 1));

  group('archivar un cliente (RF-20)', () {
    test(
      'el dueño lo archiva: queda archivado, con versión y fecha nuevas',
      () async {
        final id = await createClient('Ana');
        await advance();

        final result = await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        );

        expect((result as ClientSaved).client.archived, isTrue);
        final row = await clientRow(id);
        expect(row.archived, isTrue);
        expect(row.version, 2);
        expect(row.updatedAt.isAtSameMomentAs(clock), isTrue);
      },
    );

    test('encola un client.archive pendiente con la versión base', () async {
      final id = await createClient('Ana');
      await advance();

      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );

      final op = (await outbox()).last;
      expect(op.type, 'client.archive');
      expect(op.entityId, id);
      expect(op.businessId, 'b-1');
      expect(op.status, 'pending');
      expect(op.baseVersion, 1);
      expect(op.payload, '{}');
      expect(op.createdAt.isAtSameMomentAs(clock), isTrue);
    });

    test(
      'se puede archivar aunque tenga saldo pendiente, y conserva su historial',
      () async {
        final id = await createClient('Ana');
        await insertFiado(db, 'f-1', 'b-1', id, total: 8000);
        await insertPayment(db, 'a-1', 'b-1', id, amount: 3000);

        await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        );

        expect((await db.select(db.fiados).getSingle()).total, 8000);
        expect((await db.select(db.payments).getSingle()).amount, 3000);
      },
    );

    test('RF-21: el empleado no puede archivar y no cambia nada', () async {
      final id = await createClient('Ana');
      final opsBefore = (await outbox()).length;

      final result = await repo.archive(
        businessId: 'b-1',
        userId: 'u-2',
        role: Role.employee,
        clientId: id,
      );

      expect(result, isA<ClientForbidden>());
      expect((await clientRow(id)).archived, isFalse);
      expect((await clientRow(id)).version, 1);
      expect((await outbox()).length, opsBefore);
    });

    test(
      'un cliente que no existe, o de otro negocio, no se encuentra',
      () async {
        final id = await createClient('Ana');

        expect(
          await repo.archive(
            businessId: 'b-1',
            userId: 'u-1',
            role: Role.owner,
            clientId: 'no-existe',
          ),
          isA<ClientNotFound>(),
        );
        expect(
          await repo.archive(
            businessId: 'b-2',
            userId: 'u-1',
            role: Role.owner,
            clientId: id,
          ),
          isA<ClientNotFound>(),
        );
        expect((await clientRow(id)).archived, isFalse);
      },
    );

    test('archivar uno ya archivado no cambia nada ni encola', () async {
      final id = await createClient('Ana');
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );
      final opsBefore = (await outbox()).length;
      await advance();

      final result = await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );

      expect((result as ClientSaved).client.archived, isTrue);
      expect((await clientRow(id)).version, 2);
      expect((await outbox()).length, opsBefore);
    });

    test('si falla el encolado, el cliente no queda archivado', () async {
      final id = await createClient('Ana');
      await insertOutboxOp(db, 'id-${idCounter + 1}', 'b-1');

      await expectLater(
        repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        ),
        throwsA(isA<Exception>()),
      );

      expect((await clientRow(id)).archived, isFalse);
      expect((await clientRow(id)).version, 1);
    });
  });

  group('restaurar un cliente (RF-23)', () {
    test(
      'el dueño lo restaura: deja de estar archivado, con versión nueva',
      () async {
        final id = await createClient('Ana');
        await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        );
        await advance();

        final result = await repo.restore(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        );

        expect((result as ClientSaved).client.archived, isFalse);
        final row = await clientRow(id);
        expect(row.archived, isFalse);
        expect(row.version, 3);
        expect(row.updatedAt.isAtSameMomentAs(clock), isTrue);
      },
    );

    test('encola un client.restore pendiente con la versión base', () async {
      final id = await createClient('Ana');
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );

      await repo.restore(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );

      final op = (await outbox()).last;
      expect(op.type, 'client.restore');
      expect(op.entityId, id);
      expect(op.status, 'pending');
      expect(op.baseVersion, 2);
      expect(op.payload, '{}');
    });

    test('el empleado no puede restaurar', () async {
      final id = await createClient('Ana');
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );
      final opsBefore = (await outbox()).length;

      final result = await repo.restore(
        businessId: 'b-1',
        userId: 'u-2',
        role: Role.employee,
        clientId: id,
      );

      expect(result, isA<ClientForbidden>());
      expect((await clientRow(id)).archived, isTrue);
      expect((await outbox()).length, opsBefore);
    });

    test(
      'restaurar uno que no está archivado no cambia nada ni encola',
      () async {
        final id = await createClient('Ana');
        final opsBefore = (await outbox()).length;

        final result = await repo.restore(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        );

        expect((result as ClientSaved).client.archived, isFalse);
        expect((await clientRow(id)).version, 1);
        expect((await outbox()).length, opsBefore);
      },
    );

    test('un cliente que no existe no se encuentra', () async {
      expect(
        await repo.restore(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: 'no-existe',
        ),
        isA<ClientNotFound>(),
      );
    });

    test('si falla el encolado, el cliente sigue archivado', () async {
      final id = await createClient('Ana');
      await repo.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: id,
      );
      await insertOutboxOp(db, 'id-${idCounter + 1}', 'b-1');

      await expectLater(
        repo.restore(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: id,
        ),
        throwsA(isA<Exception>()),
      );

      expect((await clientRow(id)).archived, isTrue);
    });
  });

  group('lista normal y lista de archivados (RF-22)', () {
    List<String> names(List<ClientWithBalance> list) => [
      for (final c in list) c.client.name,
    ];

    test(
      'un archivado sale de la lista normal y aparece en la de archivados',
      () async {
        final ana = await createClient('Ana');
        await createClient('Beto');
        await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: ana,
        );

        expect(names(await repo.activeClients('b-1')), ['Beto']);
        expect(names(await repo.archivedClients('b-1')), ['Ana']);
      },
    );

    test(
      'al restaurarlo vuelve a la lista normal con su historial y su saldo',
      () async {
        final ana = await createClient('Ana');
        await insertFiado(db, 'f-1', 'b-1', ana, total: 10000);
        await insertPayment(db, 'a-1', 'b-1', ana, amount: 4000);
        await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: ana,
        );
        await repo.restore(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: ana,
        );

        final active = await repo.activeClients('b-1');

        expect(names(active), ['Ana']);
        expect(active.single.balance.amount, const Money(6000));
        expect(await repo.archivedClients('b-1'), isEmpty);
      },
    );

    test(
      'cada cliente trae su saldo: deuda, saldo a favor o saldado',
      () async {
        final debtor = await createClient('Ana');
        final creditor = await createClient('Beto');
        await createClient('Carla');
        await insertFiado(db, 'f-1', 'b-1', debtor, total: 7000);
        await insertPayment(db, 'a-1', 'b-1', creditor, amount: 2500);

        final byName = {
          for (final c in await repo.activeClients('b-1'))
            c.client.name: c.balance,
        };

        expect(byName['Ana'], const Balance(Money(7000)));
        expect(byName['Ana']!.label, BalanceLabel.debt);
        expect(byName['Beto'], const Balance(Money(-2500)));
        expect(byName['Beto']!.label, BalanceLabel.credit);
        expect(byName['Carla'], const Balance(Money.zero));
        expect(byName['Carla']!.label, BalanceLabel.settled);
      },
    );

    test(
      'los archivados muestran su saldo, también el que tienen pendiente',
      () async {
        final ana = await createClient('Ana');
        await insertFiado(db, 'f-1', 'b-1', ana, total: 9000);
        await repo.archive(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          clientId: ana,
        );

        final archived = await repo.archivedClients('b-1');

        expect(archived.single.balance, const Balance(Money(9000)));
      },
    );

    test('los movimientos anulados no cuentan en el saldo', () async {
      final ana = await createClient('Ana');
      await insertFiado(db, 'f-1', 'b-1', ana, total: 5000);
      await insertFiado(
        db,
        'f-2',
        'b-1',
        ana,
        total: 3000,
        annulledAt: clock,
        annulledBy: 'u-1',
      );
      await insertPayment(
        db,
        'a-1',
        'b-1',
        ana,
        amount: 1000,
        annulledAt: clock,
        annulledBy: 'u-1',
      );

      expect(
        (await repo.activeClients('b-1')).single.balance.amount,
        const Money(5000),
      );
    });

    test('solo trae los clientes del negocio pedido (principio 6)', () async {
      await createClient('Ana');
      final intruder = await createClient('Beto', businessId: 'b-2');
      await insertFiado(db, 'f-9', 'b-2', intruder, total: 99999);

      expect(names(await repo.activeClients('b-1')), ['Ana']);
      expect(names(await repo.activeClients('b-2')), ['Beto']);
      expect(
        (await repo.activeClients('b-1')).single.balance.amount,
        Money.zero,
      );
    });

    test('van en orden alfabético sin distinguir mayúsculas, y con id para empates', () async {
      await createClient('beto');
      await createClient('Ana');
      await createClient('Carla');
      await createClient('ANA');

      final list = await repo.activeClients('b-1');

      expect(names(list), ['Ana', 'ANA', 'beto', 'Carla']);
    });

    test('un negocio sin clientes tiene listas vacías', () async {
      expect(await repo.activeClients('b-1'), isEmpty);
      expect(await repo.archivedClients('b-1'), isEmpty);
    });
  });
}
