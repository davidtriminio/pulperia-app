import '../../domain/money/money.dart';
import '../../l10n/strings.dart';

/// Mensaje en español para un monto rechazado (RNF-5).
String amountErrorMessage(AmountError error) => switch (error) {
  AmountError.notPositive => Strings.amountNotPositive,
  AmountError.notWhole => Strings.amountNotWhole,
  AmountError.tooManyDecimals => Strings.amountTooManyDecimals,
  AmountError.invalidFormat => Strings.amountInvalid,
};
