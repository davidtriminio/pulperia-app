import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../l10n/strings.dart';

/// Pone en marcha la sincronización del negocio activo: al abrirlo y cada vez
/// que se recupera la conexión (RF-52). El disparo manual está en el menú.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _request(SyncTrigger.open),
    );
  }

  void _request(SyncTrigger trigger) {
    if (mounted) {
      ref.read(syncControllerProvider.notifier).request(trigger);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(onlineProvider, (previous, next) {
      // Solo el paso de sin conexión a con conexión.
      if (previous?.value == false && next.value == true) {
        _request(SyncTrigger.reconnect);
      }
    });
    ref.listen(syncControllerProvider, (previous, next) {
      if (next.conflicts > 0 && !identical(previous?.last, next.last)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const ValueKey('sync-conflicts'),
            content: Text(Strings.conflictsDiscarded(next.conflicts)),
          ),
        );
      }
    });
    ref.listen(activeBusinessIdProvider, (previous, next) {
      if (previous != next) {
        _request(SyncTrigger.open);
      }
    });
    return widget.child;
  }
}
