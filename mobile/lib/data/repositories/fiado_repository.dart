import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../domain/ledger/fiado_validation.dart';
import '../local/app_database.dart';

sealed class FiadoSaveResult {
  const FiadoSaveResult();
}

/// El fiado y sus ítems se guardaron y su operación quedó en la cola.
final class FiadoSaved extends FiadoSaveResult {
  const FiadoSaved(this.fiado, this.items);

  final Fiado fiado;
  final List<FiadoItem> items;
}

/// El fiado no es válido; no se escribió nada.
final class FiadoRejected extends FiadoSaveResult {
  const FiadoRejected(this.issues);

  final List<FiadoIssue> issues;
}

/// El cliente no existe en ese negocio; no se escribió nada.
final class FiadoClientNotFound extends FiadoSaveResult {
  const FiadoClientNotFound();
}

/// El cliente está archivado: hay que restaurarlo antes de fiarle (RF-76); no
/// se escribió nada.
final class FiadoClientArchived extends FiadoSaveResult {
  const FiadoClientArchived();

  /// Código estable, el mismo de la API.
  String get code => 'client_archived';
}

/// El rol del usuario no permite la acción; no se escribió nada.
final class FiadoForbidden extends FiadoSaveResult {
  const FiadoForbidden();
}

/// Registra fiados en la base local. El fiado, sus ítems y su operación en la
/// cola se escriben en una sola transacción: si algo falla, no queda nada
/// (principio 2).
///
/// Un fiado no se edita ni se borra una vez registrado (RF-46): solo se anula.
class FiadoRepository {
  FiadoRepository(this._db, {required this._newId, required this._now});

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  /// Registra un fiado a un cliente, con detalle de ítems o solo con un monto
  /// total (RF-28, RF-29). Cada ítem guarda su descripción, cantidad y precio
  /// del momento, aunque el producto cambie después (principio 4); un ítem
  /// puede no ser del catálogo (RF-31). Queda anotado quién lo registró
  /// (RF-49).
  Future<FiadoSaveResult> create({
    required String businessId,
    required String userId,
    required Role role,
    required String clientId,
    required FiadoDraft draft,
  }) async {
    if (!can(role, Permission.registerFiado)) {
      return const FiadoForbidden();
    }

    final business = await (_db.select(
      _db.businesses,
    )..where((b) => b.id.equals(businessId))).getSingleOrNull();
    if (business == null) {
      throw ArgumentError.value(
        businessId,
        'businessId',
        'negocio desconocido',
      );
    }

    // Los ids se piden antes de abrir la transacción; un fiado sin ítems no
    // pide ninguno.
    final itemCount = switch (draft) {
      FiadoWithItems(:final items) => items.length,
      FiadoTotalOnly() => 0,
    };
    final fiadoId = _newId();
    final opId = _newId();
    final itemIds = [for (var i = 0; i < itemCount; i++) _newId()];
    final now = _now();

    return _db.transaction(() async {
      final client =
          await (_db.select(_db.clients)..where(
                (c) => c.id.equals(clientId) & c.businessId.equals(businessId),
              ))
              .getSingleOrNull();
      if (client == null) {
        return const FiadoClientNotFound();
      }
      // RF-76: a un cliente archivado no se le fía hasta restaurarlo. Se
      // comprueba antes que el contenido del fiado.
      if (client.archived) {
        return const FiadoClientArchived();
      }

      final validation = validateFiado(
        draft,
        amountMode: AmountMode.fromId(business.amountMode),
        quantityMode: QuantityMode.fromId(business.quantityMode),
      );
      if (validation is InvalidFiado) {
        return FiadoRejected(validation.issues);
      }
      final valid = validation as ValidFiado;

      await _db
          .into(_db.fiados)
          .insert(
            FiadosCompanion.insert(
              id: fiadoId,
              businessId: businessId,
              clientId: clientId,
              total: valid.total.minorUnits,
              occurredAt: now,
              createdBy: userId,
            ),
          );
      for (var i = 0; i < valid.items.length; i++) {
        final item = valid.items[i];
        await _db
            .into(_db.fiadoItems)
            .insert(
              FiadoItemsCompanion.insert(
                id: itemIds[i],
                businessId: businessId,
                fiadoId: fiadoId,
                productId: Value(item.productId),
                description: item.description,
                quantity: item.quantity.milli,
                unitPrice: item.unitPrice.minorUnits,
                subtotal: item.subtotal.minorUnits,
              ),
            );
      }
      await _db
          .into(_db.outboxOps)
          .insert(
            OutboxOpsCompanion.insert(
              opId: opId,
              businessId: businessId,
              type: 'fiado.create',
              entityId: fiadoId,
              payload: jsonEncode({
                'clientId': clientId,
                'total': valid.total.minorUnits,
                'occurredAt': now.toUtc().toIso8601String(),
                'items': [
                  for (var i = 0; i < valid.items.length; i++)
                    {
                      'id': itemIds[i],
                      'productId': valid.items[i].productId,
                      'description': valid.items[i].description,
                      'quantity': valid.items[i].quantity.milli,
                      'unitPrice': valid.items[i].unitPrice.minorUnits,
                      'subtotal': valid.items[i].subtotal.minorUnits,
                    },
                ],
              }),
              createdAt: now,
            ),
          );

      final fiado = await (_db.select(
        _db.fiados,
      )..where((f) => f.id.equals(fiadoId))).getSingle();
      final items =
          await (_db.select(_db.fiadoItems)
                ..where((i) => i.fiadoId.equals(fiadoId))
                ..orderBy([(i) => OrderingTerm.asc(i.rowId)]))
              .get();
      return FiadoSaved(fiado, items);
    });
  }
}
