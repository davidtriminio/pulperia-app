import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../data/local/app_database.dart';
import '../../domain/avatar/avatar.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/summary/business_summary.dart';
import '../../l10n/strings.dart';
import '../avatar/avatar_view.dart';
import '../clients/client_detail_screen.dart';
import '../clients/clients_screen.dart';
import '../format/money_format.dart';
import '../theme.dart';
import '../widgets/amount_box.dart';

/// Cuántos deudores se muestran de entrada; la lista completa la calcula el
/// dominio y la interfaz decide el tope.
const summaryDebtorLimit = 10;

/// El resumen y los clientes activos por id, para mostrar nombre y avatar.
typedef SummaryView = ({BusinessSummary summary, Map<String, Client> clients});

/// Resumen del negocio calculado con los datos locales, incluidos los cambios
/// aún no sincronizados (RF-66). Depende de la lista de clientes: cada vez que
/// un fiado, abono, anulación o archivado la invalida, se recalcula.
final businessSummaryProvider = FutureProvider<SummaryView>((ref) async {
  ref.watch(localDataRevisionProvider);
  final clients = await ref.watch(activeClientsProvider.future);
  final businessId = ref.watch(activeBusinessIdProvider);
  final summary = await ref.watch(summaryQueriesProvider).summaryOf(businessId);
  return (
    summary: summary,
    clients: {for (final c in clients) c.client.id: c.client},
  );
});

/// Resumen del negocio (RF-63 a RF-66): deuda total, saldo a favor total y
/// mayores deudores, sin clientes archivados.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(businessSummaryProvider);
    final mode = ref
        .watch(activeBusinessProvider)
        .maybeWhen(
          data: (b) => AmountMode.fromId(b.amountMode),
          orElse: () => AmountMode.twoDecimals,
        );

    return view.when(
      loading: () => const SizedBox.shrink(key: ValueKey('section-summary')),
      error: (error, _) => const Center(
        key: ValueKey('section-summary'),
        child: Text(Strings.loadError),
      ),
      data: (data) => _Content(data: data, mode: mode),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.mode});

  final SummaryView data;
  final AmountMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = data.summary;
    final debtors = [
      for (final d in summary.debtors.take(summaryDebtorLimit))
        if (data.clients.containsKey(d.clientId)) d,
    ];

    return ListView(
      key: const ValueKey('section-summary'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.navyDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Strings.summaryDebtTotal,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(summary.debtTotal, mode),
                  key: const ValueKey('summary-debt-total'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: _cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.credit.withValues(alpha: 0.14),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: AppColors.credit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Strings.summaryCreditTotal,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AmountBox(
                  child: Text(
                    formatMoney(summary.creditTotal, mode),
                    key: const ValueKey('summary-credit-total'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.credit,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            Strings.summaryTopDebtors,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (debtors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(Strings.summaryNoDebtors)),
          )
        else
          for (var i = 0; i < debtors.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DebtorTile(
                rank: i + 1,
                client: data.clients[debtors[i].clientId]!,
                debt: formatMoney(debtors[i].debt, mode),
              ),
            ),
      ],
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0xFFDCE6EB)),
  boxShadow: [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.07),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ],
);

/// Un deudor de la lista: posición, avatar, nombre y lo que debe.
class _DebtorTile extends StatelessWidget {
  const _DebtorTile({
    required this.rank,
    required this.client,
    required this.debt,
  });

  final int rank;
  final Client client;
  final String debt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: ValueKey('debtor-${client.id}'),
      decoration: _cardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ClientDetailScreen(clientId: client.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AvatarView(
                  avatar: Avatar(
                    characterId: client.characterId,
                    skinId: client.skinId,
                    backgroundId: client.backgroundId,
                  ),
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AmountBox(
                  child: Text(
                    debt,
                    key: ValueKey('debtor-amount-${client.id}'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.debt,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
