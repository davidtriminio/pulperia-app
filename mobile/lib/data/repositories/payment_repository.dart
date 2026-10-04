import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/ledger/payment_validation.dart';
import '../../domain/money/money.dart';
import '../local/app_database.dart';
import 'annul_result.dart';

sealed class PaymentSaveResult {
  const PaymentSaveResult();
}

/// El abono se guardó y su operación quedó en la cola.
final class PaymentSaved extends PaymentSaveResult {
  const PaymentSaved(this.payment);

  final Payment payment;
}

/// El monto no es válido; no se escribió nada.
final class PaymentRejected extends PaymentSaveResult {
  const PaymentRejected(this.error);

  final AmountError error;
}

/// El cliente no existe en ese negocio; no se escribió nada.
final class PaymentClientNotFound extends PaymentSaveResult {
  const PaymentClientNotFound();
}

/// El rol del usuario no permite la acción; no se escribió nada.
final class PaymentForbidden extends PaymentSaveResult {
  const PaymentForbidden();
}

/// Registra abonos en la base local. El abono y su operación en la cola se
/// escriben en una sola transacción: si algo falla, no queda nada (principio
/// 2).
///
/// Un abono no se edita ni se borra una vez registrado (RF-46): solo se anula.
class PaymentRepository {
  PaymentRepository(this._db, {required this._newId, required this._now});

  final AppDatabase _db;
  final String Function() _newId;
  final DateTime Function() _now;

  /// Registra un abono de un cliente (RF-37): reduce su saldo total, sin
  /// asociarse a ningún fiado ni ítem. Si supera la deuda, se acepta y deja
  /// saldo a favor (RF-39). Un cliente archivado también puede abonar
  /// (RF-75), y sigue archivado. Queda anotado quién lo registró (RF-49).
  Future<PaymentSaveResult> create({
    required String businessId,
    required String userId,
    required Role role,
    required String clientId,
    required Money amount,
  }) async {
    if (!can(role, Permission.registerPayment)) {
      return const PaymentForbidden();
    }

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
    final amountMode = AmountMode.fromId(business.amountMode);

    final paymentId = _newId();
    final opId = _newId();
    final now = _now();

    return _db.transaction(() async {
      final client =
          await (_db.select(_db.clients)..where(
                (c) => c.id.equals(clientId) & c.businessId.equals(businessId),
              ))
              .getSingleOrNull();
      if (client == null) {
        return const PaymentClientNotFound();
      }

      final validation = validatePayment(amount, amountMode: amountMode);
      if (validation is InvalidPayment) {
        return PaymentRejected(validation.error);
      }

      await _db
          .into(_db.payments)
          .insert(
            PaymentsCompanion.insert(
              id: paymentId,
              businessId: businessId,
              clientId: clientId,
              amount: amount.minorUnits,
              occurredAt: now,
              createdBy: userId,
            ),
          );
      await _db
          .into(_db.outboxOps)
          .insert(
            OutboxOpsCompanion.insert(
              opId: opId,
              businessId: businessId,
              type: 'payment.create',
              entityId: paymentId,
              payload: jsonEncode({
                'clientId': clientId,
                'amount': amount.minorUnits,
                'occurredAt': now.toUtc().toIso8601String(),
              }),
              createdAt: now,
            ),
          );

      return PaymentSaved(
        await (_db.select(
          _db.payments,
        )..where((p) => p.id.equals(paymentId))).getSingle(),
      );
    });
  }

  /// Anula un abono (RF-43): se conserva en el historial, marcado con quién y
  /// cuándo lo anuló, y deja de contar en el saldo del cliente (RF-44). Solo
  /// el dueño puede (RF-45). Un abono no se edita ni se borra (RF-46).
  /// Anular uno ya anulado no cambia nada.
  Future<AnnulResult<Payment>> annul({
    required String businessId,
    required String userId,
    required Role role,
    required String paymentId,
  }) async {
    if (!can(role, Permission.annulMovement)) {
      return const AnnulForbidden();
    }

    final opId = _newId();
    final now = _now();

    return _db.transaction(() async {
      final current =
          await (_db.select(_db.payments)..where(
                (p) => p.id.equals(paymentId) & p.businessId.equals(businessId),
              ))
              .getSingleOrNull();
      if (current == null) {
        return const AnnulNotFound();
      }
      if (current.annulledAt != null) {
        return Annulled(current, alreadyAnnulled: true);
      }

      await (_db.update(_db.payments)..where(
            (p) => p.id.equals(paymentId) & p.businessId.equals(businessId),
          ))
          .write(
            PaymentsCompanion(
              annulledAt: Value(now),
              annulledBy: Value(userId),
            ),
          );
      await _db
          .into(_db.outboxOps)
          .insert(
            OutboxOpsCompanion.insert(
              opId: opId,
              businessId: businessId,
              type: 'payment.annul',
              entityId: paymentId,
              payload: '{}',
              createdAt: now,
            ),
          );

      final annulled = await (_db.select(
        _db.payments,
      )..where((p) => p.id.equals(paymentId))).getSingle();
      return Annulled(annulled, alreadyAnnulled: false);
    });
  }
}
