import '../../domain/quantity/quantity.dart';

/// Muestra una cantidad sin ceros sobrantes: `2`, `1.5`, `0.25`. Solo
/// aritmética entera, sin `double`.
String formatQuantity(Quantity quantity) {
  final whole = quantity.milli ~/ 1000;
  final fraction = (quantity.milli % 1000).toString().padLeft(3, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole' : '$whole.$trimmed';
}
