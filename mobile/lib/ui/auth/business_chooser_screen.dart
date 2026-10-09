import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../app/session_state.dart';
import '../../data/remote/models.dart';
import '../../domain/access/access.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import 'auth_widgets.dart';
import 'create_business_screen.dart';
import 'logout.dart';

/// Elegir el negocio con el que se trabaja (RF-5, RF-6) y crear otro (RF-79).
/// Es la pantalla que sigue al inicio de sesión cuando hay varios negocios (o
/// ninguno), y también se abre desde el menú para cambiar de negocio
/// ([asRoute]).
class BusinessChooserScreen extends ConsumerStatefulWidget {
  const BusinessChooserScreen({super.key, this.asRoute = false});

  /// Abierta desde el menú, encima de las pantallas de trabajo: tiene botón
  /// de volver y se cierra al elegir.
  final bool asRoute;

  @override
  ConsumerState<BusinessChooserScreen> createState() =>
      _BusinessChooserScreenState();
}

class _BusinessChooserScreenState extends ConsumerState<BusinessChooserScreen> {
  late Future<List<RemoteBusiness>> _businesses;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _businesses = _load();
  }

  Future<List<RemoteBusiness>> _load() =>
      ref.read(sessionControllerProvider.notifier).loadBusinesses();

  void _reload() => setState(() {
    _error = null;
    _businesses = _load();
  });

  Future<void> _choose(RemoteBusiness business) async {
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .chooseBusiness(business);
      if (widget.asRoute && mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = errorMessage(e));
      }
    }
  }

  /// Termina de crear un negocio: ya es el activo. Si esta pantalla se abrió
  /// desde el menú, se cierra; si es la de después de iniciar sesión, la puerta
  /// de acceso la reemplaza por las pantallas de trabajo.
  void _created() {
    if (widget.asRoute && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_creating) {
      return CreateBusinessView(
        onCancel: () => setState(() => _creating = false),
        onCreated: _created,
      );
    }
    final state = ref.watch(sessionControllerProvider).value;
    final activeId = state is SignedIn ? state.active?.id : null;
    final removedName = ref.watch(removedBusinessProvider);
    return AuthPage(
      key: const ValueKey('business-chooser'),
      title: Strings.chooseBusinessTitle,
      subtitle: Strings.chooseBusinessSubtitle,
      leading: widget.asRoute
          ? IconButton(
              key: const ValueKey('chooser-back'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      children: [
        if (removedName != null) ...[
          KeyedSubtree(
            key: const ValueKey('removed-notice'),
            child: ErrorBanner(Strings.businessRemoved(removedName)),
          ),
          const SizedBox(height: 12),
        ],
        FutureBuilder<List<RemoteBusiness>>(
          future: _businesses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  ErrorBanner(errorMessage(snapshot.error!)),
                  TextButton(
                    key: const ValueKey('business-retry'),
                    onPressed: _reload,
                    child: const Text(Strings.retry),
                  ),
                ],
              );
            }
            final list = snapshot.data!;
            if (list.isEmpty) {
              return const _NoBusinesses();
            }
            return Column(
              children: [
                for (final business in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BusinessTile(
                      business: business,
                      selected: business.id == activeId,
                      onTap: () => _choose(business),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorBanner(_error!),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('business-create'),
          onPressed: () => setState(() => _creating = true),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text(Strings.createBusiness),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
        ),
        if (!widget.asRoute)
          TextButton(
            key: const ValueKey('business-logout'),
            onPressed: () => confirmLogout(context, ref),
            child: const Text(Strings.logout),
          ),
      ],
    );
  }
}

class _NoBusinesses extends StatelessWidget {
  const _NoBusinesses();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 40,
            color: AppColors.navy,
          ),
          const SizedBox(height: 8),
          Text(
            Strings.noBusinesses,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            Strings.noBusinessesHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  const _BusinessTile({
    required this.business,
    required this.selected,
    required this.onTap,
  });

  final RemoteBusiness business;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('business-tile-${business.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                child: Icon(Icons.storefront_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      business.role == Role.owner
                          ? Strings.roleOwner
                          : Strings.roleEmployee,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.turquoise)
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
