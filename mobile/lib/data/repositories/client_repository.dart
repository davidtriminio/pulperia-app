import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/client/client_validation.dart';
import '../local/app_database.dart';

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
