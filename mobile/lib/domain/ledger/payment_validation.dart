import '../business/amount_mode.dart';
import '../money/amount_rules.dart';
import '../money/money.dart';

sealed class PaymentValidationResult {
  const PaymentValidationResult();
}

final class ValidPayment extends PaymentValidationResult {
  const ValidPayment(this.amount);

  final Money amount;
}

final class InvalidPayment extends PaymentValidationResult {
  const InvalidPayment(this.error);

  final AmountError error;
}

/// Valida un abono (RF-37, RF-38): el monto debe ser positivo y, con montos
/// enteros, sin centavos (RF-36). No recibe el saldo del cliente: un abono
/// mayor que la deuda es válido y deja saldo a favor (RF-39).
PaymentValidationResult validatePayment(
  Money amount, {
  required AmountMode amountMode,
}) {
  final error = amountRuleError(amount, amountMode);
  return error == null ? ValidPayment(amount) : InvalidPayment(error);
}
