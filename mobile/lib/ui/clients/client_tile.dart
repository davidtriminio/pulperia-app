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
/// a la derecha en una píldora tintada. La deuda y el saldo a favor se
/// distinguen por la etiqueta y por el color (RF-42). Un cliente archivado se
/// ve atenuado y con su marca (RF-22). Todas las tarjetas tienen la misma
/// altura mínima, con la misma sombra suave que las de producto.
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
    final archived = client.archived;
    final radius = BorderRadius.circular(20);

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        key: ValueKey('client-tile-${client.id}'),
        decoration: BoxDecoration(
          color: archived ? const Color(0xFFEEF3F6) : Colors.white,
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFDCE6EB)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: archived ? 0.03 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 92),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Opacity(
                      opacity: archived ? 0.6 : 1,
                      child: AvatarView(
                        avatar: Avatar(
                          characterId: client.characterId,
                          skinId: client.skinId,
                          backgroundId: client.backgroundId,
                        ),
                        size: 56,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            client.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (archived)
                            Container(
                              key: ValueKey('archived-badge-${client.id}'),
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                Strings.archivedBadge,
                                style: TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            key: ValueKey('balance-chip-${client.id}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              label,
                              key: ValueKey('balance-label-${client.id}'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (amount != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  amount,
                                  key: ValueKey('balance-amount-${client.id}'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
