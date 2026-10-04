import '../business/amount_mode.dart';
import 'money.dart';

/// Regla común a todo monto ingresado (un total, un precio, un abono): debe
/// ser positivo (RF-32, RF-38) y, con montos enteros, no tener centavos
/// (RF-36). Devuelve null si el monto es válido.
AmountError? amountRuleError(Money money, AmountMode mode) {
  if (!money.isPositive) {
    return AmountError.notPositive;
  }
  if (mode == AmountMode.integer && money.minorUnits % 100 != 0) {
    return AmountError.notWhole;
  }
  return null;
}
