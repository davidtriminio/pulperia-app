import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/data/repositories/fiado_repository.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';

import '../../support/db_fixtures.dart';

FiadoDraft withItems() => FiadoWithItems([
  FiadoItemDraft(
    description: 'Arroz',
    quantity: const Quantity(1000),
    unitPrice: const Money(2500),
  ),
]);

void main() {
  late AppDatabase db;
  late int idCounter;
  late FiadoRepository fiados;
  late ClientRepository clients;
  final clock = DateTime.utc(2026, 10, 3, 10);

  setUp(() async {
    db = openDb();
    idCounter = 0;
    String newId() => 'x-${++idCounter}';
    fiados = FiadoRepository(db, newId: newId, now: () => clock);
    clients = ClientRepository(db, newId: newId, now: () => clock);
    await insertBusiness(db, 'b-1');
    await insertClient(db, 'c-1', 'b-1');
  });
  tearDown(() => db.close());

  Future<FiadoSaveResult> register(
    FiadoDraft draft, {
    String clientId = 'c-1',
  }) => fiados.create(
    businessId: 'b-1',
    userId: 'u-1',
    role: Role.owner,
    clientId: clientId,
    draft: draft,
  );

  Future<void> archiveClient(String id) => clients.archive(
    businessId: 'b-1',
    userId: 'u-1',
    role: Role.owner,
    clientId: id,
  );

  Future<int> opsCount() async => (await db.select(db.outboxOps).get()).length;

  group('fiar a un cliente archivado (RF-76)', () {
    test(
      'se rechaza e indica que el cliente debe restaurarse primero',
      () async {
        await archiveClient('c-1');

        final result = await register(withItems());

        expect(result, isA<FiadoClientArchived>());
        expect((result as FiadoClientArchived).code, 'client_archived');
      },
    );

    test('no deja nada: ni fiado, ni ítems, ni operación en la cola', () async {
      await archiveClient('c-1');
      final opsBefore = await opsCount();

      await register(withItems());
      await register(const FiadoTotalOnly(Money(5000)));

      expect(await db.select(db.fiados).get(), isEmpty);
      expect(await db.select(db.fiadoItems).get(), isEmpty);
      expect(await opsCount(), opsBefore);
    });

    test('también se rechaza un fiado solo con monto total', () async {
      await archiveClient('c-1');

      expect(
        await register(const FiadoTotalOnly(Money(5000))),
        isA<FiadoClientArchived>(),
      );
    });

    test('un cliente archivado pierde la restricción al restaurarlo', () async {
      await archiveClient('c-1');
      await clients.restore(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: 'c-1',
      );

      final result = await register(withItems());

      expect(result, isA<FiadoSaved>());
      expect((await db.select(db.fiados).getSingle()).clientId, 'c-1');
    });

    test('archivar a un cliente no afecta a otro del mismo negocio', () async {
      await insertClient(db, 'c-2', 'b-1', name: 'Beto');
      await archiveClient('c-1');

      expect(await register(withItems(), clientId: 'c-2'), isA<FiadoSaved>());
      expect(
        await register(withItems(), clientId: 'c-1'),
        isA<FiadoClientArchived>(),
      );
    });

    test('lo que ya estaba fiado antes de archivarlo se conserva', () async {
      await register(const FiadoTotalOnly(Money(7000)));
      await archiveClient('c-1');

      await register(const FiadoTotalOnly(Money(100)));

      final stored = await db.select(db.fiados).get();
      expect([for (final f in stored) f.total], [7000]);
    });

    test('un cliente archivado se avisa antes que un fiado inválido', () async {
      await archiveClient('c-1');

      final result = await register(const FiadoWithItems([]));

      expect(result, isA<FiadoClientArchived>());
    });

    test(
      'un cliente que no existe sigue siendo "no encontrado", no "archivado"',
      () async {
        expect(
          await register(withItems(), clientId: 'no-existe'),
          isA<FiadoClientNotFound>(),
        );
      },
    );
  });

  group(
    'un abono a un cliente archivado no tiene esta restricción (RF-75)',
    () {
      test(
        'la tabla de abonos admite movimientos de un cliente archivado',
        () async {
          await archiveClient('c-1');

          await insertPayment(db, 'a-1', 'b-1', 'c-1', amount: 2000);

          expect((await db.select(db.payments).getSingle()).clientId, 'c-1');
        },
      );
    },
  );
}
