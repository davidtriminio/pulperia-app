import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/annul_result.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/ledger_queries.dart';
import '../../domain/avatar/avatar.dart';
import '../../domain/access/access.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/ledger/balance.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';
import '../avatar/avatar_view.dart';
import '../format/date_format.dart';
import '../format/money_format.dart';
import '../format/quantity_format.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../ledger/fiado_form_screen.dart';
import '../ledger/payment_form_screen.dart';
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

    // Solo el dueño anula (RF-45): al empleado no se le ofrece la acción.
    final canAnnul = can(
      ref.watch(activeUserProvider).role,
      Permission.annulMovement,
    );

    final role = ref.watch(activeUserProvider).role;
    final canArchive = can(role, Permission.archiveClient);

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
          // Solo el dueño archiva y restaura (RF-21, RF-23).
          if (history.asData?.value != null && canArchive)
            if (history.asData!.value!.client.archived)
              IconButton(
                key: const ValueKey('restore-client'),
                tooltip: Strings.restoreClientTooltip,
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: () => _setArchived(context, ref, clientId, false),
              )
            else
              IconButton(
                key: const ValueKey('archive-client'),
                tooltip: Strings.archiveClientTooltip,
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => _setArchived(context, ref, clientId, true),
              ),
        ],
      ),
      bottomNavigationBar: history.asData?.value == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('register-fiado'),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text(Strings.registerFiado),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FiadoFormScreen(clientId: clientId),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('register-payment'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.turquoise,
                          foregroundColor: AppColors.ink,
                        ),
                        icon: const Icon(Icons.payments),
                        label: const Text(Strings.registerPayment),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PaymentFormScreen(clientId: clientId),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: history.when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => const Center(child: Text(Strings.loadError)),
        data: (data) {
          if (data == null) {
            return const Center(child: Text(Strings.clientNotFound));
          }
          return _Body(
            history: data,
            mode: mode,
            onAnnul: canAnnul
                ? (entry) => _annul(context, ref, clientId, entry)
                : null,
          );
        },
      ),
    );
  }
}

/// Archiva (con confirmación, RF-20) o restaura (RF-23) al cliente. El
/// repositorio vuelve a comprobar que sea el dueño (RF-21).
Future<void> _setArchived(
  BuildContext context,
  WidgetRef ref,
  String clientId,
  bool archive,
) async {
  if (archive) {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.archive_outlined,
      title: Strings.archiveClientTitle,
      body: Strings.archiveClientBody,
      confirmLabel: Strings.archiveClientConfirm,
      cancelLabel: Strings.cancel,
      confirmKey: const ValueKey('archive-confirm'),
      cancelKey: const ValueKey('archive-cancel'),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
  }

  final user = ref.read(activeUserProvider);
  final repository = ref.read(clientRepositoryProvider);
  final businessId = ref.read(activeBusinessIdProvider);
  final result = archive
      ? await repository.archive(
          businessId: businessId,
          userId: user.id,
          role: user.role,
          clientId: clientId,
        )
      : await repository.restore(
          businessId: businessId,
          userId: user.id,
          role: user.role,
          clientId: clientId,
        );
  if (!context.mounted) {
    return;
  }

  ref.invalidate(clientHistoryProvider(clientId));
  ref.invalidate(activeClientsProvider);
  ref.invalidate(archivedClientsProvider);
  final message = switch (result) {
    ClientSaved() =>
      archive ? Strings.clientArchivedDone : Strings.clientRestoredDone,
    _ => Strings.saveError,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Pide confirmación y anula el movimiento (RF-43). Solo llega aquí el dueño,
/// pero el repositorio lo comprueba también (RF-45).
Future<void> _annul(
  BuildContext context,
  WidgetRef ref,
  String clientId,
  HistoryEntry entry,
) async {
  final isFiado = entry.kind == MovementKind.fiado;
  final confirmed = await showConfirmDialog(
    context,
    icon: Icons.block,
    title: isFiado ? Strings.annulFiadoTitle : Strings.annulPaymentTitle,
    body: isFiado ? Strings.annulFiadoBody : Strings.annulPaymentBody,
    confirmLabel: Strings.annulConfirm,
    cancelLabel: Strings.annulKeep,
    confirmKey: const ValueKey('annul-confirm'),
    cancelKey: const ValueKey('annul-cancel'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  final user = ref.read(activeUserProvider);
  final businessId = ref.read(activeBusinessIdProvider);
  final AnnulResult<Object> result = isFiado
      ? await ref
            .read(fiadoRepositoryProvider)
            .annul(
              businessId: businessId,
              userId: user.id,
              role: user.role,
              fiadoId: entry.id,
            )
      : await ref
            .read(paymentRepositoryProvider)
            .annul(
              businessId: businessId,
              userId: user.id,
              role: user.role,
              paymentId: entry.id,
            );
  if (!context.mounted) {
    return;
  }

  ref.invalidate(clientHistoryProvider(clientId));
  ref.invalidate(activeClientsProvider);
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case Annulled():
      messenger.showSnackBar(const SnackBar(content: Text(Strings.annulDone)));
    case AnnulNotFound() || AnnulForbidden():
      messenger.showSnackBar(const SnackBar(content: Text(Strings.saveError)));
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.history, required this.mode, this.onAnnul});

  final ClientHistory history;
  final AmountMode mode;

  /// Null si el usuario no puede anular.
  final ValueChanged<HistoryEntry>? onAnnul;

  @override
  Widget build(BuildContext context) {
    final client = history.client;
    final theme = Theme.of(context);
    final contact = [
      if (client.phone != null)
        ('contact-phone', Icons.phone_outlined, client.phone!),
      if (client.address != null)
        ('contact-address', Icons.place_outlined, client.address!),
      if (client.note != null)
        ('contact-note', Icons.notes_outlined, client.note!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _Header(history: history, mode: mode),
        if (contact.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final (key, icon, text) in contact)
                    _ContactRow(rowKey: key, icon: icon, text: text),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            Strings.historyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (history.entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(Strings.historyEmpty)),
          )
        else
          for (final entry in history.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EntryTile(
                entry: entry,
                mode: mode,
                onAnnul: onAnnul == null || entry.isAnnulled
                    ? null
                    : () => onAnnul!(entry),
              ),
            ),
      ],
    );
  }
}

/// Tarjeta azul con el cliente y su saldo destacado (RF-42).
class _Header extends StatelessWidget {
  const _Header({required this.history, required this.mode});

  final ClientHistory history;
  final AmountMode mode;

  @override
  Widget build(BuildContext context) {
    final client = history.client;
    final balance = history.balance;
    final theme = Theme.of(context);

    final (label, amount, chipColor) = switch (balance.label) {
      BalanceLabel.debt => (
        Strings.balanceDebt,
        formatMoney(balance.debt, mode),
        const Color(0xFFFFB4B4),
      ),
      BalanceLabel.credit => (
        Strings.balanceCredit,
        formatMoney(balance.credit, mode),
        AppColors.turquoise,
      ),
      BalanceLabel.settled => (
        Strings.balanceSettled,
        formatMoney(Money.zero, mode),
        Colors.white24,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarView(
                avatar: Avatar(
                  characterId: client.characterId,
                  skinId: client.skinId,
                  backgroundId: client.backgroundId,
                ),
                size: 64,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (client.archived)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          Strings.archivedBadge,
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            key: const ValueKey('balance-chip'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              key: const ValueKey('balance-label'),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            key: const ValueKey('balance-amount'),
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.navy),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// Un movimiento del historial: ícono redondo, tipo y fecha a la izquierda,
/// monto a la derecha. Un movimiento anulado se ve atenuado y marcado.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.mode, this.onAnnul});

  final HistoryEntry entry;
  final AmountMode mode;

  /// Null si no se puede anular (empleado o ya anulado).
  final VoidCallback? onAnnul;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFiado = entry.kind == MovementKind.fiado;
    final annulled = entry.isAnnulled;
    final muted = theme.colorScheme.outline;
    final strike = annulled ? TextDecoration.lineThrough : null;
    final accent = annulled
        ? muted
        : (isFiado ? AppColors.debt : AppColors.credit);

    return Card(
      key: ValueKey('entry-${entry.id}'),
      color: annulled ? const Color(0xFFE9EEF1) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: accent.withValues(alpha: 0.14),
                  child: Icon(
                    isFiado ? Icons.shopping_bag_outlined : Icons.payments,
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            isFiado ? Strings.entryFiado : Strings.entryPayment,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: strike,
                            ),
                          ),
                          if (annulled)
                            Container(
                              key: ValueKey('annulled-${entry.id}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(8),
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
                      ),
                      Text(
                        formatDateTime(entry.occurredAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      if (annulled)
                        Text(
                          '${Strings.annulledOn} '
                          '${formatDateTime(entry.annulledAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.debt,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(entry.amount, mode),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    decoration: strike,
                    color: annulled ? muted : AppColors.ink,
                  ),
                ),
              ],
            ),
            for (final item in entry.items) _ItemRow(item: item, mode: mode),
            if (onAnnul != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: ValueKey('annul-${entry.id}'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.debt),
                  onPressed: onAnnul,
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text(Strings.annulAction),
                ),
              ),
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
                  '${formatQuantity(Quantity(item.quantity))} '
                  '${SaleUnit.fromId(item.unit).nameFor(Quantity(item.quantity))} × '
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
