import '../data/remote/models.dart';
import '../domain/access/access.dart';
import '../domain/business/amount_mode.dart';
import '../domain/business/quantity_mode.dart';

/// Estado de la sesión de este teléfono (RF-3, RF-6).
sealed class SessionState {
  const SessionState();
}

/// Nadie ha iniciado sesión.
final class SignedOut extends SessionState {
  const SignedOut();
}

/// Un usuario con sesión. [active] es el negocio con el que trabaja; null
/// mientras no haya elegido uno (RF-6).
final class SignedIn extends SessionState {
  const SignedIn({required this.userId, required this.email, this.active});

  final String userId;
  final String email;
  final RemoteBusiness? active;
}

/// Usuario, negocio y rol con los que trabaja la app en este momento. Todo lo
/// que se muestra y se escribe corresponde a este negocio (RF-6, RNF-6).
final class ActiveSession {
  const ActiveSession({
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
