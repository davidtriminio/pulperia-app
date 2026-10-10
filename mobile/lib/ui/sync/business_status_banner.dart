import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_state.dart';
import '../../domain/business/business_status.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

/// Avisa que el negocio activo está suspendido (RF-98, T194): el teléfono
/// sigue funcionando con lo que tiene y lo que se registre se envía al
/// reactivarse. No se ve con el negocio activo.
class BusinessStatusBanner extends ConsumerStatefulWidget {
  const BusinessStatusBanner({super.key});

  @override
  ConsumerState<BusinessStatusBanner> createState() =>
      _BusinessStatusBannerState();
}

class _BusinessStatusBannerState extends ConsumerState<BusinessStatusBanner> {
  bool _busy = false;

  Future<void> _check() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).refreshBusinesses();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).value;
    final status = session is SignedIn ? session.active?.status : null;
    if (status != BusinessStatus.suspended) {
      return const SizedBox.shrink();
    }
    return Material(
      key: const ValueKey('business-suspended-banner'),
      color: AppColors.turquoise.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.pause_circle_outline, color: AppColors.navy),
            const SizedBox(width: 12),
            const Expanded(child: Text(Strings.businessSuspended)),
            TextButton(
              key: const ValueKey('sync-banner-check'),
              onPressed: _busy ? null : _check,
              child: const Text(Strings.businessCheck),
            ),
          ],
        ),
      ),
    );
  }
}
