import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/sync_controller.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

/// Avisa que hay cambios sin sincronizar (RF-57) y, si falta iniciar sesión
/// para poder hacerlo (D-10), lo dice. Un toque sincroniza. No se ve cuando no
/// hay nada que enviar.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingChangesProvider).value ?? 0;
    final status = ref.watch(syncControllerProvider);
    if (pending == 0 && !status.needsLogin) {
      return const SizedBox.shrink();
    }
    final label = status.needsLogin
        ? Strings.syncNeedsLogin
        : Strings.pendingChanges(pending);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        key: const ValueKey('sync-indicator'),
        avatar: status.running
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                status.needsLogin
                    ? Icons.lock_outline
                    : Icons.cloud_upload_outlined,
                size: 18,
                color: AppColors.navy,
              ),
        label: Text(label),
        backgroundColor: AppColors.turquoise.withValues(alpha: 0.2),
        side: BorderSide.none,
        onPressed: status.running
            ? null
            : () => ref
                  .read(syncControllerProvider.notifier)
                  .request(SyncTrigger.manual),
      ),
    );
  }
}
