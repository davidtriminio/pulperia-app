import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/business/amount_mode.dart';
import '../../l10n/strings.dart';
import 'client_tile.dart';

/// Clientes no archivados del negocio activo con su saldo.
final activeClientsProvider = FutureProvider<List<ClientWithBalance>>((ref) {
  final repository = ref.watch(clientRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repository.activeClients(businessId);
});

/// Sección de clientes (RF-20, RF-42).
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(activeClientsProvider);
    final mode = ref
        .watch(activeBusinessProvider)
        .maybeWhen(
          data: (b) => AmountMode.fromId(b.amountMode),
          orElse: () => AmountMode.twoDecimals,
        );

    return clients.when(
      loading: () => const SizedBox.shrink(key: ValueKey('section-clients')),
      error: (error, _) => Center(
        key: const ValueKey('section-clients'),
        child: Text(Strings.loadError),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            key: ValueKey('section-clients'),
            child: Text(Strings.clientsEmpty),
          );
        }
        return ListView.builder(
          key: const ValueKey('section-clients'),
          itemCount: items.length,
          itemBuilder: (context, i) =>
              ClientTile(item: items[i], amountMode: mode),
        );
      },
    );
  }
}
