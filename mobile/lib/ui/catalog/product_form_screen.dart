import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/product_validation.dart';
import '../../domain/money/money.dart';
import '../../l10n/strings.dart';
import '../format/amount_messages.dart';
import '../format/money_format.dart';
import 'catalog_screen.dart';

/// Crear o editar un producto del catálogo (RF-24, RF-25). Con [existing]
/// edita ese producto; sin él crea uno nuevo.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.existing});

  final Product? existing;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  String? _nameError;
  String? _priceError;
  bool _saving = false;

  AmountMode get _mode => ref
      .read(activeBusinessProvider)
      .maybeWhen(
        data: (b) => AmountMode.fromId(b.amountMode),
        orElse: () => AmountMode.twoDecimals,
      );

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController();
    if (p != null) {
      // El modo del negocio se conoce al abrir la pantalla.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _price.text.isEmpty) {
          _price.text = plainAmount(Money(p.price), _mode);
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final mode = _mode;
    final text = _price.text.trim();

    String? priceError;
    Money? price;
    if (text.isEmpty) {
      priceError = Strings.priceRequired;
    } else {
      switch (Money.parse(text, mode)) {
        case MoneyParsed(:final money):
          price = money;
        case MoneyRejected(:final error):
          priceError = amountErrorMessage(error);
      }
    }
    final nameError = _name.text.trim().isEmpty
        ? Strings.productNameRequired
        : null;

    setState(() {
      _nameError = nameError;
      _priceError = priceError;
    });
    if (nameError != null || price == null) {
      return;
    }

    setState(() => _saving = true);
    final repository = ref.read(productRepositoryProvider);
    final businessId = ref.read(activeBusinessIdProvider);
    final user = ref.read(activeUserProvider);
    final existing = widget.existing;

    final result = existing == null
        ? await repository.create(
            businessId: businessId,
            userId: user.id,
            role: user.role,
            name: _name.text,
            price: price,
          )
        : await repository.update(
            businessId: businessId,
            userId: user.id,
            role: user.role,
            productId: existing.id,
            name: _name.text,
            price: price,
          );
    if (!mounted) {
      return;
    }

    switch (result) {
      case ProductSaved():
        ref.invalidate(activeProductsProvider);
        Navigator.of(context).pop(true);
      case ProductRejected(:final issues):
        setState(() {
          _saving = false;
          for (final issue in issues) {
            switch (issue.field) {
              case ProductField.name:
                _nameError = Strings.productNameRequired;
              case ProductField.price:
                _priceError = Strings.amountNotWhole;
            }
          }
        });
      case ProductNotFound():
        setState(() => _saving = false);
        _show(Strings.productNotFound);
      case ProductForbidden():
        setState(() => _saving = false);
        _show(Strings.saveError);
    }
  }

  void _show(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? Strings.newProduct : Strings.editProduct,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('field-product-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: Strings.fieldProductName,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-product-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: Strings.fieldPrice,
                prefixText: 'L ',
                errorText: _priceError,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('product-save'),
              onPressed: _saving ? null : _save,
              child: const Text(Strings.save),
            ),
          ],
        ),
      ),
    );
  }
}
