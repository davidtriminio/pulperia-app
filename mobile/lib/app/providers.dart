import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/ids.dart';
import '../data/local/app_database.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/fiado_repository.dart';
import '../data/repositories/ledger_queries.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/summary_queries.dart';
import '../data/remote/api_client.dart';
import '../data/session/session_service.dart';
import '../data/session/session_store.dart';
import '../domain/access/access.dart';
import 'session_controller.dart';
import 'session_state.dart';

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

/// Dirección del servidor. Se fija al compilar con
/// `--dart-define=API_BASE_URL=https://...`. En depuración, sin ella, se usa la
/// API local vista desde el emulador de Android; una compilación de producción
/// exige definirla (D-31).
final apiBaseUrlProvider = Provider<Uri>((ref) {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) {
    return Uri.parse(configured);
  }
  if (kDebugMode) {
    return Uri.parse('http://10.0.2.2:5109');
  }
  throw StateError('Falta --dart-define=API_BASE_URL');
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// El servidor (D-17). Los tests lo sobrescriben con uno falso.
final pulperiaApiProvider = Provider<PulperiaApi>(
  (ref) => HttpPulperiaApi(
    ref.watch(httpClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

/// Dónde se guarda la sesión: el almacenamiento seguro del sistema (D-31).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(
    api: ref.watch(pulperiaApiProvider),
    store: ref.watch(sessionStoreProvider),
    now: ref.watch(clockProvider),
  ),
);

/// La sesión de este teléfono (RF-3).
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

/// Usuario, negocio y rol con los que se trabaja. Solo existe con sesión
/// iniciada y un negocio elegido; la interfaz solo construye pantallas de
/// trabajo en ese caso.
final activeSessionProvider = Provider<ActiveSession>((ref) {
  final state = ref.watch(sessionControllerProvider).value;
  final active = state is SignedIn ? state.active : null;
  if (state is! SignedIn || active == null) {
    throw StateError('No hay sesión con un negocio elegido');
  }
  return ActiveSession(
    businessId: active.id,
    businessName: active.name,
    userId: state.userId,
    role: active.role,
    amountMode: active.amountMode,
    quantityMode: active.quantityMode,
  );
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
