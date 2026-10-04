import '../business/amount_mode.dart';

/// Motivo por el que se rechaza un monto ingresado.
enum AmountError {
  notPositive('amount_not_positive'),
  notWhole('amount_not_whole'),
  tooManyDecimals('amount_too_many_decimals'),
  invalidFormat('amount_invalid_format');

  const AmountError(this.code);

  /// Código estable, el mismo de los vectores compartidos.
  final String code;
}

sealed class MoneyParseResult {
  const MoneyParseResult();
}

final class MoneyParsed extends MoneyParseResult {
  const MoneyParsed(this.money);

  final Money money;
}

final class MoneyRejected extends MoneyParseResult {
  const MoneyRejected(this.error);

  final AmountError error;
}

/// Monto de dinero exacto, guardado como entero en la unidad menor
/// (centavos de lempira). Nunca usa decimales de punto flotante.
///
/// Puede ser negativo: un saldo negativo es saldo a favor del cliente.
final class Money implements Comparable<Money> {
  const Money(this.minorUnits);

  static const Money zero = Money(0);

  static const int _minorUnitsPerLempira = 100;
  static const int _maxDecimals = 2;
  static final RegExp _plainDecimal = RegExp(r'^(-?)([0-9]+)(?:\.([0-9]+))?$');

  final int minorUnits;

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);
  Money operator -(Money other) => Money(minorUnits - other.minorUnits);
  Money operator -() => Money(-minorUnits);

  bool operator <(Money other) => minorUnits < other.minorUnits;
  bool operator <=(Money other) => minorUnits <= other.minorUnits;
  bool operator >(Money other) => minorUnits > other.minorUnits;
  bool operator >=(Money other) => minorUnits >= other.minorUnits;

  /// Lee el texto que escribió el usuario (punto decimal, sin separadores de
  /// miles) según el modo de montos del negocio. Devuelve centavos de lempira.
  static MoneyParseResult parse(String text, AmountMode mode) {
    final match = _plainDecimal.firstMatch(text);
    if (match == null) {
      return const MoneyRejected(AmountError.invalidFormat);
    }

    final negative = match.group(1) == '-';
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';

    final isZero = RegExp(r'^0*$').hasMatch(whole + fraction);
    if (negative || isZero) {
      return const MoneyRejected(AmountError.notPositive);
    }

    final hasFraction = RegExp(r'[1-9]').hasMatch(fraction);
    switch (mode) {
      case AmountMode.integer:
        if (hasFraction) {
          return const MoneyRejected(AmountError.notWhole);
        }
      case AmountMode.twoDecimals:
        if (fraction.length > _maxDecimals) {
          return const MoneyRejected(AmountError.tooManyDecimals);
        }
    }

    final centavos = mode == AmountMode.integer
        ? 0
        : int.parse(fraction.padRight(_maxDecimals, '0'));
    final minor = int.parse(whole) * _minorUnitsPerLempira + centavos;
    return MoneyParsed(Money(minor));
  }

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Money($minorUnits)';
}
