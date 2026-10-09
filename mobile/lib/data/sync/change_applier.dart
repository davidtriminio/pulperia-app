import 'package:drift/drift.dart';

import '../local/app_database.dart';
import '../remote/models.dart';

/// Guarda en la base local los cambios que entrega el servidor. Aplicar la
/// misma página dos veces deja la base igual (RF-53), y lo que el usuario
/// cambió aquí y aún no se envió no se pisa mientras el servidor no tenga algo
/// más nuevo (D-8: ante un conflicto gana el servidor).
class ChangeApplier {
  ChangeApplier(this._db);

  final AppDatabase _db;

  /// Aplica [changes] al negocio. Debe llamarse dentro de una transacción: el
  /// orden (clientes y productos antes que lo que los referencia) asegura que
  /// las claves foráneas se cumplan sin importar en qué página llegó cada uno.
  Future<void> apply(String businessId, List<RemoteChange> changes) async {
    final entities = [for (final c in changes) c.entity];
    for (final e in entities.whereType<RemoteClient>()) {
      await _client(businessId, e);
    }
    for (final e in entities.whereType<RemoteProduct>()) {
      await _product(businessId, e);
    }
    for (final e in entities.whereType<RemoteFiado>()) {
      await _fiado(businessId, e);
    }
    for (final e in entities.whereType<RemotePayment>()) {
      await _payment(businessId, e);
    }
  }

  /// Las operaciones aún sin enviar sobre un registro.
  Future<List<OutboxOp>> _pending(String businessId, String entityId) =>
      (_db.select(_db.outboxOps)..where(
            (o) =>
                o.businessId.equals(businessId) &
                o.entityId.equals(entityId) &
                o.status.equals('pending'),
          ))
          .get();

  /// ¿Se debe aplicar la versión [remote] sobre un registro editable que tiene
  /// ediciones locales sin enviar? Solo si el servidor pasó de la versión que
  /// el usuario conocía al editar (la base de su primera edición pendiente);
  /// si no, es lo que ya sabíamos y la edición local sigue en pie.
  bool _remoteWins(List<OutboxOp> pending, int remoteVersion) {
    final bases = [
      for (final op in pending)
        if (op.baseVersion != null) op.baseVersion!,
    ];
    if (bases.isEmpty) {
      // Solo hay una creación pendiente: el registro es nuestro todavía.
      return pending.isEmpty;
    }
    return remoteVersion > bases.reduce((a, b) => a < b ? a : b);
  }

  Future<void> _client(String businessId, RemoteClient e) async {
    final pending = await _pending(businessId, e.id);
    if (pending.isNotEmpty && !_remoteWins(pending, e.version)) {
      return;
    }
    await _db
        .into(_db.clients)
        .insertOnConflictUpdate(
          ClientsCompanion.insert(
            id: e.id,
            businessId: businessId,
            name: e.name,
            characterId: e.characterId,
            skinId: e.skinId,
            backgroundId: e.backgroundId,
            phone: Value(e.phone),
            address: Value(e.address),
            note: Value(e.note),
            archived: Value(e.archived),
            version: Value(e.version),
            createdBy: e.createdBy,
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
          ),
        );
  }

  Future<void> _product(String businessId, RemoteProduct e) async {
    final pending = await _pending(businessId, e.id);
    if (pending.isNotEmpty && !_remoteWins(pending, e.version)) {
      return;
    }
    await _db
        .into(_db.products)
        .insertOnConflictUpdate(
          ProductsCompanion.insert(
            id: e.id,
            businessId: businessId,
            name: e.name,
            price: e.price,
            unit: Value(e.unit.id),
            previousPrice: Value(e.previousPrice),
            priceChangedAt: Value(e.priceChangedAt),
            archived: Value(e.archived),
            version: Value(e.version),
            createdBy: e.createdBy,
            createdAt: e.createdAt,
          ),
        );
  }

  Future<void> _fiado(String businessId, RemoteFiado e) async {
    final existing =
        await (_db.select(_db.fiados)..where(
              (f) => f.id.equals(e.id) & f.businessId.equals(businessId),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.fiados)
          .insert(
            FiadosCompanion.insert(
              id: e.id,
              businessId: businessId,
              clientId: e.clientId,
              total: e.total,
              occurredAt: e.occurredAt,
              createdBy: e.createdBy,
              annulledAt: Value(e.annulledAt),
              annulledBy: Value(e.annulledBy),
              serverSeq: Value(e.serverSeq),
            ),
          );
      for (final item in e.items) {
        await _db
            .into(_db.fiadoItems)
            .insert(
              FiadoItemsCompanion.insert(
                id: item.id,
                businessId: businessId,
                fiadoId: e.id,
                productId: Value(item.productId),
                description: item.description,
                quantity: item.quantity,
                unit: Value(item.unit.id),
                unitPrice: item.unitPrice,
                subtotal: item.subtotal,
              ),
            );
      }
      return;
    }
    // Un fiado nunca se edita: solo cambian su orden de llegada y su anulación.
    final keepLocalAnnulment =
        e.annulledAt == null && await _hasPendingAnnul(businessId, e.id);
    await (_db.update(_db.fiados)..where((f) => f.id.equals(e.id))).write(
      FiadosCompanion(
        serverSeq: Value(e.serverSeq),
        annulledAt: keepLocalAnnulment
            ? const Value.absent()
            : Value(e.annulledAt),
        annulledBy: keepLocalAnnulment
            ? const Value.absent()
            : Value(e.annulledBy),
      ),
    );
  }

  Future<void> _payment(String businessId, RemotePayment e) async {
    final existing =
        await (_db.select(_db.payments)..where(
              (p) => p.id.equals(e.id) & p.businessId.equals(businessId),
            ))
            .getSingleOrNull();
    if (existing == null) {
      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              id: e.id,
              businessId: businessId,
              clientId: e.clientId,
              amount: e.amount,
              occurredAt: e.occurredAt,
              createdBy: e.createdBy,
              annulledAt: Value(e.annulledAt),
              annulledBy: Value(e.annulledBy),
              serverSeq: Value(e.serverSeq),
            ),
          );
      return;
    }
    final keepLocalAnnulment =
        e.annulledAt == null && await _hasPendingAnnul(businessId, e.id);
    await (_db.update(_db.payments)..where((p) => p.id.equals(e.id))).write(
      PaymentsCompanion(
        serverSeq: Value(e.serverSeq),
        annulledAt: keepLocalAnnulment
            ? const Value.absent()
            : Value(e.annulledAt),
        annulledBy: keepLocalAnnulment
            ? const Value.absent()
            : Value(e.annulledBy),
      ),
    );
  }

  Future<bool> _hasPendingAnnul(String businessId, String entityId) async =>
      (await _pending(
        businessId,
        entityId,
      )).any((o) => o.type == 'fiado.annul' || o.type == 'payment.annul');
}
