import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/ids.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/repositories/client_repository.dart';
import 'package:pulperia_mobile/data/repositories/fiado_repository.dart';
import 'package:pulperia_mobile/data/repositories/ledger_queries.dart';
import 'package:pulperia_mobile/data/remote/models.dart';
import 'package:pulperia_mobile/data/repositories/payment_repository.dart';
import 'package:pulperia_mobile/data/session/session_service.dart';
import 'package:pulperia_mobile/data/sync/sync_service.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/client/client_validation.dart';
import 'package:pulperia_mobile/domain/ledger/fiado_validation.dart';
import 'package:pulperia_mobile/domain/money/money.dart';

import '../../support/db_fixtures.dart';
import '../../support/fake_api.dart';
import '../../support/fake_server.dart';

/// Un teléfono simulado: su propia base local, su propia cola y su propia
/// sesión, hablando con el mismo servidor.
class Device {
  Device(this.server, this.userId) {
    db = openDb();
    final sessions = SessionService(
      api: server,
      store: MemorySessionStore(),
      now: () => server.now,
    );
    sync = SyncService(
      sessions: sessions,
      api: server,
      db: db,
      wait: (_) async {},
    );
    clients = ClientRepository(db, newId: newId, now: () => server.now);
    fiados = FiadoRepository(db, newId: newId, now: () => server.now);
    payments = PaymentRepository(db, newId: newId, now: () => server.now);
    ready = Future(() async {
      await sessions.login('$userId@correo.com', 'contrasena1');
      await insertBusiness(db, 'b-1');
    });
  }

  final FakeServer server;
  final String userId;
  late final AppDatabase db;
  late final SyncService sync;
  late final ClientRepository clients;
  late final FiadoRepository fiados;
  late final PaymentRepository payments;
  late final Future<void> ready;

  Future<void> sincronizar() async {
    await ready;
    final outcome = await sync.attempt('b-1');
    expect(outcome, isA<SyncSucceeded>(), reason: '$userId: $outcome');
  }

  Future<String> crearCliente(String name) async {
    await ready;
    final saved = await clients.create(
      businessId: 'b-1',
      userId: userId,
      draft: ClientDraft(
        name: name,
        characterId: 'char-01',
        skinId: 'skin-1',
        backgroundId: 'bg-01',
      ),
    ) as ClientSaved;
    return saved.client.id;
  }

  Future<String> fiar(String clientId, int centavos) async {
    final saved = await fiados.create(
      businessId: 'b-1',
      userId: userId,
      role: Role.owner,
      clientId: clientId,
      draft: FiadoTotalOnly(Money(centavos)),
    ) as FiadoSaved;
    return saved.fiado.id;
  }

  Future<String> abonar(String clientId, int centavos) async {
    final saved = await payments.create(
      businessId: 'b-1',
      userId: userId,
      role: Role.owner,
      clientId: clientId,
      amount: Money(centavos),
    ) as PaymentSaved;
    return saved.payment.id;
  }

  Future<int> saldo(String clientId) async {
    final balances = await LedgerQueries(db).balancesByClient('b-1');
    return balances[clientId]?.amount.minorUnits ?? 0;
  }

  Future<Client> cliente(String clientId) =>
      (db.select(db.clients)..where((c) => c.id.equals(clientId))).getSingle();

  Future<void> cerrar() => db.close();
}

void main() {
  // Cada teléfono simulado tiene su propia base en memoria.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeServer server;
  late Device ana;
  late Device beto;

  setUp(() {
    server = FakeServer();
    ana = Device(server, 'ana');
    beto = Device(server, 'beto');
  });

  tearDown(() async {
    await ana.cerrar();
    await beto.cerrar();
  });

  /// Los dos teléfonos conocen al mismo cliente, sincronizado.
  Future<String> clienteCompartido() async {
    final id = await ana.crearCliente('Doña Marta');
    await ana.sincronizar();
    await beto.sincronizar();
    return id;
  }

  /// Dos vueltas cada uno, en orden cruzado: lo que uno manda, el otro lo recibe.
  Future<void> sincronizarTodo() async {
    await ana.sincronizar();
    await beto.sincronizar();
    await ana.sincronizar();
    await beto.sincronizar();
  }

  group('dos dispositivos simulados (RF-47, RF-54, RF-85)', () {
    test(
      'un dispositivo nuevo ve lo que ya había (descarga inicial)',
      () async {
        final id = await clienteCompartido();

        expect((await beto.cliente(id)).name, 'Doña Marta');
      },
    );

    test('fiados concurrentes sin conexión: se conservan todos y el saldo es la suma (RF-54)', () async {
      final id = await clienteCompartido();

      await ana.fiar(id, 1000);
      await beto.fiar(id, 2500);
      await beto.abonar(id, 300);
      await sincronizarTodo();

      expect(await ana.saldo(id), 3200);
      expect(await beto.saldo(id), 3200);
      expect(await ana.db.select(ana.db.fiados).get(), hasLength(2));
      expect(await beto.db.select(beto.db.fiados).get(), hasLength(2));
    });

    test('anular un fiado en uno mientras el otro abona: el saldo queda a favor igual en ambos (RF-47)', () async {
      final id = await clienteCompartido();
      final fiado = await ana.fiar(id, 1400);
      await sincronizarTodo();

      await ana.fiados.annul(
        businessId: 'b-1',
        userId: 'ana',
        role: Role.owner,
        fiadoId: fiado,
      );
      await beto.abonar(id, 500);
      await sincronizarTodo();

      expect(await ana.saldo(id), -500);
      expect(await beto.saldo(id), -500);
    });

    test('fiado sin conexión a un cliente que otro archivó: se aplica y sigue archivado (RF-85)', () async {
      final id = await clienteCompartido();

      await ana.clients.archive(
        businessId: 'b-1',
        userId: 'ana',
        role: Role.owner,
        clientId: id,
      );
      await beto.fiar(id, 700);
      await sincronizarTodo();

      for (final device in [ana, beto]) {
        expect((await device.cliente(id)).archived, isTrue);
        expect(await device.saldo(id), 700);
      }
    });

    test('anular el mismo movimiento en los dos es idempotente', () async {
      final id = await clienteCompartido();
      final fiado = await ana.fiar(id, 900);
      await sincronizarTodo();

      for (final device in [ana, beto]) {
        await device.fiados.annul(
          businessId: 'b-1',
          userId: device.userId,
          role: Role.owner,
          fiadoId: fiado,
        );
      }
      await sincronizarTodo();

      expect(await ana.saldo(id), 0);
      expect(await beto.saldo(id), 0);
    });

    test('editar el mismo cliente en los dos: gana el servidor y el otro recibe el aviso (RF-55)', () async {
      final id = await clienteCompartido();
      ClientDraft draft(String name) => ClientDraft(
        name: name,
        characterId: 'char-01',
        skinId: 'skin-1',
        backgroundId: 'bg-01',
      );

      await ana.clients.update(
        businessId: 'b-1',
        userId: 'ana',
        clientId: id,
        draft: draft('Marta de Ana'),
      );
      await beto.clients.update(
        businessId: 'b-1',
        userId: 'beto',
        clientId: id,
        draft: draft('Marta de Beto'),
      );
      await ana.sincronizar();
      await beto.sincronizar();
      await ana.sincronizar();

      expect((await ana.cliente(id)).name, 'Marta de Ana');
      expect((await beto.cliente(id)).name, 'Marta de Ana');
      final avisos = await beto.sync.rejectedOperations('b-1');
      expect(avisos.map((o) => o.errorCode), ['version_conflict']);
    });

    test('reenviar un lote tras un corte no duplica nada (RF-53)', () async {
      final id = await clienteCompartido();
      await ana.fiar(id, 1000);
      // El servidor aplica el lote pero la respuesta se pierde.
      final lote = await (ana.db.select(ana.db.outboxOps)).get();
      await server.push('t', 'b-1', [
        for (final op in lote)
          PushOperation(
            opId: op.opId,
            type: op.type,
            entityId: op.entityId,
            payload: jsonDecode(op.payload) as Map<String, dynamic>,
            baseVersion: op.baseVersion,
            createdAt: op.createdAt,
          ),
      ]);

      await sincronizarTodo();

      expect(await ana.saldo(id), 1000);
      expect(await beto.saldo(id), 1000);
      expect(await ana.db.select(ana.db.fiados).get(), hasLength(1));
      expect(await ana.sync.pendingCount(), 0);
    });
  });
}
