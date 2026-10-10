import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_state.dart';
import '../../app/sync_controller.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../auth/business_chooser_screen.dart';
import '../auth/logout.dart';
import '../theme.dart';
import '../widgets/error_banner.dart';

/// Lo que ve quien trabaja con un negocio pendiente de activación (RF-102,
/// T199): no ofrece registrar datos. Lo que ya estaba guardado en el teléfono
/// sigue en la cola y se envía solo al activarse.
class PendingBusinessScreen extends ConsumerStatefulWidget {
  const PendingBusinessScreen({super.key});

  @override
  ConsumerState<PendingBusinessScreen> createState() =>
      _PendingBusinessScreenState();
}

class _PendingBusinessScreenState extends ConsumerState<PendingBusinessScreen> {
  bool _busy = false;
  String? _message;
  bool _error = false;

  /// Vuelve a preguntarle al servidor: si ya lo activaron, la puerta de acceso
  /// cambia de pantalla sola y esta se destruye.
  Future<void> _check() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).refreshBusinesses();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = false;
          _message = Strings.businessStillPending;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = true;
          _message = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider).value;
    final name = session is SignedIn ? session.active?.name ?? '' : '';
    final queued = ref.watch(pendingChangesProvider).value ?? 0;
    return Scaffold(
      key: const ValueKey('pending-business'),
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.turquoise.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 36,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    Strings.businessPendingTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    Strings.businessPendingBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (queued > 0) ...[
                    const SizedBox(height: 16),
                    Card(
                      key: const ValueKey('pending-business-queue'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_upload_outlined,
                              color: AppColors.navy,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Strings.pendingChanges(queued),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(Strings.businessPendingQueue),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: const ValueKey('pending-business-message'),
                      child: _error
                          ? ErrorBanner(_message!)
                          : Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('pending-business-check'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _busy ? null : _check,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text(Strings.businessCheck),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('pending-business-switch'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const BusinessChooserScreen(asRoute: true),
                      ),
                    ),
                    child: const Text(Strings.switchBusiness),
                  ),
                  TextButton(
                    key: const ValueKey('pending-business-logout'),
                    onPressed: () => confirmLogout(context, ref),
                    child: const Text(Strings.logout),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
