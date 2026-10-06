import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/business/amount_mode.dart';
import '../../l10n/strings.dart';
import 'client_detail_screen.dart';
import 'client_tile.dart';
import 'clients_screen.dart';

/// Vista de los clientes archivados con su saldo (RF-22). Se abre desde la
/// lista de clientes; tocar uno abre su detalle, desde donde el dueño lo
/// restaura (RF-23).
class ArchivedClientsScreen extends ConsumerWidget {
  const ArchivedClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(archivedClientsProvider);
    final mode = ref
        .watch(activeBusinessProvider)
        .maybeWhen(
          data: (b) => AmountMode.fromId(b.amountMode),
          orElse: () => AmountMode.twoDecimals,
        );

    return Scaffold(
      key: const ValueKey('archived-clients-screen'),
      appBar: AppBar(title: const Text(Strings.archivedClientsTitle)),
      body: clients.when(
        loading: () => const SizedBox.shrink(),
        error: (error, _) => const Center(child: Text(Strings.loadError)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text(Strings.archivedClientsEmpty));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
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
      ),
    );
  }
}
