import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';

/// Mensaje en español para una cantidad rechazada (RNF-5).
String quantityErrorMessage(QuantityError error) => switch (error) {
  QuantityError.notPositive => Strings.quantityNotPositive,
  QuantityError.notWhole => Strings.quantityNotWhole,
  QuantityError.tooManyDecimals => Strings.quantityTooManyDecimals,
  QuantityError.invalidFormat => Strings.quantityInvalid,
};
