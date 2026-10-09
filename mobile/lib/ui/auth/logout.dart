import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/error_banner.dart';

/// Cierra la sesión de este teléfono, con confirmación. Si hay cambios sin
/// enviar no se puede: se avisa cuántos son y se ofrece sincronizar ahí mismo,
/// porque otro usuario los enviaría con su nombre. Si todo se envía, sigue la
/// confirmación de siempre.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final pending = await ref.read(syncServiceProvider).pendingCount();
  if (!context.mounted) {
    return;
  }
  if (pending > 0) {
    final synced = await showDialog<bool>(
      context: context,
      builder: (_) => _BlockedLogoutDialog(count: pending),
    );
    if (synced != true || !context.mounted) {
      return;
    }
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
      await showDialog<bool>(
        context: context,
        builder: (_) => _BlockedLogoutDialog(count: e.count),
      );
    }
  }
}

/// El aviso de «hay cambios sin enviar»: cuántos son, un botón para
/// sincronizar y, si no se pudo, por qué. Se cierra con `true` cuando la cola
/// quedó vacía.
class _BlockedLogoutDialog extends ConsumerStatefulWidget {
  const _BlockedLogoutDialog({required this.count});

  final int count;

  @override
  ConsumerState<_BlockedLogoutDialog> createState() =>
      _BlockedLogoutDialogState();
}

class _BlockedLogoutDialogState extends ConsumerState<_BlockedLogoutDialog> {
  late int _count = widget.count;
  String? _error;
  bool _busy = false;

  Future<void> _sync() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(syncServiceProvider);
    final outcomes = await service.syncAllPending();
    final left = await service.pendingCount();
    if (!mounted) {
      return;
    }
    if (left == 0) {
      Navigator.of(context).pop(true);
      return;
    }
    final failed = outcomes.values.whereType<SyncFailed>().firstOrNull;
    setState(() {
      _busy = false;
      _count = left;
      _error = failed == null ? Strings.errorUnexpected : _messageOf(failed);
    });
  }

  String _messageOf(SyncFailed failure) => switch (failure.reason) {
    SyncFailure.network => Strings.errorOffline,
    SyncFailure.sessionExpired => Strings.errorSessionExpired,
    SyncFailure.removed => Strings.errorUnexpected,
    SyncFailure.server || SyncFailure.refused =>
      (failure.code == null ? null : errorMessageForCode(failure.code!)) ??
          Strings.errorUnexpected,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.turquoise.withValues(alpha: 0.2),
              child: const Icon(
                Icons.sync_problem_outlined,
                size: 28,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              Strings.logoutBlockedTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Strings.logoutBlockedBody(_count),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              KeyedSubtree(
                key: const ValueKey('logout-blocked-error'),
                child: ErrorBanner(_error!),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const ValueKey('logout-blocked-sync'),
                onPressed: _busy ? null : _sync,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(Strings.syncNow),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey('logout-blocked-ok'),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text(Strings.understood),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
