import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/business/amount_mode.dart';
import '../../l10n/strings.dart';
import 'archived_clients_screen.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';
import 'client_tile.dart';

/// Clientes no archivados del negocio activo con su saldo.
final activeClientsProvider = FutureProvider<List<ClientWithBalance>>((ref) {
  final repository = ref.watch(clientRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repository.activeClients(businessId);
});

/// Clientes archivados del negocio activo con su saldo (RF-22). Se recalcula
/// cada vez que se abre la vista de archivados.
final archivedClientsProvider =
    FutureProvider.autoDispose<List<ClientWithBalance>>((ref) {
      final repository = ref.watch(clientRepositoryProvider);
      final businessId = ref.watch(activeBusinessIdProvider);
      return repository.archivedClients(businessId);
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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-client'),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text(Strings.newClient),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ClientFormScreen()),
        ),
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextButton.icon(
                key: const ValueKey('open-archived'),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text(Strings.archivedClientsAction),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ArchivedClientsScreen(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _list(context, clients, mode)),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    AsyncValue<List<ClientWithBalance>> clients,
    AmountMode mode,
  ) {
    return clients.when(
      loading: () => const SizedBox.shrink(key: ValueKey('section-clients')),
      error: (error, _) => const Center(
        key: ValueKey('section-clients'),
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
          padding: const EdgeInsets.only(top: 4, bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, i) => ClientTile(
            item: items[i],
            amountMode: mode,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ClientDetailScreen(clientId: items[i].client.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
