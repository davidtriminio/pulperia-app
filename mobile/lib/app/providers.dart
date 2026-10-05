import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ids.dart';
import '../data/local/app_database.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/fiado_repository.dart';
import '../data/repositories/ledger_queries.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/summary_queries.dart';
import '../dev/dev_session.dart';
import '../domain/access/access.dart';

/// La base local. No tiene valor por omisión: `main` (o un test) la abre y la
/// sobrescribe, para no abrir una base vacía por accidente.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('appDatabaseProvider no fue sobrescrito'),
);

/// Generador único de ids (D-21).
final idGeneratorProvider = Provider<IdGenerator>((ref) => newId);

/// Reloj de los repositorios; los tests lo sobrescriben.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// Sesión activa. Hasta la sesión real (T088) es la simulada de depuración;
/// en modo release no hay ninguna y la app no puede arrancar sin ella.
final activeSessionProvider = Provider<DevSession>((ref) {
  final session = devSessionFor();
  if (session == null) {
    throw StateError('No hay sesión: la sesión real llega con T088');
  }
  return session;
});

/// Usuario activo y su rol en el negocio activo.
final class ActiveUser {
  const ActiveUser({required this.id, required this.role});

  final String id;
  final Role role;
}

final activeUserProvider = Provider<ActiveUser>((ref) {
  final session = ref.watch(activeSessionProvider);
  return ActiveUser(id: session.userId, role: session.role);
});

/// Id del negocio activo.
final activeBusinessIdProvider = Provider<String>(
  (ref) => ref.watch(activeSessionProvider).businessId,
);

/// El negocio activo, leído de la base local (con sus modos de montos y
/// cantidades).
final activeBusinessProvider = FutureProvider<Business>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final id = ref.watch(activeBusinessIdProvider);
  return (db.select(db.businesses)..where((b) => b.id.equals(id))).getSingle();
});

final clientRepositoryProvider = Provider(
  (ref) => ClientRepository(
    ref.watch(appDatabaseProvider),
    newId: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final productRepositoryProvider = Provider(
  (ref) => ProductRepository(
    ref.watch(appDatabaseProvider),
    newId: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final fiadoRepositoryProvider = Provider(
  (ref) => FiadoRepository(
    ref.watch(appDatabaseProvider),
    newId: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final paymentRepositoryProvider = Provider(
  (ref) => PaymentRepository(
    ref.watch(appDatabaseProvider),
    newId: ref.watch(idGeneratorProvider),
    now: ref.watch(clockProvider),
  ),
);

final ledgerQueriesProvider = Provider(
  (ref) => LedgerQueries(ref.watch(appDatabaseProvider)),
);

final summaryQueriesProvider = Provider(
  (ref) => SummaryQueries(ref.watch(appDatabaseProvider)),
);
