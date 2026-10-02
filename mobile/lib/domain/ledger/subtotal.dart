import '../money/money.dart';
import '../quantity/quantity.dart';

/// Subtotal de un ítem en un negocio con montos enteros: cantidad por precio
/// unitario, redondeado al lempira entero más cercano con la mitad hacia
/// arriba (RF-34). Todo con aritmética de enteros, sin decimales de punto
/// flotante.
Money wholeLempiraSubtotal({
  required Quantity quantity,
  required Money unitPrice,
}) {
  assert(quantity.milli > 0, 'la cantidad debe ser positiva');
  assert(unitPrice.isPositive, 'el precio unitario debe ser positivo');

  const milliPerUnit = 1000;
  const minorUnitsPerLempira = 100;
  const unitsPerWholeLempira = milliPerUnit * minorUnitsPerLempira;

  // quantity.milli * unitPrice.minorUnits son milésimas de centavo.
  final exactMilliCents = quantity.milli * unitPrice.minorUnits;
  final wholeLempiras =
      (exactMilliCents + unitsPerWholeLempira ~/ 2) ~/ unitsPerWholeLempira;

  return Money(wholeLempiras * minorUnitsPerLempira);
}

/// Subtotal de un ítem en un negocio con montos de 2 decimales: cantidad por
/// precio unitario, redondeado al centavo más cercano con la mitad hacia
/// arriba (RF-83). Todo con aritmética de enteros.
Money centavoSubtotal({required Quantity quantity, required Money unitPrice}) {
  assert(quantity.milli > 0, 'la cantidad debe ser positiva');
  assert(unitPrice.isPositive, 'el precio unitario debe ser positivo');

  const milliPerUnit = 1000;

  // quantity.milli * unitPrice.minorUnits son milésimas de centavo.
  final exactMilliCents = quantity.milli * unitPrice.minorUnits;

  return Money((exactMilliCents + milliPerUnit ~/ 2) ~/ milliPerUnit);
}
