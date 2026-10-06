import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/fiado_repository.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/ledger/fiado_validation.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';
import '../../l10n/strings.dart';
import '../catalog/catalog_screen.dart';
import '../clients/client_detail_screen.dart';
import '../clients/clients_screen.dart';
import '../format/amount_messages.dart';
import '../format/money_format.dart';
import '../format/quantity_format.dart';
import '../input_limits.dart';
import '../theme.dart';
import 'fiado_cart.dart';
import 'fiado_messages.dart';
import 'line_edit_sheet.dart';

/// Registrar un fiado a un cliente (RF-28, RF-29, RF-33).
///
/// Con detalle: el catálogo se muestra como una cuadrícula con búsqueda; un
/// toque agrega el producto con cantidad 1 y otro toque suma 1. Abajo queda el
/// carrito. El subtotal y el total salen ya redondeados según los ajustes del
/// negocio (RF-34, RF-83).
class FiadoFormScreen extends ConsumerStatefulWidget {
  const FiadoFormScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<FiadoFormScreen> createState() => _FiadoFormScreenState();
}

class _FiadoFormScreenState extends ConsumerState<FiadoFormScreen> {
  final FiadoCart _cart = FiadoCart();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _totalInput = TextEditingController();
  bool _totalOnly = false;
  String? _totalError;
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
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cart
      ..removeListener(_onCartChanged)
      ..dispose();
    _search.dispose();
    _totalInput.dispose();
    super.dispose();
  }

  /// Agrega un ítem libre (RF-31) y abre su edición para pedir el precio.
  void _addFree() {
    _cart.addFree();
    final line = _cart.lines.last;
    showLineEditSheet(
      context,
      cart: _cart,
      line: line,
      amountMode: _amountMode,
      quantityMode: _quantityMode,
    );
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() => _formError = null);
    }
  }

  /// Lee el monto total del fiado sin detalle (RF-29). Devuelve null y deja el
  /// error en pantalla si no es válido.
  FiadoDraft? _readTotal() {
    final text = _totalInput.text.trim();
    String? error;
    Money? amount;
    if (text.isEmpty) {
      error = Strings.totalRequired;
    } else {
      switch (Money.parse(text, _amountMode)) {
        case MoneyParsed(:final money):
          amount = money;
        case MoneyRejected(error: final e):
          error = amountErrorMessage(e);
      }
    }
    _totalError = error;
    return amount == null ? null : FiadoTotalOnly(amount);
  }

  /// Los ítems del carrito, o null si no se pueden guardar (y deja el motivo
  /// en pantalla).
  FiadoDraft? _readCart() {
    if (_cart.isEmpty) {
      _formError = Strings.fiadoEmpty;
      return null;
    }
    final drafts = _cart.toDrafts();
    if (drafts == null) {
      _formError = Strings.fiadoMissingPrice;
      return null;
    }
    return FiadoWithItems(drafts);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _formError = null);
    final draft = _totalOnly ? _readTotal() : _readCart();
    if (draft == null) {
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
          draft: draft,
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
          _formError = fiadoIssueMessage(issues.first);
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
    if (_totalOnly) {
      final parsed = Money.parse(_totalInput.text.trim(), mode);
      if (parsed is MoneyParsed) {
        total = parsed.money;
      }
    } else {
      total = _cart.total(mode);
    }

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.newFiado)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text(Strings.modeItems, key: ValueKey('mode-items')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(Strings.modeTotal, key: ValueKey('mode-total')),
                ),
              ],
              selected: {_totalOnly},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _totalOnly = value.first),
            ),
            const SizedBox(height: 12),
            if (_totalOnly)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    key: const ValueKey('fiado-total-input'),
                    inputFormatters: InputLimits.text(InputLimits.amount),
                    controller: _totalInput,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() => _totalError = null),
                    decoration: InputDecoration(
                      labelText: Strings.fieldTotal,
                      prefixText: 'L ',
                      errorText: _totalError,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
              )
            else ...[
              TextField(
                key: const ValueKey('product-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: Strings.searchProducts,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              _ProductGrid(
                query: _search.text,
                cart: _cart,
                mode: mode,
                onTap: _cart.addProduct,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('add-free'),
                onPressed: _addFree,
                icon: const Icon(Icons.add),
                label: const Text(Strings.addFreeItem),
              ),
              const SizedBox(height: 20),
              Text(
                Strings.cartTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_cart.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      Strings.cartEmptyHint,
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ),
                )
              else
                for (final line in _cart.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CartRow(
                      line: line,
                      cart: _cart,
                      mode: mode,
                      onEdit: () => showLineEditSheet(
                        context,
                        cart: _cart,
                        line: line,
                        amountMode: mode,
                        quantityMode: _quantityMode,
                      ),
                    ),
                  ),
            ],
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
                  key: const ValueKey('fiado-form-error'),
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
      ),
    );
  }
}

/// El catálogo como una cuadrícula de dos columnas: un toque agrega el
/// producto al carrito y otro toque suma 1 (RF-30). Los archivados no se
/// ofrecen (RF-26).
class _ProductGrid extends ConsumerWidget {
  const _ProductGrid({
    required this.query,
    required this.cart,
    required this.mode,
    required this.onTap,
  });

  final String query;
  final FiadoCart cart;
  final AmountMode mode;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(activeProductsProvider);
    return products.when(
      loading: () => const SizedBox(height: 80),
      error: (error, _) => const Center(child: Text(Strings.loadError)),
      data: (all) {
        if (all.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(Strings.catalogEmpty)),
          );
        }
        final needle = query.trim().toLowerCase();
        final shown = [
          for (final p in all)
            if (needle.isEmpty || p.name.toLowerCase().contains(needle)) p,
        ];
        if (shown.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(Strings.noProductsFound)),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final product in shown)
                  SizedBox(
                    width: width,
                    child: _ProductTile(
                      product: product,
                      inCart: cart.lines
                          .where((l) => l.productId == product.id)
                          .map((l) => l.quantity)
                          .firstOrNull,
                      mode: mode,
                      onTap: () => onTap(product),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.mode,
    required this.onTap,
  });

  final Product product;
  final Quantity? inCart;
  final AmountMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = SaleUnit.fromId(product.unit);
    final selected = inCart != null;
    return Material(
      color: selected
          ? AppColors.turquoise.withValues(alpha: 0.18)
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('product-tile-${product.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.turquoise : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(Money(product.price), mode),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${Strings.perUnit} ${unit.singular}',
                      key: ValueKey('product-unit-${product.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.navy,
                  child: Text(
                    formatQuantity(inCart!),
                    key: ValueKey('product-count-${product.id}'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una línea del carrito: nombre, − cantidad +, y su subtotal.
class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.line,
    required this.cart,
    required this.mode,
    required this.onEdit,
  });

  final CartLine line;
  final FiadoCart cart;
  final AmountMode mode;

  /// Abre la edición de precio, unidad, descripción y cantidad exacta.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = cart.subtotalOf(line, mode);
    final removes = line.quantity.milli <= 1000;

    return Card(
      key: ValueKey('cart-line-${line.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('line-edit-${line.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              line.description.isEmpty
                                  ? Strings.freeItem
                                  : line.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                      if (line.unitPrice != null)
                        Text(
                          '${formatMoney(line.unitPrice!, mode)} '
                          '${Strings.perUnit} ${line.unit.singular}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        )
                      else
                        Text(
                          Strings.priceMissing,
                          key: ValueKey('line-missing-price-${line.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      if (line.unitPrice != null && subtotal == null)
                        Text(
                          Strings.subtotalZero,
                          key: ValueKey('line-zero-${line.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      key: ValueKey('line-minus-${line.id}'),
                      tooltip: removes ? Strings.removeItem : Strings.lessOne,
                      icon: Icon(removes ? Icons.delete_outline : Icons.remove),
                      onPressed: () => cart.decrement(line.id),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 36),
                      child: Text(
                        formatQuantity(line.quantity),
                        key: ValueKey('line-qty-${line.id}'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      key: ValueKey('line-plus-${line.id}'),
                      tooltip: Strings.moreOne,
                      icon: const Icon(Icons.add),
                      onPressed: () => cart.increment(line.id),
                    ),
                  ],
                ),
                if (subtotal != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      formatMoney(subtotal, mode),
                      key: ValueKey('line-subtotal-${line.id}'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
