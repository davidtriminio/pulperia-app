import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

/// Sección del catálogo. La lista real llega con T115.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    key: ValueKey('section-catalog'),
    child: Text(Strings.catalogEmpty),
  );
}
