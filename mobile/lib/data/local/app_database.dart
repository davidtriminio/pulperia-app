import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Base de datos local del móvil (SQLite vía Drift). Todo cambio se escribe
/// primero aquí (principio 2).
@DriftDatabase(
  tables: [
    Businesses,
    Memberships,
    Clients,
    Products,
    Fiados,
    FiadoItems,
    Payments,
    OutboxOps,
    SyncStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 1: esquema inicial. 2: unidad de venta en productos e ítems de fiado
  /// (RF-86, RF-88, D-23). 3: precio anterior y fecha del cambio en productos
  /// (RF-90, D-24).
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Lo que ya existía queda con la unidad por omisión ("unidad").
        await m.addColumn(products, products.unit);
        await m.addColumn(fiadoItems, fiadoItems.unit);
      }
      if (from < 3) {
        // Lo que ya existía queda sin precio anterior (nulo).
        await m.addColumn(products, products.previousPrice);
        await m.addColumn(products, products.priceChangedAt);
      }
    },
    beforeOpen: (details) async {
      // SQLite no aplica las claves foráneas salvo que se active.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
