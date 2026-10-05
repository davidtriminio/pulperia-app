import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/ledger_queries.dart';
import '../../domain/avatar/avatar.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';
import '../avatar/avatar_view.dart';
import '../format/date_format.dart';
import '../format/money_format.dart';
import '../format/quantity_format.dart';
import 'client_form_screen.dart';
import 'clients_screen.dart';

/// Saldo e historial de un cliente; null si no existe en el negocio activo.
final clientHistoryProvider = FutureProvider.family<ClientHistory?, String>((
  ref,
  clientId,
) {
  final queries = ref.watch(ledgerQueriesProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return queries.historyOf(businessId, clientId);
});

/// Detalle de un cliente con su saldo y su historial (RF-41, RF-42).
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(clientHistoryProvider(clientId));
    final mode = ref
        .watch(activeBusinessProvider)
        .maybeWhen(
          data: (b) => AmountMode.fromId(b.amountMode),
          orElse: () => AmountMode.twoDecimals,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.clientDetail),
        actions: [
          if (history.asData?.value != null)
            IconButton(
              key: const ValueKey('edit-client'),
              tooltip: Strings.editAction,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ClientFormScreen(
                      existing: history.asData!.value!.client,
                    ),
                  ),
                );
                if (saved == true) {
                  ref.invalidate(clientHistoryProvider(clientId));
                  ref.invalidate(activeClientsProvider);
                }
              },
            ),
        ],
      ),
      body: history.when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => const Center(child: Text(Strings.loadError)),
        data: (data) {
          if (data == null) {
            return const Center(child: Text(Strings.clientNotFound));
          }
          return _Body(history: data, mode: mode);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.history, required this.mode});

  final ClientHistory history;
  final AmountMode mode;

  @override
  Widget build(BuildContext context) {
    final client = history.client;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            AvatarView(
              avatar: Avatar(
                characterId: client.characterId,
                skinId: client.skinId,
                backgroundId: client.backgroundId,
              ),
              size: 72,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: theme.textTheme.titleLarge),
                  if (client.archived)
                    const Chip(
                      label: Text(Strings.archivedBadge),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _BalanceCard(balance: history.balance, mode: mode),
        const SizedBox(height: 8),
        if (client.phone != null)
          _ContactRow(
            rowKey: 'contact-phone',
            icon: Icons.phone_outlined,
            text: client.phone!,
          ),
        if (client.address != null)
          _ContactRow(
            rowKey: 'contact-address',
            icon: Icons.place_outlined,
            text: client.address!,
          ),
        if (client.note != null)
          _ContactRow(
            rowKey: 'contact-note',
            icon: Icons.notes_outlined,
            text: client.note!,
          ),
        const SizedBox(height: 16),
        Text(Strings.historyTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (history.entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(Strings.historyEmpty)),
          )
        else
          for (final entry in history.entries)
            _EntryTile(entry: entry, mode: mode),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.mode});

  final Balance balance;
  final AmountMode mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (text, color) = switch (balance.label) {
      BalanceLabel.debt => (
        '${Strings.balanceDebt} ${formatMoney(balance.debt, mode)}',
        scheme.error,
      ),
      BalanceLabel.credit => (
        '${Strings.balanceCredit} ${formatMoney(balance.credit, mode)}',
        Colors.green.shade800,
      ),
      BalanceLabel.settled => (Strings.balanceSettled, scheme.outline),
    };
    return Card(
      key: const ValueKey('balance'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.rowKey,
    required this.icon,
    required this.text,
  });

  final String rowKey;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey(rowKey),
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.mode});

  final HistoryEntry entry;
  final AmountMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiado = entry.kind == MovementKind.fiado;
    final annulled = entry.isAnnulled;
    final muted = theme.colorScheme.outline;
    final strike = annulled ? TextDecoration.lineThrough : null;

    return Card(
      key: ValueKey('entry-${entry.id}'),
      color: annulled ? theme.colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFiado ? Icons.shopping_bag_outlined : Icons.payments,
                  size: 20,
                  color: annulled
                      ? muted
                      : (isFiado
                            ? theme.colorScheme.error
                            : Colors.green.shade800),
                ),
                const SizedBox(width: 8),
                Text(
                  isFiado ? Strings.entryFiado : Strings.entryPayment,
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: strike,
                  ),
                ),
                if (annulled) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: ValueKey('annulled-${entry.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Strings.annulled,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  formatMoney(entry.amount, mode),
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: strike,
                    color: annulled ? muted : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatDateTime(entry.occurredAt),
              style: theme.textTheme.bodySmall,
            ),
            if (annulled)
              Text(
                '${Strings.annulledOn} ${formatDateTime(entry.annulledAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            for (final item in entry.items) _ItemRow(item: item, mode: mode),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.mode});

  final FiadoItem item;
  final AmountMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description),
                Text(
                  '${formatQuantity(Quantity(item.quantity))} × '
                  '${formatMoney(Money(item.unitPrice), mode)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(formatMoney(Money(item.subtotal), mode)),
        ],
      ),
    );
  }
}
