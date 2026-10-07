import '../money/money.dart';

/// El precio anterior de un producto y cuándo cambió (RF-90, D-24). Es solo
/// el último anterior, no un historial: cada cambio de precio reemplaza al
/// guardado. Ambos son nulos mientras el precio nunca ha cambiado.
final class PriceHistory {
  const PriceHistory({this.previousPrice, this.changedAt});

  final Money? previousPrice;

  /// Fecha del cambio, en UTC.
  final DateTime? changedAt;
}

/// Lo que guarda un producto tras cambiarle el precio de [currentPrice] a
/// [newPrice] en la fecha [at] (la de creación de la operación).
///
/// Un precio distinto deja el vigente como anterior y [at] como fecha,
/// sustituyendo lo que hubiera; un precio igual (por ejemplo cuando solo
/// cambia el nombre o la unidad) no toca nada y devuelve [current]. Debe dar
/// lo mismo que `shared/vectors/price-change.json`.
PriceHistory applyPriceChange({
  required Money currentPrice,
  required PriceHistory current,
  required Money newPrice,
  required DateTime at,
}) {
  if (newPrice == currentPrice) {
    return current;
  }
  return PriceHistory(previousPrice: currentPrice, changedAt: at.toUtc());
}
