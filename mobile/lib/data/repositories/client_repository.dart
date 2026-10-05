import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/access/access.dart';
import '../../domain/client/client_validation.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/money/money.dart';
import '../local/app_database.dart';
import 'ledger_queries.dart';

sealed class ClientSaveResult {
  const ClientSaveResult();
}

/// El cliente se guardó y su operación quedó en la cola.
final class ClientSaved extends ClientSaveResult {
  const ClientSaved(this.client);

  final Client client;
}

/// El borrador no es válido; no se escribió nada.
final class ClientRejected extends ClientSaveResult {
  const ClientRejected(this.issues);

  final List<ClientIssue> issues;
}

/// El cliente no existe en ese negocio; no se escribió nada.
final class ClientNotFound extends ClientSaveResult {
  const ClientNotFound();
}

/// El rol del usuario no permite la acción; no se escribió nada.
final class ClientForbidden extends ClientSaveResult {
  const ClientForbidden();
}

/// Un cliente con su saldo, para las listas.
final class ClientWithBalance {
  const ClientWithBalance(this.client, this.balance);

  final Client client;
  final Balance balance;
}

/// Crea y edita clientes en la base local. Cada cambio se escribe junto con su
/// operación en la cola, en una sola transacción: si falla el encolado, el
/// cambio no queda guardado (principio 2).
class ClientRepository {
  ClientRepository(this._db, {required this._newId, required this._now});

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  /// Crea un cliente (RF-14). El aviso de nombre repetido (RF-17) lo da la
  /// interfaz antes de llamar aquí: un homónimo no impide guardar.
  Future<ClientSaveResult> create({
    required String businessId,
    required String userId,
    required ClientDraft draft,
  }) async {
    final validation = validateClient(draft);
    if (validation is InvalidClient) {
      return ClientRejected(validation.issues);
    }

    final clientId = _newId();
    final opId = _newId();
    final now = _now();
    final values = _Values.of(draft);

    return _db.transaction(() async {
      await _db
          .into(_db.clients)
          .insert(
            ClientsCompanion.insert(
              id: clientId,
              businessId: businessId,
              name: values.name,
              characterId: values.characterId,
              skinId: values.skinId,
              backgroundId: values.backgroundId,
              phone: Value(values.phone),
              address: Value(values.address),
              note: Value(values.note),
              createdBy: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue(
        opId: opId,
        businessId: businessId,
        type: 'client.create',
        entityId: clientId,
        baseVersion: null,
        values: values,
        now: now,
      );
      return ClientSaved(await _find(businessId, clientId) as Client);
    });
  }

  /// Edita el nombre, el avatar, el teléfono, la dirección y la nota de un
  /// cliente (RF-19). No toca su historial ni si está archivado.
  ///
  /// La versión local sube con cada edición, de modo que ediciones seguidas
  /// sin sincronizar encadenan sus versiones base (D-8).
  Future<ClientSaveResult> update({
    required String businessId,
    required String userId,
    required String clientId,
    required ClientDraft draft,
  }) async {
    final validation = validateClient(draft);
    if (validation is InvalidClient) {
      return ClientRejected(validation.issues);
    }

    final opId = _newId();
    final now = _now();
    final values = _Values.of(draft);

    return _db.transaction(() async {
      final current = await _find(businessId, clientId);
      if (current == null) {
        return const ClientNotFound();
      }

      await (_db.update(_db.clients)..where(
            (c) => c.id.equals(clientId) & c.businessId.equals(businessId),
          ))
          .write(
            ClientsCompanion(
              name: Value(values.name),
              characterId: Value(values.characterId),
              skinId: Value(values.skinId),
              backgroundId: Value(values.backgroundId),
              phone: Value(values.phone),
              address: Value(values.address),
              note: Value(values.note),
              version: Value(current.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _enqueue(
        opId: opId,
        businessId: businessId,
        type: 'client.update',
        entityId: clientId,
        baseVersion: current.version,
        values: values,
        now: now,
      );
      return ClientSaved(await _find(businessId, clientId) as Client);
    });
  }

  /// Archiva un cliente (RF-20): sale de la lista normal pero conserva su
  /// historial y su saldo. Solo el dueño puede (RF-21). Archivar uno que ya
  /// está archivado no cambia nada.
  Future<ClientSaveResult> archive({
    required String businessId,
    required String userId,
    required Role role,
    required String clientId,
  }) => _setArchived(
    businessId: businessId,
    role: role,
    permission: Permission.archiveClient,
    clientId: clientId,
    archived: true,
    type: 'client.archive',
  );

  /// Restaura un cliente archivado (RF-23): vuelve a la lista normal con su
  /// historial y su saldo. Solo el dueño puede. Restaurar uno que no está
  /// archivado no cambia nada.
  Future<ClientSaveResult> restore({
    required String businessId,
    required String userId,
    required Role role,
    required String clientId,
  }) => _setArchived(
    businessId: businessId,
    role: role,
    permission: Permission.restoreClient,
    clientId: clientId,
    archived: false,
    type: 'client.restore',
  );

  Future<ClientSaveResult> _setArchived({
    required String businessId,
    required Role role,
    required Permission permission,
    required String clientId,
    required bool archived,
    required String type,
  }) async {
    if (!can(role, permission)) {
      return const ClientForbidden();
    }

    final opId = _newId();
    final now = _now();

    return _db.transaction(() async {
      final current = await _find(businessId, clientId);
      if (current == null) {
        return const ClientNotFound();
      }
      if (current.archived == archived) {
        return ClientSaved(current);
      }

      await (_db.update(_db.clients)..where(
            (c) => c.id.equals(clientId) & c.businessId.equals(businessId),
          ))
          .write(
            ClientsCompanion(
              archived: Value(archived),
              version: Value(current.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _db
          .into(_db.outboxOps)
          .insert(
            OutboxOpsCompanion.insert(
              opId: opId,
              businessId: businessId,
              type: type,
              entityId: clientId,
              payload: '{}',
              baseVersion: Value(current.version),
              createdAt: now,
            ),
          );
      return ClientSaved(await _find(businessId, clientId) as Client);
    });
  }

  /// Id y nombre de todos los clientes del negocio, archivados o no: sirve
  /// para avisar de un nombre repetido (RF-17).
  Future<List<({String id, String name})>> clientNames(
    String businessId,
  ) async {
    final clients = await (_db.select(
      _db.clients,
    )..where((c) => c.businessId.equals(businessId))).get();
    return [for (final c in clients) (id: c.id, name: c.name)];
  }

  /// Clientes no archivados del negocio, con su saldo (RF-42).
  Future<List<ClientWithBalance>> activeClients(String businessId) =>
      _list(businessId, archived: false);

  /// Clientes archivados del negocio, con su saldo (RF-22).
  Future<List<ClientWithBalance>> archivedClients(String businessId) =>
      _list(businessId, archived: true);

  /// En orden alfabético sin distinguir mayúsculas; los empates, por id.
  Future<List<ClientWithBalance>> _list(
    String businessId, {
    required bool archived,
  }) async {
    final clients =
        await (_db.select(_db.clients)..where(
              (c) =>
                  c.businessId.equals(businessId) & c.archived.equals(archived),
            ))
            .get();
    if (clients.isEmpty) {
      return const [];
    }

    final balances = await LedgerQueries(_db).balancesByClient(businessId);

    final result = [
      for (final c in clients)
        ClientWithBalance(c, balances[c.id] ?? const Balance(Money.zero)),
    ];
    result.sort((a, b) {
      final byName = a.client.name.toLowerCase().compareTo(
        b.client.name.toLowerCase(),
      );
      return byName != 0 ? byName : a.client.id.compareTo(b.client.id);
    });
    return result;
  }

  Future<Client?> _find(String businessId, String clientId) =>
      (_db.select(_db.clients)..where(
            (c) => c.id.equals(clientId) & c.businessId.equals(businessId),
          ))
          .getSingleOrNull();

  Future<void> _enqueue({
    required String opId,
    required String businessId,
    required String type,
    required String entityId,
    required int? baseVersion,
    required _Values values,
    required DateTime now,
  }) => _db
      .into(_db.outboxOps)
      .insert(
        OutboxOpsCompanion.insert(
          opId: opId,
          businessId: businessId,
          type: type,
          entityId: entityId,
          payload: jsonEncode(values.toJson()),
          baseVersion: Value(baseVersion),
          createdAt: now,
        ),
      );
}

/// Los datos de un cliente ya limpios para guardarse: sin espacios exteriores
/// en el nombre y con los textos vacíos como ausentes.
final class _Values {
  const _Values({
    required this.name,
    required this.characterId,
    required this.skinId,
    required this.backgroundId,
    required this.phone,
    required this.address,
    required this.note,
  });

  factory _Values.of(ClientDraft draft) => _Values(
    name: draft.name.trim(),
    characterId: draft.characterId!,
    skinId: draft.skinId!,
    backgroundId: draft.backgroundId!,
    phone: _blankToNull(draft.phone),
    address: _blankToNull(draft.address),
    note: _blankToNull(draft.note),
  );

  final String name;
  final String characterId;
  final String skinId;
  final String backgroundId;
  final String? phone;
  final String? address;
  final String? note;

  static String? _blankToNull(String? value) =>
      (value == null || value.isEmpty) ? null : value;

  Map<String, Object?> toJson() => {
    'name': name,
    'characterId': characterId,
    'skinId': skinId,
    'backgroundId': backgroundId,
    'phone': phone,
    'address': address,
    'note': note,
  };
}
