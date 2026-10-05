import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../l10n/strings.dart';
import 'catalog/catalog_screen.dart';
import 'clients/clients_screen.dart';

/// Estructura principal: barra superior con el negocio activo y navegación
/// inferior entre las secciones.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(business.maybeWhen(data: (b) => b.name, orElse: () => '')),
      ),
      body: IndexedStack(
        index: _index,
        children: const [ClientsScreen(), CatalogScreen()],
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
