import 'package:flutter/services.dart';

import '../domain/client/client_validation.dart';

/// Tope de caracteres de cada campo de texto: el campo deja de aceptar más
/// (también al pegar) en lugar de dejar que se rompa una pantalla o se guarde
/// algo desmedido. Solo la nota tiene un límite en la spec (RF-74); los demás
/// son topes de la interfaz, holgados para el uso real.
abstract final class InputLimits {
  /// RF-74.
  static const int note = maxNoteLength;
  static const int name = 60;
  static const int address = 150;
  static const int productName = 60;
  static const int itemDescription = 100;

  /// RF-77: el teléfono tiene exactamente 8 dígitos.
  static const int phoneDigits = 8;

  /// Un monto de hasta 10 caracteres ("9999999.99").
  static const int amount = 10;
  static const int quantity = 8;

  static List<TextInputFormatter> text(int max) => [
    LengthLimitingTextInputFormatter(max),
  ];

  static List<TextInputFormatter> digits(int max) => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(max),
  ];
}
