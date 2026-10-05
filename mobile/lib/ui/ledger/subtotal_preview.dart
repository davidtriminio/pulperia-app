import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../domain/ledger/subtotal.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';

/// Subtotal de un ítem tal como se escribe en el formulario, para mostrarlo
/// mientras se teclea. Usa las mismas reglas de redondeo del dominio (RF-34,
/// RF-83). Devuelve null si algún campo está vacío o no es válido, o si el
/// subtotal redondea a cero.
Money? previewSubtotal({
  required String quantity,
  required String unitPrice,
  required AmountMode amountMode,
  required QuantityMode quantityMode,
}) {
  final parsedQuantity = Quantity.parse(quantity.trim(), quantityMode);
  final parsedPrice = Money.parse(unitPrice.trim(), amountMode);
  if (parsedQuantity is! QuantityParsed || parsedPrice is! MoneyParsed) {
    return null;
  }

  final subtotal = switch (amountMode) {
    AmountMode.integer => wholeLempiraSubtotal(
      quantity: parsedQuantity.quantity,
      unitPrice: parsedPrice.money,
    ),
    AmountMode.twoDecimals => centavoSubtotal(
      quantity: parsedQuantity.quantity,
      unitPrice: parsedPrice.money,
    ),
  };
  return subtotal.isPositive ? subtotal : null;
}
