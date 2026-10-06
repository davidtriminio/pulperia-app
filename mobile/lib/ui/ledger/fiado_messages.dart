import '../../domain/ledger/fiado_validation.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';
import '../format/amount_messages.dart';
import '../format/quantity_messages.dart';

/// Mensaje en español para un problema que el dominio encontró en un fiado
/// (RNF-5). Los códigos son los estables del dominio.
String fiadoIssueMessage(FiadoIssue issue) {
  if (issue.field == FiadoField.subtotal) {
    return Strings.subtotalZero;
  }
  for (final error in QuantityError.values) {
    if (error.code == issue.code) {
      return quantityErrorMessage(error);
    }
  }
  for (final error in AmountError.values) {
    if (error.code == issue.code) {
      return amountErrorMessage(error);
    }
  }
  return Strings.fiadoEmpty;
}
