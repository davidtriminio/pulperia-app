import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import '../domain/access/access.dart';
import '../domain/business/amount_mode.dart';
import '../domain/business/quantity_mode.dart';

/// Negocio y usuario fijos para probar la app sin servidor. Solo existen fuera
/// de modo release y se eliminan al llegar la sesión real (T088).
@immutable
class DevSession {
  const DevSession({
    required this.businessId,
    required this.businessName,
    required this.userId,
    required this.role,
    required this.amountMode,
    required this.quantityMode,
  });

  final String businessId;
  final String businessName;
  final String userId;
  final Role role;
  final AmountMode amountMode;
  final QuantityMode quantityMode;
}

/// Ajustes del negocio de prueba: los más permisivos, para ejercitar los
/// decimales en montos y cantidades.
const _devSession = DevSession(
  businessId: '00000000-0000-7000-8000-00000000d001',
  businessName: 'Pulpería de prueba',
  userId: '00000000-0000-7000-8000-00000000d002',
  role: Role.owner,
  amountMode: AmountMode.twoDecimals,
  quantityMode: QuantityMode.fractional,
);

/// La sesión simulada, o `null` en modo release: una app publicada nunca debe
/// arrancar con un usuario falso.
DevSession? devSessionFor({bool isRelease = kReleaseMode}) =>
    isRelease ? null : _devSession;

/// Deja en la base local el negocio y la pertenencia de la sesión simulada.
/// Es idempotente y no pisa cambios que se hayan hecho después. Sin sesión
/// (modo release) no escribe nada.
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
