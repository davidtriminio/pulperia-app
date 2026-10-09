import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/strings.dart';
import '../widgets/confirm_dialog.dart';

/// Cierra la sesión de este teléfono, con confirmación. Si hay cambios sin
/// enviar no se puede: se avisa cuántos son y que hay que sincronizar antes,
/// porque otro usuario los enviaría con su nombre.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final pending = await ref.read(syncServiceProvider).pendingCount();
  if (!context.mounted) {
    return;
  }
  if (pending > 0) {
    await _showBlocked(context, pending);
    return;
  }

  final confirmed = await showConfirmDialog(
    context,
    icon: Icons.logout,
    title: Strings.logoutConfirmTitle,
    body: Strings.logoutConfirmBody,
    confirmLabel: Strings.logout,
    cancelLabel: Strings.cancel,
    confirmKey: const ValueKey('logout-confirm'),
    cancelKey: const ValueKey('logout-cancel'),
  );
  if (!confirmed) {
    return;
  }
  try {
    await ref.read(sessionControllerProvider.notifier).logout();
  } on PendingChangesException catch (e) {
    // Se hizo un cambio mientras se confirmaba.
    if (context.mounted) {
      await _showBlocked(context, e.count);
    }
  }
}

Future<void> _showBlocked(BuildContext context, int count) => showConfirmDialog(
  context,
  icon: Icons.sync_problem_outlined,
  title: Strings.logoutBlockedTitle,
  body: Strings.logoutBlockedBody(count),
  confirmLabel: Strings.understood,
  cancelLabel: null,
  confirmKey: const ValueKey('logout-blocked-ok'),
);
