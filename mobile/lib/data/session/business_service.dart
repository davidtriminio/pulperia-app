import 'package:drift/drift.dart';

import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../local/app_database.dart';
import '../remote/api_client.dart';
import '../remote/models.dart';
import 'session_service.dart';

/// Los negocios del usuario en este teléfono (RF-5, RF-6, RF-79). Los trae del
/// servidor cuando hay red y los guarda en la base local, para poder elegirlos
/// y trabajar sin conexión.
class BusinessService {
  BusinessService({
    required this.sessions,
    required this.api,
    required this.db,
    required this.now,
  });

  final SessionService sessions;
  final PulperiaApi api;
  final AppDatabase db;
  final DateTime Function() now;

  /// Los negocios del servidor con el rol del usuario en cada uno, guardados
  /// en el teléfono. Requiere conexión: sin ella lanza [NetworkException] y lo
  /// ya guardado sigue disponible con [local].
  Future<List<RemoteBusiness>> refresh() async {
    final session = await sessions.restore();
    if (session == null) {
      throw const SessionExpiredException();
    }
    final list = await api.listBusinesses(await sessions.accessToken());
    for (final business in list) {
      await remember(session.userId, business);
    }
    return list;
  }

  /// Los negocios de este usuario guardados en el teléfono, sin red.
  Future<List<RemoteBusiness>> local() async {
    final session = await sessions.restore();
    if (session == null) {
      return const [];
    }
    final query = db.select(db.memberships).join([
      innerJoin(
        db.businesses,
        db.businesses.id.equalsExp(db.memberships.businessId),
      ),
    ])..where(db.memberships.userId.equals(session.userId));
    query.orderBy([OrderingTerm.asc(db.businesses.name)]);
    return [
      for (final row in await query.get())
        RemoteBusiness(
          id: row.readTable(db.businesses).id,
          name: row.readTable(db.businesses).name,
          role: Role.fromId(row.readTable(db.memberships).role),
          amountMode: AmountMode.fromId(
            row.readTable(db.businesses).amountMode,
          ),
          quantityMode: QuantityMode.fromId(
            row.readTable(db.businesses).quantityMode,
          ),
        ),
    ];
  }

  /// Crea un negocio adicional del que el usuario es dueño (RF-79). Requiere
  /// conexión.
  Future<RemoteBusiness> create({
    required String name,
    required AmountMode amountMode,
    required QuantityMode quantityMode,
  }) async {
    final session = await sessions.restore();
    if (session == null) {
      throw const SessionExpiredException();
    }
    final created = await api.createBusiness(
      await sessions.accessToken(),
      name: name.trim(),
      amountMode: amountMode,
      quantityMode: quantityMode,
    );
    await remember(session.userId, created);
    return created;
  }

  /// Elige el negocio con el que trabajar y lo recuerda (RF-6). No necesita red.
  Future<void> select(RemoteBusiness business) async {
    final session = await sessions.restore();
    if (session == null) {
      throw const SessionExpiredException();
    }
    await remember(session.userId, business);
    await sessions.saveActiveBusiness(business);
  }

  /// Deja el negocio y la pertenencia del usuario en la base local, con los
  /// datos más recientes que se conocen.
  Future<void> remember(String userId, RemoteBusiness business) =>
      db.transaction(() async {
        await db
            .into(db.businesses)
            .insert(
              BusinessesCompanion.insert(
                id: business.id,
                name: business.name,
                amountMode: business.amountMode.id,
                quantityMode: business.quantityMode.id,
                createdAt: now().toUtc(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await (db.update(
          db.businesses,
        )..where((b) => b.id.equals(business.id))).write(
          BusinessesCompanion(
            name: Value(business.name),
            amountMode: Value(business.amountMode.id),
            quantityMode: Value(business.quantityMode.id),
          ),
        );
        await db
            .into(db.memberships)
            .insertOnConflictUpdate(
              MembershipsCompanion.insert(
                userId: userId,
                businessId: business.id,
                role: business.role.id,
              ),
            );
      });
}
