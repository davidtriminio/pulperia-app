import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/data/repositories/fiado_repository.dart';
import 'package:pulperia_mobile/data/repositories/payment_repository.dart';
import 'package:pulperia_mobile/data/repositories/summary_queries.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/client/client_validation.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';
import '../../support/shared_vectors.dart';

void main() {
  late AppDatabase db;
  late SummaryQueries queries;

  setUp(() async {
    db = openDb();
    queries = SummaryQueries(db);
    await insertBusiness(db, 'b-1');
    await insertBusiness(db, 'b-2');
  });
  tearDown(() => db.close());

  group(
    'resumen con los vectores compartidos (RF-63, RF-64, RF-65, RF-66)',
    () {
      final cases = loadVectorCases('summary.json');

      test('hay al menos 15 casos', () {
        expect(cases.length, greaterThanOrEqualTo(15));
      });

      for (final c in cases) {
        test(c.name, () async {
          var n = 0;
          for (final raw in c.input['clients'] as List<dynamic>) {
            final client = raw as Map<String, dynamic>;
            final id = client['id'] as String;
            final balance = client['balance'] as int;
            n++;
            await db
                .into(db.clients)
                .insert(
                  ClientsCompanion.insert(
                    id: id,
                    businessId: 'b-1',
                    name: client['name'] as String,
                    characterId: 'char-01',
                    skinId: 'skin-1',
                    backgroundId: 'bg-01',
                    archived: Value(client['archived'] as bool),
                    createdBy: 'u-1',
                    createdAt: created,
                    updatedAt: created,
                  ),
                );
            // El saldo del vector se obtiene con un movimiento: un fiado si es
            // deuda, un abono si es saldo a favor.
            if (balance > 0) {
              await insertFiado(db, 'f-$n', 'b-1', id, total: balance);
            } else if (balance < 0) {
              await insertPayment(db, 'a-$n', 'b-1', id, amount: -balance);
            }
          }

          final summary = await queries.summaryOf('b-1');

          expect(summary.debtTotal.minorUnits, c.expected['debtTotal']);
          expect(summary.creditTotal.minorUnits, c.expected['creditTotal']);
          expect([
            for (final d in summary.debtors) d.clientId,
          ], c.expected['topDebtorIds']);
        });
      }
    },
  );

  group('incluye los cambios aún sin sincronizar (RF-66)', () {
    late DateTime clock;
    late int idCounter;
    late ClientRepository clients;
    late FiadoRepository fiados;
    late PaymentRepository payments;

    ClientDraft draft(String name) => ClientDraft(
      name: name,
      characterId: 'char-01',
      skinId: 'skin-1',
      backgroundId: 'bg-01',
    );

    Future<String> createClient(String name) async => ((await clients.create(
      businessId: 'b-1',
      userId: 'u-1',
      draft: draft(name),
    )) as ClientSaved).client.id;

    Future<void> fiar(String clientId, int amount) => fiados.create(
      businessId: 'b-1',
      userId: 'u-1',
      role: Role.owner,
      clientId: clientId,
      draft: FiadoTotalOnly(Money(amount)),
    );

    Future<void> abonar(String clientId, int amount) => payments.create(
      businessId: 'b-1',
      userId: 'u-1',
      role: Role.owner,
      clientId: clientId,
      amount: Money(amount),
    );

    setUp(() {
      clock = DateTime.utc(2026, 10, 3, 10);
      idCounter = 0;
      String newId() => 'n-${++idCounter}';
      clients = ClientRepository(db, newId: newId, now: () => clock);
      fiados = FiadoRepository(db, newId: newId, now: () => clock);
      payments = PaymentRepository(db, newId: newId, now: () => clock);
    });

    test('un fiado recién registrado, sin sincronizar, ya cuenta en la deuda total', () async {
      final ana = await createClient('Ana');
      await fiar(ana, 8000);

      final summary = await queries.summaryOf('b-1');

      expect(summary.debtTotal, const Money(8000));
      expect([for (final d in summary.debtors) d.clientId], [ana]);
      final pending = await (db.select(
        db.outboxOps,
      )..where((o) => o.status.equals('pending'))).get();
      expect(
        pending,
        isNotEmpty,
        reason: 'sigue habiendo cambios por sincronizar',
      );
    });

    test('un abono sin sincronizar reduce la deuda y un abono mayor deja saldo a favor', () async {
      final ana = await createClient('Ana');
      final beto = await createClient('Beto');
      await fiar(ana, 8000);
      await abonar(ana, 3000);
      await abonar(beto, 2500);

      final summary = await queries.summaryOf('b-1');

      expect(summary.debtTotal, const Money(5000));
      expect(summary.creditTotal, const Money(2500));
      expect([for (final d in summary.debtors) d.clientId], [ana]);
    });

    test('lo sincronizado y lo pendiente cuentan igual', () async {
      final ana = await createClient('Ana');
      await fiar(ana, 4000);
      await (db.update(db.fiados)..where((f) => f.clientId.equals(ana))).write(
        const FiadosCompanion(serverSeq: Value(5)),
      );
      await fiar(ana, 1000);

      final summary = await queries.summaryOf('b-1');

      expect(summary.debtTotal, const Money(5000));
    });

    test(
      'una anulación sin sincronizar ya quita el movimiento del resumen',
      () async {
        final ana = await createClient('Ana');
        await fiar(ana, 8000);
        final fiadoId = (await db.select(db.fiados).getSingle()).id;
        await fiados.annul(
          businessId: 'b-1',
          userId: 'u-1',
          role: Role.owner,
          fiadoId: fiadoId,
        );

        final summary = await queries.summaryOf('b-1');

        expect(summary.debtTotal, Money.zero);
        expect(summary.debtors, isEmpty);
      },
    );

    test('archivar un cliente sin sincronizar lo saca del resumen', () async {
      final ana = await createClient('Ana');
      await fiar(ana, 8000);
      await clients.archive(
        businessId: 'b-1',
        userId: 'u-1',
        role: Role.owner,
        clientId: ana,
      );

      final summary = await queries.summaryOf('b-1');

      expect(summary.debtTotal, Money.zero);
      expect(summary.debtors, isEmpty);
    });

    test('el resumen cambia en cuanto se registra algo nuevo', () async {
      final ana = await createClient('Ana');

      expect((await queries.summaryOf('b-1')).debtTotal, Money.zero);
      await fiar(ana, 1000);
      expect((await queries.summaryOf('b-1')).debtTotal, const Money(1000));
      await fiar(ana, 2000);
      expect((await queries.summaryOf('b-1')).debtTotal, const Money(3000));
    });
  });

  group('solo datos locales y solo del negocio pedido', () {
    test('un negocio sin clientes tiene un resumen vacío', () async {
      final summary = await queries.summaryOf('b-1');

      expect(summary.debtTotal, Money.zero);
      expect(summary.creditTotal, Money.zero);
      expect(summary.debtors, isEmpty);
    });

    test('no mezcla los clientes de otro negocio (principio 6)', () async {
      await insertClient(db, 'c-1', 'b-1', name: 'Ana');
      await insertClient(db, 'c-2', 'b-2', name: 'Beto');
      await insertFiado(db, 'f-1', 'b-1', 'c-1', total: 3000);
      await insertFiado(db, 'f-2', 'b-2', 'c-2', total: 99999);

      final first = await queries.summaryOf('b-1');
      final second = await queries.summaryOf('b-2');

      expect(first.debtTotal, const Money(3000));
      expect([for (final d in first.debtors) d.clientId], ['c-1']);
      expect(second.debtTotal, const Money(99999));
    });

    test('un negocio que no existe da un resumen vacío', () async {
      expect((await queries.summaryOf('no-existe')).debtors, isEmpty);
    });
  });
}
