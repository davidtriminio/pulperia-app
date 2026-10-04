import '../business/amount_mode.dart';
import '../money/amount_rules.dart';
import '../money/money.dart';

/// Campo de un producto al que se refiere un problema de validación.
enum ProductField { name, price }

final class ProductIssue {
  const ProductIssue(this.field, this.code);

  final ProductField field;

  /// Código estable, el mismo de la API.
  final String code;
}

sealed class ProductValidationResult {
  const ProductValidationResult();
}

final class ValidProduct extends ProductValidationResult {
  const ValidProduct({required this.name, required this.price});

  /// El nombre, sin espacios exteriores.
  final String name;
  final Money price;
}

final class InvalidProduct extends ProductValidationResult {
  const InvalidProduct(this.issues);

  final List<ProductIssue> issues;
}

/// Valida un producto del catálogo (RF-24): lleva nombre y un precio positivo
/// y, con montos enteros, sin centavos (RF-36). Reporta todos los problemas,
/// el nombre primero.
ProductValidationResult validateProduct({
  required String name,
  required Money price,
  required AmountMode amountMode,
}) {
  final issues = <ProductIssue>[];

  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    issues.add(const ProductIssue(ProductField.name, 'product_name_required'));
  }

  final priceError = amountRuleError(price, amountMode);
  if (priceError != null) {
    issues.add(ProductIssue(ProductField.price, priceError.code));
  }

  return issues.isEmpty
      ? ValidProduct(name: trimmed, price: price)
      : InvalidProduct(issues);
}
