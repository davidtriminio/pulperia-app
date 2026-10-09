import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../format/date_format.dart';
import '../theme.dart';

/// Cambios que el servidor no aplicó (RF-55, RF-56): qué se intentó, cuándo y
/// por qué, con la opción de descartarlos. Los rechazos no se reenvían solos.
class RejectedChangesScreen extends ConsumerWidget {
  const RejectedChangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejected = ref.watch(rejectedChangesProvider).value ?? const [];
    return Scaffold(
      key: const ValueKey('rejected-screen'),
      appBar: AppBar(title: const Text(Strings.rejectedTitle)),
      body: rejected.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  Strings.rejectedEmpty,
                  key: ValueKey('rejected-empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    Strings.rejectedIntro,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                for (final op in rejected)
                  Card(
                    key: ValueKey('rejected-${op.opId}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            operationLabel(op.type),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatDateTime(op.createdAt.toLocal()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (op.errorCode == null
                                    ? null
                                    : errorMessageForCode(op.errorCode!)) ??
                                Strings.errorUnexpected,
                            key: ValueKey('rejected-reason-${op.opId}'),
                            style: const TextStyle(
                              color: AppColors.debtDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: ValueKey('rejected-discard-${op.opId}'),
                              onPressed: () => ref
                                  .read(syncServiceProvider)
                                  .discardRejected(op.opId),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text(Strings.rejectedDiscard),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Qué intentaba hacer una operación de la cola, en español.
String operationLabel(String type) => switch (type) {
  'client.create' => 'Crear cliente',
  'client.update' => 'Editar cliente',
  'client.archive' => 'Archivar cliente',
  'client.restore' => 'Restaurar cliente',
  'product.create' => 'Crear producto',
  'product.update' => 'Editar producto',
  'product.archive' => 'Archivar producto',
  'fiado.create' => 'Registrar fiado',
  'payment.create' => 'Registrar abono',
  'fiado.annul' => 'Anular fiado',
  'payment.annul' => 'Anular abono',
  _ => 'Cambio',
};
