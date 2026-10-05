import 'package:flutter/material.dart';

import '../../domain/catalog/sale_unit.dart';
import '../../l10n/strings.dart';

/// "libra" → "Libra".
String capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Elegir la unidad de venta de la lista fija (RF-86): una fila de chips, de
/// un toque, pensada para el mostrador.
class UnitSelector extends StatelessWidget {
  const UnitSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SaleUnit selected;
  final ValueChanged<SaleUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.fieldUnit,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final unit in SaleUnit.values)
              ChoiceChip(
                key: ValueKey('unit-${unit.id}'),
                label: Text(capitalize(unit.singular)),
                selected: unit == selected,
                onSelected: (_) => onChanged(unit),
              ),
          ],
        ),
      ],
    );
  }
}
