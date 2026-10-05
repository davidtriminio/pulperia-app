import '../../domain/business/amount_mode.dart';
import '../../domain/money/money.dart';

/// Muestra un monto como el usuario lo lee: `L 1,234.50` con 2 decimales o
/// `L 1,234` con enteros. Solo aritmética entera, sin `double` (principio 5).
String formatMoney(Money money, AmountMode mode) {
  final negative = money.isNegative;
  final minor = money.minorUnits.abs();
  final lempiras = minor ~/ 100;
  final centavos = minor % 100;

  final whole = _withThousands(lempiras);
  final number = mode == AmountMode.twoDecimals
      ? '$whole.${centavos.toString().padLeft(2, '0')}'
      : whole;
  return '${negative ? '-' : ''}L $number';
}

String _withThousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
