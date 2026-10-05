import 'package:flutter/material.dart';

import '../../data/repositories/client_repository.dart';
import '../../domain/avatar/avatar.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/ledger/balance.dart';
import '../../l10n/strings.dart';
import '../avatar/avatar_view.dart';
import '../format/money_format.dart';
import '../theme.dart';

/// Una fila de la lista de clientes: avatar, nombre y saldo. La deuda y el
/// saldo a favor se distinguen por la etiqueta y por el color (RF-42).
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
    final scheme = Theme.of(context).colorScheme;
    final balance = item.balance;

    final (text, color) = switch (balance.label) {
      BalanceLabel.debt => (
        '${Strings.balanceDebt} ${formatMoney(balance.debt, amountMode)}',
        scheme.error,
      ),
      BalanceLabel.credit => (
        '${Strings.balanceCredit} ${formatMoney(balance.credit, amountMode)}',
        AppColors.credit,
      ),
      BalanceLabel.settled => (Strings.balanceSettled, scheme.outline),
    };

    return ListTile(
      leading: AvatarView(
        avatar: Avatar(
          characterId: client.characterId,
          skinId: client.skinId,
          backgroundId: client.backgroundId,
        ),
        size: 44,
      ),
      title: Text(client.name),
      subtitle: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
