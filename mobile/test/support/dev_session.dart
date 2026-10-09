import 'package:drift/drift.dart';
import 'package:pulperia_mobile/app/session_state.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/data/session/session_store.dart';
import 'package:pulperia_mobile/domain/access/access.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/business/quantity_mode.dart';

import 'fake_api.dart';

/// Negocio y usuario fijos para las pruebas: el "negocio activo" que las
/// pantallas reciben sobrescribiendo `activeSessionProvider`. La app real saca
/// el negocio activo de la sesión (T088).
typedef DevSession = ActiveSession;

const _devSession = ActiveSession(
  businessId: '00000000-0000-7000-8000-00000000d001',
  businessName: 'Pulpería de prueba',
  userId: '00000000-0000-7000-8000-00000000d002',
  role: Role.owner,
  amountMode: AmountMode.twoDecimals,
  quantityMode: QuantityMode.fractional,
);

/// La sesión de prueba. El parámetro se conserva por compatibilidad con los
/// tests existentes; siempre existe.
DevSession? devSessionFor({bool isRelease = false}) =>
    isRelease ? null : _devSession;

/// Deja en la base local el negocio y la pertenencia de la sesión de prueba.
/// Es idempotente y no pisa cambios hechos después.
Future<void> seedDevSession(AppDatabase db, DevSession? session) async {
  if (session == null) {
    return;
  }
  await db.transaction(() async {
    await db
        .into(db.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: session.businessId,
            name: session.businessName,
            amountMode: session.amountMode.id,
            quantityMode: session.quantityMode.id,
            createdAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.memberships)
        .insert(
          MembershipsCompanion.insert(
            userId: session.userId,
            businessId: session.businessId,
            role: session.role.id,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });
}

/// Un almacén de sesión con la sesión de prueba ya iniciada y su negocio como
/// activo, para arrancar la app completa en un test.
MemorySessionStore devSignedInStore() {
  final dev = devSessionFor()!;
  return MemorySessionStore(
    StoredSession(
      userId: dev.userId,
      email: 'ana@correo.com',
      tokens: tokensAt(DateTime.now().toUtc()),
      activeBusiness: remoteBusiness(
        dev.businessId,
        name: dev.businessName,
        role: dev.role,
        amountMode: dev.amountMode,
        quantityMode: dev.quantityMode,
      ),
    ),
  );
}
