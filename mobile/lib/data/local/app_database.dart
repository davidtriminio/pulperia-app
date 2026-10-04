import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Base de datos local del móvil (SQLite vía Drift). Todo cambio se escribe
/// primero aquí (principio 2).
@DriftDatabase(tables: [Businesses, Memberships, Clients, Products])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // SQLite no aplica las claves foráneas salvo que se active.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
