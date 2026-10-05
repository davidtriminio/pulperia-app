import '../business/amount_mode.dart';
import '../business/quantity_mode.dart';
import '../catalog/sale_unit.dart';
import '../money/amount_rules.dart';
import '../money/money.dart';
import '../quantity/quantity.dart';
import 'subtotal.dart';

/// Un ítem de un fiado tal como lo ingresa el usuario.
final class FiadoItemDraft {
  const FiadoItemDraft({
    required this.description,
    this.productId,
    required this.quantity,
    required this.unitPrice,
    this.unit = SaleUnit.defaultUnit,
  });

  final String description;

  /// Producto del catálogo del que se copió el ítem; null si es un ítem libre.
  final String? productId;
  final Quantity quantity;
  final Money unitPrice;

  /// Unidad de venta del ítem (RF-87): la del producto o la que se le cambió;
  /// `unidad` si es libre.
  final SaleUnit unit;
}

/// Lo que el usuario quiere registrar: un fiado con detalle de ítems o un
/// fiado solo con un monto total (RF-28, RF-29).
sealed class FiadoDraft {
  const FiadoDraft();
}

final class FiadoWithItems extends FiadoDraft {
  const FiadoWithItems(this.items);

  final List<FiadoItemDraft> items;
}

final class FiadoTotalOnly extends FiadoDraft {
  /// [total] es null cuando el usuario no ha indicado ningún monto.
  const FiadoTotalOnly(this.total);

  final Money? total;
}

/// Campo de un fiado al que se refiere un problema de validación.
enum FiadoField { fiado, total, quantity, unitPrice, subtotal }

final class FiadoIssue {
  const FiadoIssue({this.itemIndex, required this.field, required this.code});

  /// Posición del ítem con el problema; null si no es de un ítem.
  final int? itemIndex;
  final FiadoField field;

  /// Código estable, el mismo de los vectores compartidos y de la API.
  final String code;
}

final class ValidFiadoItem {
  const ValidFiadoItem({
    required this.description,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    required this.subtotal,
  });

  final String description;
  final String? productId;
  final Quantity quantity;
  final Money unitPrice;
  final SaleUnit unit;
  final Money subtotal;
}

sealed class FiadoValidationResult {
  const FiadoValidationResult();
}

/// Fiado válido. Con ítems, [total] es la suma de sus subtotales ya
/// redondeados; sin ítems, es el monto indicado.
final class ValidFiado extends FiadoValidationResult {
  const ValidFiado({required this.total, required this.items});

  final Money total;
  final List<ValidFiadoItem> items;
}

final class InvalidFiado extends FiadoValidationResult {
  const InvalidFiado(this.issues);

  final List<FiadoIssue> issues;
}

const String _emptyFiado = 'fiado_empty';

/// Valida un fiado según RF-28, RF-29, RF-32, RF-33, RF-34, RF-35, RF-36 y
/// RF-83 y calcula los subtotales. Reporta todos los problemas, ítem por
/// ítem y campo por campo.
FiadoValidationResult validateFiado(
  FiadoDraft draft, {
  required AmountMode amountMode,
  required QuantityMode quantityMode,
}) {
  return switch (draft) {
    FiadoTotalOnly(:final total) => _validateTotalOnly(total, amountMode),
    FiadoWithItems(:final items) => _validateWithItems(
      items,
      amountMode,
      quantityMode,
    ),
  };
}

FiadoValidationResult _validateTotalOnly(Money? total, AmountMode amountMode) {
  if (total == null) {
    return const InvalidFiado([
      FiadoIssue(field: FiadoField.fiado, code: _emptyFiado),
    ]);
  }
  final error = amountRuleError(total, amountMode);
  if (error != null) {
    return InvalidFiado([
      FiadoIssue(field: FiadoField.total, code: error.code),
    ]);
  }
  return ValidFiado(total: total, items: const []);
}

FiadoValidationResult _validateWithItems(
  List<FiadoItemDraft> items,
  AmountMode amountMode,
  QuantityMode quantityMode,
) {
  if (items.isEmpty) {
    return const InvalidFiado([
      FiadoIssue(field: FiadoField.fiado, code: _emptyFiado),
    ]);
  }

  final issues = <FiadoIssue>[];
  final valid = <ValidFiadoItem>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final quantityError = _quantityError(item.quantity, quantityMode);
    final priceError = amountRuleError(item.unitPrice, amountMode);
    if (quantityError != null) {
      issues.add(
        FiadoIssue(
          itemIndex: i,
          field: FiadoField.quantity,
          code: quantityError.code,
        ),
      );
    }
    if (priceError != null) {
      issues.add(
        FiadoIssue(
          itemIndex: i,
          field: FiadoField.unitPrice,
          code: priceError.code,
        ),
      );
    }
    if (quantityError != null || priceError != null) continue;

    final subtotal = switch (amountMode) {
      AmountMode.integer => wholeLempiraSubtotal(
        quantity: item.quantity,
        unitPrice: item.unitPrice,
      ),
      AmountMode.twoDecimals => centavoSubtotal(
        quantity: item.quantity,
        unitPrice: item.unitPrice,
      ),
    };
    if (!subtotal.isPositive) {
      issues.add(
        FiadoIssue(
          itemIndex: i,
          field: FiadoField.subtotal,
          code: AmountError.notPositive.code,
        ),
      );
      continue;
    }
    valid.add(
      ValidFiadoItem(
        description: item.description,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        unit: item.unit,
        subtotal: subtotal,
      ),
    );
  }

  if (issues.isNotEmpty) return InvalidFiado(issues);
  return ValidFiado(
    total: valid.fold(Money.zero, (sum, item) => sum + item.subtotal),
    items: valid,
  );
}

QuantityError? _quantityError(Quantity quantity, QuantityMode mode) {
  if (quantity.milli <= 0) return QuantityError.notPositive;
  if (mode == QuantityMode.integer && !quantity.isWhole) {
    return QuantityError.notWhole;
  }
  return null;
}
