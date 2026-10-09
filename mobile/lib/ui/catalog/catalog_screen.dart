import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/money/money.dart';
import '../../l10n/strings.dart';
import '../format/date_format.dart';
import '../format/money_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/amount_box.dart';
import '../theme.dart';
import 'product_form_screen.dart';

/// Productos del catálogo del negocio activo que se pueden ofrecer al fiar.
final activeProductsProvider = FutureProvider<List<Product>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repository.activeProducts(businessId);
});

/// Los productos que se ofrecen de entrada al fiar: los más fiados del
/// negocio, completados con los más recientes (máximo 8). Se recalcula cada
/// vez que se abre la pantalla de fiar.
final frequentProductsProvider = FutureProvider.autoDispose<List<Product>>((
  ref,
) {
  final repository = ref.watch(productRepositoryProvider);
  final businessId = ref.watch(activeBusinessIdProvider);
  return repository.frequentProducts(businessId);
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
        // Sin héroe: las pantallas de la barra inferior conviven en el mismo
        // IndexedStack y dos botones con la misma etiqueta rompen las rutas.
        heroTag: null,
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
    final radius = BorderRadius.circular(20);
    final hasPrevious =
        product.previousPrice != null && product.priceChangedAt != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        key: ValueKey('catalog-tile-${product.id}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFDCE6EB)),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductFormScreen(existing: product),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                key: ValueKey(
                                  'product-unit-pill-${product.id}',
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.turquoise.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${Strings.perUnit} '
                                  '${SaleUnit.fromId(product.unit).singular}',
                                  key: ValueKey('product-unit-${product.id}'),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AmountBox(
                          child: Text(
                            formatMoney(Money(product.price), mode),
                            key: ValueKey('product-price-${product.id}'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
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
                    // Solo el último precio anterior, si el precio cambió
                    // alguna vez (RF-90), a todo el ancho de la tarjeta.
                    if (hasPrevious)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 12),
                        child: Text(
                          '${Strings.previousPriceLabel}: '
                          '${formatMoney(Money(product.previousPrice!), mode)}'
                          ' · ${Strings.priceChangedOn} '
                          '${formatDate(product.priceChangedAt!)}',
                          key: ValueKey('product-previous-${product.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
