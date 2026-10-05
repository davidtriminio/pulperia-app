import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/fiado_repository.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../domain/ledger/fiado_validation.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';
import '../clients/client_detail_screen.dart';
import '../clients/clients_screen.dart';
import '../format/amount_messages.dart';
import '../format/money_format.dart';
import '../format/quantity_messages.dart';
import '../theme.dart';
import '../catalog/catalog_screen.dart';
import 'subtotal_preview.dart';

/// Un ítem en edición: sus campos de texto y los errores que se le muestran.
class _ItemEditor {
  _ItemEditor()
    : description = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      price = TextEditingController();

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController price;

  /// Producto del catálogo del que se copió el ítem; null si es libre (RF-31).
  String? productId;
  String? productName;

  String? quantityError;
  String? priceError;
  String? subtotalError;

  void clearErrors() {
    quantityError = null;
    priceError = null;
    subtotalError = null;
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }
}

/// Registrar un fiado a un cliente con el detalle de lo que se llevó (RF-28,
/// RF-33). El subtotal de cada ítem y el total se muestran ya redondeados
/// según los ajustes del negocio (RF-34, RF-83).
class FiadoFormScreen extends ConsumerStatefulWidget {
  const FiadoFormScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<FiadoFormScreen> createState() => _FiadoFormScreenState();
}

class _FiadoFormScreenState extends ConsumerState<FiadoFormScreen> {
  final List<_ItemEditor> _items = [_ItemEditor()];
  String? _formError;
  bool _saving = false;

  AmountMode get _amountMode => ref
      .read(activeBusinessProvider)
      .maybeWhen(
        data: (b) => AmountMode.fromId(b.amountMode),
        orElse: () => AmountMode.twoDecimals,
      );

  QuantityMode get _quantityMode => ref
      .read(activeBusinessProvider)
      .maybeWhen(
        data: (b) => QuantityMode.fromId(b.quantityMode),
        orElse: () => QuantityMode.fractional,
      );

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Money? _subtotalOf(_ItemEditor item) => previewSubtotal(
    quantity: item.quantity.text,
    unitPrice: item.price.text,
    amountMode: _amountMode,
    quantityMode: _quantityMode,
  );

  void _addItem() => setState(() => _items.add(_ItemEditor()));

  Future<void> _pickProduct(_ItemEditor item) async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProductPicker(mode: _amountMode),
    );
    if (product == null) {
      return;
    }
    // Se propone el precio del catálogo; el usuario puede cambiarlo solo para
    // este ítem (RF-30): el producto del catálogo no se toca.
    setState(() {
      item.productId = product.id;
      item.productName = product.name;
      item.description.text = product.name;
      item.price.text = plainAmount(Money(product.price), _amountMode);
    });
  }

  void _unlinkProduct(_ItemEditor item) => setState(() {
    item.productId = null;
    item.productName = null;
  });

  void _removeItem(int index) => setState(() {
    _items.removeAt(index).dispose();
  });

  /// Lee los campos de cada ítem. Devuelve null y deja los errores en pantalla
  /// si alguno no es válido.
  List<FiadoItemDraft>? _readItems() {
    final drafts = <FiadoItemDraft>[];
    var ok = true;
    for (final item in _items) {
      item.clearErrors();
      Quantity? quantity;
      Money? price;

      final quantityText = item.quantity.text.trim();
      if (quantityText.isEmpty) {
        item.quantityError = Strings.quantityRequired;
      } else {
        switch (Quantity.parse(quantityText, _quantityMode)) {
          case QuantityParsed(quantity: final q):
            quantity = q;
          case QuantityRejected(:final error):
            item.quantityError = quantityErrorMessage(error);
        }
      }

      final priceText = item.price.text.trim();
      if (priceText.isEmpty) {
        item.priceError = Strings.priceRequired;
      } else {
        switch (Money.parse(priceText, _amountMode)) {
          case MoneyParsed(:final money):
            price = money;
          case MoneyRejected(:final error):
            item.priceError = amountErrorMessage(error);
        }
      }

      if (quantity == null || price == null) {
        ok = false;
        continue;
      }
      drafts.add(
        FiadoItemDraft(
          description: item.description.text.trim(),
          productId: item.productId,
          quantity: quantity,
          unitPrice: price,
        ),
      );
    }
    return ok ? drafts : null;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final drafts = _readItems();
    setState(() => _formError = null);
    if (drafts == null) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    final user = ref.read(activeUserProvider);
    final result = await ref
        .read(fiadoRepositoryProvider)
        .create(
          businessId: ref.read(activeBusinessIdProvider),
          userId: user.id,
          role: user.role,
          clientId: widget.clientId,
          draft: FiadoWithItems(drafts),
        );
    if (!mounted) {
      return;
    }

    switch (result) {
      case FiadoSaved():
        ref.invalidate(clientHistoryProvider(widget.clientId));
        ref.invalidate(activeClientsProvider);
        Navigator.of(context).pop(true);
      case FiadoRejected(:final issues):
        setState(() {
          _saving = false;
          for (final issue in issues) {
            final index = issue.itemIndex;
            if (index == null) {
              _formError = Strings.fiadoEmpty;
              continue;
            }
            final item = _items[index];
            switch (issue.field) {
              case FiadoField.subtotal:
                item.subtotalError = Strings.subtotalZero;
              case FiadoField.quantity:
                item.quantityError = Strings.quantityInvalid;
              case FiadoField.unitPrice:
                item.priceError = Strings.amountInvalid;
              case FiadoField.fiado || FiadoField.total:
                _formError = Strings.fiadoEmpty;
            }
          }
        });
      case FiadoClientArchived():
        setState(() {
          _saving = false;
          _formError = Strings.clientArchivedFiado;
        });
      case FiadoClientNotFound():
        setState(() {
          _saving = false;
          _formError = Strings.clientNotFound;
        });
      case FiadoForbidden():
        setState(() {
          _saving = false;
          _formError = Strings.saveError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se vuelve a leer al cambiar los ajustes del negocio.
    ref.watch(activeBusinessProvider);
    final mode = _amountMode;
    final theme = Theme.of(context);

    var total = Money.zero;
    for (final item in _items) {
      total = total + (_subtotalOf(item) ?? Money.zero);
    }

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.newFiado)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ItemCard(
                index: i,
                editor: _items[i],
                subtotal: _subtotalOf(_items[i]),
                mode: mode,
                canRemove: _items.length > 1,
                onChanged: () => setState(() {}),
                onRemove: () => _removeItem(i),
                onPickProduct: () => _pickProduct(_items[i]),
                onUnlinkProduct: () => _unlinkProduct(_items[i]),
              ),
            ),
          TextButton.icon(
            key: const ValueKey('add-item'),
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text(Strings.addItem),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Strings.totalLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatMoney(total, mode),
                    key: const ValueKey('fiado-total'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _formError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('fiado-save'),
            onPressed: _saving ? null : _save,
            child: const Text(Strings.newFiado),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.index,
    required this.editor,
    required this.subtotal,
    required this.mode,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    required this.onPickProduct,
    required this.onUnlinkProduct,
  });

  final int index;
  final _ItemEditor editor;
  final Money? subtotal;
  final AmountMode mode;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onPickProduct;
  final VoidCallback onUnlinkProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${Strings.itemNumber} ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (canRemove)
                  IconButton(
                    key: ValueKey('remove-item-$index'),
                    tooltip: Strings.removeItem,
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (editor.productId == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: ValueKey('pick-product-$index'),
                  onPressed: onPickProduct,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text(Strings.pickFromCatalog),
                ),
              )
            else
              Container(
                key: ValueKey('item-product-$index'),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: AppColors.turquoise.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${Strings.fromCatalog}: ${editor.productName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('unlink-product-$index'),
                      tooltip: Strings.unlinkProduct,
                      icon: const Icon(Icons.link_off, size: 18),
                      onPressed: onUnlinkProduct,
                    ),
                  ],
                ),
              ),
            TextField(
              key: ValueKey('item-description-$index'),
              controller: editor.description,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: Strings.fieldDescription,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('item-quantity-$index'),
                    controller: editor.quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: Strings.fieldQuantity,
                      errorText: editor.quantityError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: ValueKey('item-price-$index'),
                    controller: editor.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: Strings.fieldUnitPrice,
                      prefixText: 'L ',
                      errorText: editor.priceError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
              ],
            ),
            if (subtotal != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(Strings.subtotalLabel),
                    Text(
                      formatMoney(subtotal!, mode),
                      key: ValueKey('item-subtotal-$index'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (editor.subtotalError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  editor.subtotalError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior con los productos activos del catálogo (RF-26): al tocar uno
/// se devuelve para copiar su nombre y su precio al ítem.
class _ProductPicker extends ConsumerWidget {
  const _ProductPicker({required this.mode});

  final AmountMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(activeProductsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: products.when(
          loading: () => const SizedBox(height: 120),
          error: (error, _) => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text(Strings.loadError)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text(Strings.catalogEmpty)),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final product in items)
                  ListTile(
                    key: ValueKey('product-option-${product.id}'),
                    title: Text(product.name),
                    trailing: Text(
                      formatMoney(Money(product.price), mode),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => Navigator.of(context).pop(product),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
