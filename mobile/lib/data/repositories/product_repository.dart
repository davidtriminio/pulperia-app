import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/price_change.dart';
import '../../domain/catalog/product_validation.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/money/money.dart';
import '../local/app_database.dart';

sealed class ProductSaveResult {
  const ProductSaveResult();
}

/// El producto se guardó y su operación quedó en la cola.
final class ProductSaved extends ProductSaveResult {
  const ProductSaved(this.product);

  final Product product;
}

/// Los datos no son válidos; no se escribió nada.
final class ProductRejected extends ProductSaveResult {
  const ProductRejected(this.issues);

  final List<ProductIssue> issues;
}

/// El producto no existe en ese negocio; no se escribió nada.
final class ProductNotFound extends ProductSaveResult {
  const ProductNotFound();
}

/// El rol del usuario no permite la acción; no se escribió nada.
final class ProductForbidden extends ProductSaveResult {
  const ProductForbidden();
}

/// Administra el catálogo de productos en la base local. Cada cambio se
/// escribe junto con su operación en la cola, en una sola transacción
/// (principio 2).
///
/// Un producto nunca se borra (RF-27): se archiva. Cambiarle el precio o
/// archivarlo no toca los ítems de fiado ya registrados, que guardaron su
/// propia descripción y precio (RF-25, RF-26, principio 4).
class ProductRepository {
  ProductRepository(this._db, {required this._newId, required this._now});

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  /// Crea un producto (RF-24).
  Future<ProductSaveResult> create({
    required String businessId,
    required String userId,
    required Role role,
    required String name,
    required Money price,
    SaleUnit unit = SaleUnit.defaultUnit,
  }) async {
    if (!can(role, Permission.manageCatalog)) {
      return const ProductForbidden();
    }
    final validation = validateProduct(
      name: name,
      price: price,
      amountMode: await _amountMode(businessId),
    );
    if (validation is InvalidProduct) {
      return ProductRejected(validation.issues);
    }
    final valid = validation as ValidProduct;

    final productId = _newId();
    final opId = _newId();
    final now = _now();

    return _db.transaction(() async {
      await _db
          .into(_db.products)
          .insert(
            ProductsCompanion.insert(
              id: productId,
              businessId: businessId,
              name: valid.name,
              price: valid.price.minorUnits,
              unit: Value(unit.id),
              createdBy: userId,
              createdAt: now,
            ),
          );
      await _enqueue(
        opId: opId,
        businessId: businessId,
        type: 'product.create',
        entityId: productId,
        baseVersion: null,
        payload: {
          'name': valid.name,
          'price': valid.price.minorUnits,
          'unit': unit.id,
        },
        now: now,
      );
      return ProductSaved(await _find(businessId, productId) as Product);
    });
  }

  /// Cambia el nombre y el precio de un producto (RF-25). La versión local
  /// sube con cada edición, de modo que ediciones seguidas sin sincronizar
  /// encadenan sus versiones base (D-8).
  Future<ProductSaveResult> update({
    required String businessId,
    required String userId,
    required Role role,
    required String productId,
    required String name,
    required Money price,
    SaleUnit? unit,
  }) async {
    if (!can(role, Permission.manageCatalog)) {
      return const ProductForbidden();
    }
    final validation = validateProduct(
      name: name,
      price: price,
      amountMode: await _amountMode(businessId),
    );
    if (validation is InvalidProduct) {
      return ProductRejected(validation.issues);
    }
    final valid = validation as ValidProduct;

    final opId = _newId();
    final now = _now();

    return _db.transaction(() async {
      final current = await _find(businessId, productId);
      if (current == null) {
        return const ProductNotFound();
      }
      // Sin unidad indicada se conserva la que tenía.
      final effectiveUnit = unit ?? SaleUnit.fromId(current.unit);

      // Un precio distinto deja el vigente como anterior, con la fecha del
      // cambio; si el precio es el mismo no se toca (RF-90, D-24). Los ítems
      // de fiado ya guardados no se tocan (RF-25).
      final history = applyPriceChange(
        currentPrice: Money(current.price),
        current: PriceHistory(
          previousPrice: current.previousPrice == null
              ? null
              : Money(current.previousPrice!),
          changedAt: current.priceChangedAt,
        ),
        newPrice: valid.price,
        at: now,
      );

      await (_db.update(_db.products)..where(
            (p) => p.id.equals(productId) & p.businessId.equals(businessId),
          ))
          .write(
            ProductsCompanion(
              name: Value(valid.name),
              price: Value(valid.price.minorUnits),
              unit: Value(effectiveUnit.id),
              previousPrice: Value(history.previousPrice?.minorUnits),
              priceChangedAt: Value(history.changedAt),
              version: Value(current.version + 1),
            ),
          );
      await _enqueue(
        opId: opId,
        businessId: businessId,
        type: 'product.update',
        entityId: productId,
        baseVersion: current.version,
        payload: {
          'name': valid.name,
          'price': valid.price.minorUnits,
          'unit': effectiveUnit.id,
        },
        now: now,
      );
      return ProductSaved(await _find(businessId, productId) as Product);
    });
  }

  /// Archiva un producto (RF-26): deja de ofrecerse al fiar, pero se conserva
  /// (RF-27). Archivar uno que ya está archivado no cambia nada.
  Future<ProductSaveResult> archive({
    required String businessId,
    required String userId,
    required Role role,
    required String productId,
  }) async {
    if (!can(role, Permission.manageCatalog)) {
      return const ProductForbidden();
    }

    final opId = _newId();
    final now = _now();

    return _db.transaction(() async {
      final current = await _find(businessId, productId);
      if (current == null) {
        return const ProductNotFound();
      }
      if (current.archived) {
        return ProductSaved(current);
      }

      await (_db.update(_db.products)..where(
            (p) => p.id.equals(productId) & p.businessId.equals(businessId),
          ))
          .write(
            ProductsCompanion(
              archived: const Value(true),
              version: Value(current.version + 1),
            ),
          );
      await _enqueue(
        opId: opId,
        businessId: businessId,
        type: 'product.archive',
        entityId: productId,
        baseVersion: current.version,
        payload: const {},
        now: now,
      );
      return ProductSaved(await _find(businessId, productId) as Product);
    });
  }

  /// Productos que se pueden ofrecer al fiar.
  Future<List<Product>> activeProducts(String businessId) =>
      _list(businessId, archived: false);

  Future<List<Product>> archivedProducts(String businessId) =>
      _list(businessId, archived: true);

  /// Los productos activos que más se fían en el negocio, para ofrecerlos de
  /// entrada al fiar. Se ordenan por veces fiado (sin contar movimientos
  /// anulados), con empate por nombre; si hay menos que [limit], se completa
  /// con los más recientes. Es solo una vista de lectura: no escribe nada.
  Future<List<Product>> frequentProducts(
    String businessId, {
    int limit = 8,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT i.product_id AS product_id, COUNT(*) AS times '
          'FROM fiado_items i '
          'JOIN fiados f ON f.id = i.fiado_id AND f.business_id = i.business_id '
          'WHERE i.business_id = ?1 AND i.product_id IS NOT NULL '
          'AND f.annulled_at IS NULL '
          'GROUP BY i.product_id',
          variables: [Variable.withString(businessId)],
          readsFrom: {_db.fiadoItems, _db.fiados},
        )
        .get();
    final times = {
      for (final r in rows) r.read<String>('product_id'): r.read<int>('times'),
    };

    final active = await activeProducts(businessId);
    final used = [
      for (final p in active)
        if (times.containsKey(p.id)) p,
    ]..sort((a, b) => times[b.id]!.compareTo(times[a.id]!));
    // `activeProducts` ya viene ordenada por nombre y el sort es estable, así
    // que los empates quedan por nombre.
    final recent = [
      for (final p in active)
        if (!times.containsKey(p.id)) p,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [...used, ...recent].take(limit).toList();
  }

  /// En orden alfabético sin distinguir mayúsculas; los empates, por id.
  Future<List<Product>> _list(
    String businessId, {
    required bool archived,
  }) async {
    final products =
        await (_db.select(_db.products)..where(
              (p) =>
                  p.businessId.equals(businessId) & p.archived.equals(archived),
            ))
            .get();
    products.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
    return products;
  }

  Future<AmountMode> _amountMode(String businessId) async {
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
    return AmountMode.fromId(business.amountMode);
  }

  Future<Product?> _find(String businessId, String productId) =>
      (_db.select(_db.products)..where(
            (p) => p.id.equals(productId) & p.businessId.equals(businessId),
          ))
          .getSingleOrNull();

  Future<void> _enqueue({
    required String opId,
    required String businessId,
    required String type,
    required String entityId,
    required int? baseVersion,
    required Map<String, Object?> payload,
    required DateTime now,
  }) => _db
      .into(_db.outboxOps)
      .insert(
        OutboxOpsCompanion.insert(
          opId: opId,
          businessId: businessId,
          type: type,
          entityId: entityId,
          payload: jsonEncode(payload),
          baseVersion: Value(baseVersion),
          createdAt: now,
        ),
      );
}
