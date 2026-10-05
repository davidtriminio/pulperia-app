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
  /// (RF-86, RF-88, D-23).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Lo que ya existía queda con la unidad por omisión ("unidad").
        await m.addColumn(products, products.unit);
        await m.addColumn(fiadoItems, fiadoItems.unit);
      }
    },
    beforeOpen: (details) async {
      // SQLite no aplica las claves foráneas salvo que se active.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
