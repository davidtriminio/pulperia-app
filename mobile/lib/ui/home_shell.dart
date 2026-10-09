import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/sync_controller.dart';
import '../domain/access/access.dart';
import '../l10n/strings.dart';
import 'auth/business_chooser_screen.dart';
import 'auth/logout.dart';
import 'business/settings_screen.dart';
import 'catalog/catalog_screen.dart';
import 'clients/clients_screen.dart';
import 'summary/summary_screen.dart';
import 'sync/sync_indicator.dart';
import 'sync/sync_triggers.dart';

/// Estructura principal: barra superior con el negocio activo y navegación
/// inferior entre las secciones.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

enum _MenuAction { syncNow, settings, switchBusiness, logout }

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final role = ref.watch(activeUserProvider).role;
    return Scaffold(
      appBar: AppBar(
        title: Text(business.maybeWhen(data: (b) => b.name, orElse: () => '')),
        actions: [
          const SyncIndicator(),
          PopupMenuButton<_MenuAction>(
            key: const ValueKey('home-menu'),
            tooltip: Strings.menu,
            onSelected: (action) => switch (action) {
              _MenuAction.syncNow =>
                ref
                    .read(syncControllerProvider.notifier)
                    .request(SyncTrigger.manual),
              _MenuAction.settings => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const BusinessSettingsScreen(),
                ),
              ),
              _MenuAction.switchBusiness => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const BusinessChooserScreen(asRoute: true),
                ),
              ),
              _MenuAction.logout => confirmLogout(context, ref),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                key: ValueKey('menu-sync'),
                value: _MenuAction.syncNow,
                child: Text(Strings.syncNow),
              ),
              if (can(role, Permission.manageBusinessSettings))
                const PopupMenuItem(
                  key: ValueKey('menu-settings'),
                  value: _MenuAction.settings,
                  child: Text(Strings.menuSettings),
                ),
              const PopupMenuItem(
                key: ValueKey('menu-switch-business'),
                value: _MenuAction.switchBusiness,
                child: Text(Strings.switchBusiness),
              ),
              const PopupMenuItem(
                key: ValueKey('menu-logout'),
                value: _MenuAction.logout,
                child: Text(Strings.logout),
              ),
            ],
          ),
        ],
      ),
      body: SyncTriggers(
        child: IndexedStack(
          index: _index,
          children: const [ClientsScreen(), SummaryScreen(), CatalogScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav-clients'),
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Strings.clients,
          ),
          NavigationDestination(
            key: ValueKey('nav-summary'),
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: Strings.summary,
          ),
          NavigationDestination(
            key: ValueKey('nav-catalog'),
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: Strings.catalog,
          ),
        ],
      ),
    );
  }
}
