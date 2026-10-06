import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/payment_repository.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/money/money.dart';
import '../../l10n/strings.dart';
import '../clients/client_detail_screen.dart';
import '../clients/clients_screen.dart';
import '../input_limits.dart';
import '../format/amount_messages.dart';
import '../format/money_format.dart';
import '../theme.dart';
import '../widgets/quick_amounts.dart';

/// Registrar un abono general a un cliente (RF-37): se resta de su saldo sin
/// asociarlo a ningún ítem. Un abono mayor que la deuda se acepta y deja saldo
/// a favor (RF-39); un cliente archivado también puede abonar (RF-75).
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final TextEditingController _amount = TextEditingController();
  String? _error;
  bool _saving = false;

  AmountMode get _mode => ref
      .read(activeBusinessProvider)
      .maybeWhen(
        data: (b) => AmountMode.fromId(b.amountMode),
        orElse: () => AmountMode.twoDecimals,
      );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// El texto del campo como monto, o null si aún no es un monto válido.
  Money? get _typedAmount {
    final parsed = Money.parse(_amount.text.trim(), _mode);
    return parsed is MoneyParsed ? parsed.money : null;
  }

  /// Rellena el campo con un monto rápido; el teclado sigue disponible.
  void _fill(Money amount) {
    setState(() {
      _error = null;
      _amount.text = plainAmount(amount, _mode);
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final text = _amount.text.trim();
    Money? amount;
    String? error;
    if (text.isEmpty) {
      error = Strings.totalRequired;
    } else {
      switch (Money.parse(text, _mode)) {
        case MoneyParsed(:final money):
          amount = money;
        case MoneyRejected(error: final e):
          error = amountErrorMessage(e);
      }
    }
    setState(() => _error = error);
    if (amount == null) {
      return;
    }

    setState(() => _saving = true);
    final user = ref.read(activeUserProvider);
    final result = await ref
        .read(paymentRepositoryProvider)
        .create(
          businessId: ref.read(activeBusinessIdProvider),
          userId: user.id,
          role: user.role,
          clientId: widget.clientId,
          amount: amount,
        );
    if (!mounted) {
      return;
    }

    switch (result) {
      case PaymentSaved():
        ref.invalidate(clientHistoryProvider(widget.clientId));
        ref.invalidate(activeClientsProvider);
        Navigator.of(context).pop(true);
      case PaymentRejected(error: final e):
        setState(() {
          _saving = false;
          _error = amountErrorMessage(e);
        });
      case PaymentClientNotFound():
        setState(() {
          _saving = false;
          _error = Strings.clientNotFound;
        });
      case PaymentForbidden():
        setState(() {
          _saving = false;
          _error = Strings.saveError;
        });
    }
  }

  String _describe(Balance balance, AmountMode mode) => switch (balance.label) {
    BalanceLabel.debt =>
      '${Strings.balanceDebt} ${formatMoney(balance.debt, mode)}',
    BalanceLabel.credit =>
      '${Strings.balanceCredit} ${formatMoney(balance.credit, mode)}',
    BalanceLabel.settled => Strings.balanceSettled,
  };

  @override
  Widget build(BuildContext context) {
    ref.watch(activeBusinessProvider);
    final mode = _mode;
    final theme = Theme.of(context);
    final current = ref
        .watch(clientHistoryProvider(widget.clientId))
        .asData
        ?.value
        ?.balance;
    final typed = _typedAmount;
    // Si el monto es válido se muestra cómo quedaría el saldo; un abono mayor
    // que la deuda deja la diferencia a favor del cliente (RF-39).
    final after = (current != null && typed != null)
        ? Balance(current.amount - typed)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.newPayment)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _BalanceRow(
                    label: Strings.currentBalance,
                    valueKey: 'payment-current',
                    value: current == null ? '' : _describe(current, mode),
                  ),
                  if (after != null) ...[
                    const Divider(height: 24),
                    _BalanceRow(
                      label: Strings.balanceAfter,
                      valueKey: 'payment-after',
                      value: _describe(after, mode),
                      color: switch (after.label) {
                        BalanceLabel.debt => AppColors.debt,
                        BalanceLabel.credit => AppColors.credit,
                        BalanceLabel.settled => AppColors.navy,
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('payment-input'),
            inputFormatters: InputLimits.text(InputLimits.amount),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.headlineSmall,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: Strings.fieldPaymentAmount,
              prefixText: 'L ',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (current != null && current.amount.isPositive)
                ActionChip(
                  key: const ValueKey('pay-full'),
                  avatar: const Icon(Icons.done_all, size: 18),
                  label: const Text(Strings.payFull),
                  labelStyle: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: () => _fill(current.debt),
                ),
              for (final lempiras in quickAmountLempiras)
                ActionChip(
                  key: ValueKey('quick-$lempiras'),
                  label: Text(formatMoney(Money(lempiras * 100), mode)),
                  labelStyle: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: () => _fill(Money(lempiras * 100)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('payment-save'),
            onPressed: _saving ? null : _save,
            child: const Text(Strings.newPayment),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.valueKey,
    required this.value,
    this.color,
  });

  final String label;
  final String valueKey;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          key: ValueKey(valueKey),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
