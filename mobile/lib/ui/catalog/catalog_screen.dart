import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/money/money.dart';
import '../../l10n/strings.dart';
import '../format/money_format.dart';
import '../widgets/confirm_dialog.dart';
import 'product_form_screen.dart';

/// Productos del catálogo del negocio activo que se pueden ofrecer al fiar.
final activeProductsProvider = FutureProvider<List<Product>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repository.activeProducts(businessId);
});

/// Catálogo: lista, alta, cambio de precio y archivado (RF-24 a RF-27). Un
/// producto no se borra nunca: solo se archiva.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(activeProductsProvider);
    final mode = ref
        .watch(activeBusinessProvider)
        .maybeWhen(
          data: (b) => AmountMode.fromId(b.amountMode),
          orElse: () => AmountMode.twoDecimals,
        );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-product'),
        icon: const Icon(Icons.add),
        label: const Text(Strings.newProduct),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()),
        ),
      ),
      body: products.when(
        loading: () => const SizedBox.shrink(key: ValueKey('section-catalog')),
        error: (error, _) => const Center(
          key: ValueKey('section-catalog'),
          child: Text(Strings.loadError),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              key: ValueKey('section-catalog'),
              child: Text(Strings.catalogEmpty),
            );
          }
          return ListView.builder(
            key: const ValueKey('section-catalog'),
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            itemCount: items.length,
            itemBuilder: (context, i) =>
                _ProductTile(product: items[i], mode: mode),
          );
        },
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product, required this.mode});

  final Product product;
  final AmountMode mode;

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.archive_outlined,
      title: Strings.archiveProductTitle,
      body: Strings.archiveProductBody,
      confirmLabel: Strings.archiveProduct,
      cancelLabel: Strings.cancel,
      confirmKey: const ValueKey('archive-confirm'),
      cancelKey: const ValueKey('archive-cancel'),
    );
    if (!confirmed) {
      return;
    }
    final user = ref.read(activeUserProvider);
    await ref
        .read(productRepositoryProvider)
        .archive(
          businessId: ref.read(activeBusinessIdProvider),
          userId: user.id,
          role: user.role,
          productId: product.id,
        );
    ref.invalidate(activeProductsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProductFormScreen(existing: product),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              top: 6,
              bottom: 6,
              right: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${Strings.perUnit} '
                        '${SaleUnit.fromId(product.unit).singular}',
                        key: ValueKey('product-unit-${product.id}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(Money(product.price), mode),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  key: ValueKey('archive-${product.id}'),
                  tooltip: Strings.archiveProduct,
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () => _archive(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
