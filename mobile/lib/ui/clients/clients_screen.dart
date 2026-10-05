import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Sección de clientes. La lista real llega con T106.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('section-clients'),
    child: Text(Strings.clientsEmpty),
  );
}
