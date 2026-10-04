import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/product_validation.dart';
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
        payload: {'name': valid.name, 'price': valid.price.minorUnits},
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

      await (_db.update(_db.products)..where(
            (p) => p.id.equals(productId) & p.businessId.equals(businessId),
          ))
          .write(
            ProductsCompanion(
              name: Value(valid.name),
              price: Value(valid.price.minorUnits),
              version: Value(current.version + 1),
            ),
          );
      await _enqueue(
        opId: opId,
        businessId: businessId,
        type: 'product.update',
        entityId: productId,
        baseVersion: current.version,
        payload: {'name': valid.name, 'price': valid.price.minorUnits},
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
