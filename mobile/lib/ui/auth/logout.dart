import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/strings.dart';
import '../widgets/confirm_dialog.dart';

/// Pide confirmación y cierra la sesión de este teléfono. Lo que no se ha
/// enviado al servidor se conserva en el teléfono.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
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
  if (confirmed) {
    await ref.read(sessionControllerProvider.notifier).logout();
  }
}
