import '../business/quantity_mode.dart';

/// Motivo por el que se rechaza una cantidad ingresada.
enum QuantityError {
  notPositive('quantity_not_positive'),
  notWhole('quantity_not_whole'),
  tooManyDecimals('quantity_too_many_decimals'),
  invalidFormat('quantity_invalid_format');

  const QuantityError(this.code);

  /// Código estable, el mismo de los vectores compartidos.
  final String code;
}

sealed class QuantityParseResult {
  const QuantityParseResult();
}

final class QuantityParsed extends QuantityParseResult {
  const QuantityParsed(this.quantity);

  final Quantity quantity;
}

final class QuantityRejected extends QuantityParseResult {
  const QuantityRejected(this.error);

  final QuantityError error;
}

/// Cantidad exacta, guardada como entero en milésimas (0.25 es 250).
/// Nunca usa decimales de punto flotante.
final class Quantity {
  const Quantity(this.milli);

  static const int _milliPerUnit = 1000;
  static const int _maxDecimals = 3;
  static final RegExp _plainDecimal = RegExp(r'^(-?)([0-9]+)(?:\.([0-9]+))?$');

  final int milli;

  bool get isWhole => milli % _milliPerUnit == 0;

  /// Lee el texto que escribió el usuario (punto decimal, sin separadores de
  /// miles) según el modo de cantidades del negocio.
  static QuantityParseResult parse(String text, QuantityMode mode) {
    final match = _plainDecimal.firstMatch(text);
    if (match == null) {
      return const QuantityRejected(QuantityError.invalidFormat);
    }

    final negative = match.group(1) == '-';
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';

    final isZero = RegExp(r'^0*$').hasMatch(whole + fraction);
    if (negative || isZero) {
      return const QuantityRejected(QuantityError.notPositive);
    }

    final hasFraction = RegExp(r'[1-9]').hasMatch(fraction);
    switch (mode) {
      case QuantityMode.integer:
        if (hasFraction) return const QuantityRejected(QuantityError.notWhole);
      case QuantityMode.fractional:
        if (fraction.length > _maxDecimals) {
          return const QuantityRejected(QuantityError.tooManyDecimals);
        }
    }

    final milliFraction = fraction
        .padRight(_maxDecimals, '0')
        .substring(0, _maxDecimals);
    return QuantityParsed(
      Quantity(int.parse(whole) * _milliPerUnit + int.parse(milliFraction)),
    );
  }

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => 'Quantity($milli)';
}
