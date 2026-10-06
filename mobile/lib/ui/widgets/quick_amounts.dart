import 'package:flutter/material.dart';

import '../../domain/business/amount_mode.dart';
import '../../domain/money/money.dart';
import '../format/money_format.dart';
import '../theme.dart';

/// Montos rápidos en lempiras para los casos más comunes. Solo rellenan un
/// campo: el teclado manual siempre sigue disponible.
const List<int> quickAmountLempiras = [50, 100, 200, 500];

/// Una fila de botones con los montos rápidos. Al tocar uno entrega ese monto
/// en la unidad menor.
class QuickAmounts extends StatelessWidget {
  const QuickAmounts({super.key, required this.mode, required this.onSelected});

  final AmountMode mode;
  final ValueChanged<Money> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final lempiras in quickAmountLempiras)
          ActionChip(
            key: ValueKey('quick-$lempiras'),
            label: Text(formatMoney(Money(lempiras * 100), mode)),
            labelStyle: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
            onPressed: () => onSelected(Money(lempiras * 100)),
          ),
      ],
    );
  }
}
