import 'package:flutter/material.dart';

import '../../data/repositories/client_repository.dart';
import '../../domain/avatar/avatar.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/ledger/balance.dart';
import '../../l10n/strings.dart';
import '../avatar/avatar_view.dart';
import '../format/money_format.dart';
import '../theme.dart';

/// Una tarjeta de la lista de clientes: avatar y nombre a la izquierda, saldo
/// a la derecha. La deuda y el saldo a favor se distinguen por la etiqueta y
/// por el color (RF-42).
class ClientTile extends StatelessWidget {
  const ClientTile({
    super.key,
    required this.item,
    required this.amountMode,
    this.onTap,
  });

  final ClientWithBalance item;
  final AmountMode amountMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final client = item.client;
    final theme = Theme.of(context);
    final balance = item.balance;

    final (label, amount, color) = switch (balance.label) {
      BalanceLabel.debt => (
        Strings.balanceDebt,
        formatMoney(balance.debt, amountMode),
        AppColors.debt,
      ),
      BalanceLabel.credit => (
        Strings.balanceCredit,
        formatMoney(balance.credit, amountMode),
        AppColors.credit,
      ),
      BalanceLabel.settled => (
        Strings.balanceSettled,
        null,
        theme.colorScheme.outline,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AvatarView(
                  avatar: Avatar(
                    characterId: client.characterId,
                    skinId: client.skinId,
                    backgroundId: client.backgroundId,
                  ),
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      label,
                      key: ValueKey('balance-label-${client.id}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (amount != null)
                      Text(
                        amount,
                        key: ValueKey('balance-amount-${client.id}'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
