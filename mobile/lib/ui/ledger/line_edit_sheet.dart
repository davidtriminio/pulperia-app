import 'package:flutter/material.dart';

import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';
import '../catalog/unit_selector.dart';
import '../format/amount_messages.dart';
import '../format/money_format.dart';
import '../format/quantity_format.dart';
import '../format/quantity_messages.dart';
import '../input_limits.dart';
import 'fiado_cart.dart';

/// Abre la hoja para editar una línea del carrito: descripción, cantidad
/// exacta, precio y unidad. Los cambios valen solo para esa línea (RF-30,
/// RF-87): el producto del catálogo no se toca.
Future<void> showLineEditSheet(
  BuildContext context, {
  required FiadoCart cart,
  required CartLine line,
  required AmountMode amountMode,
  required QuantityMode quantityMode,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _LineEditSheet(
        cart: cart,
        line: line,
        amountMode: amountMode,
        quantityMode: quantityMode,
      ),
    ),
  );
}

class _LineEditSheet extends StatefulWidget {
  const _LineEditSheet({
    required this.cart,
    required this.line,
    required this.amountMode,
    required this.quantityMode,
  });

  final FiadoCart cart;
  final CartLine line;
  final AmountMode amountMode;
  final QuantityMode quantityMode;

  @override
  State<_LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends State<_LineEditSheet> {
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _price;
  late SaleUnit _unit;
  String? _quantityError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final line = widget.line;
    _description = TextEditingController(text: line.description);
    _quantity = TextEditingController(text: formatQuantity(line.quantity));
    _price = TextEditingController(
      text: line.unitPrice == null
          ? ''
          : plainAmount(line.unitPrice!, widget.amountMode),
    );
    _unit = line.unit;
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    Quantity? quantity;
    Money? price;
    String? quantityError;
    String? priceError;

    final quantityText = _quantity.text.trim();
    if (quantityText.isEmpty) {
      quantityError = Strings.quantityRequired;
    } else {
      switch (Quantity.parse(quantityText, widget.quantityMode)) {
        case QuantityParsed(quantity: final q):
          quantity = q;
        case QuantityRejected(:final error):
          quantityError = quantityErrorMessage(error);
      }
    }

    final priceText = _price.text.trim();
    if (priceText.isEmpty) {
      priceError = Strings.priceRequired;
    } else {
      switch (Money.parse(priceText, widget.amountMode)) {
        case MoneyParsed(:final money):
          price = money;
        case MoneyRejected(:final error):
          priceError = amountErrorMessage(error);
      }
    }

    setState(() {
      _quantityError = quantityError;
      _priceError = priceError;
    });
    if (quantity == null || price == null) {
      return;
    }

    widget.cart.update(
      widget.line.id,
      description: _description.text.trim(),
      quantity: quantity,
      unitPrice: price,
      unit: _unit,
    );
    Navigator.of(context).pop();
  }

  void _remove() {
    widget.cart.remove(widget.line.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('line-edit-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.editItem,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('edit-description'),
              controller: _description,
              inputFormatters: InputLimits.text(InputLimits.itemDescription),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: Strings.fieldDescription,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('edit-quantity'),
                    controller: _quantity,
                    inputFormatters: InputLimits.text(InputLimits.quantity),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: Strings.fieldQuantity,
                      prefixIcon: const Icon(Icons.numbers),
                      suffixText: _unit.abbreviation,
                      errorText: _quantityError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('edit-price'),
                    controller: _price,
                    inputFormatters: InputLimits.text(InputLimits.amount),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: Strings.fieldUnitPrice,
                      prefixIcon: const Icon(Icons.payments_outlined),
                      prefixText: 'L ',
                      errorText: _priceError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            UnitSelector(
              selected: _unit,
              onChanged: (unit) => setState(() => _unit = unit),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('line-save'),
              onPressed: _save,
              child: const Text(Strings.save),
            ),
            TextButton.icon(
              key: const ValueKey('line-remove'),
              onPressed: _remove,
              icon: const Icon(Icons.delete_outline),
              label: const Text(Strings.removeItem),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
