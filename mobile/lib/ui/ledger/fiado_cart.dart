import 'package:flutter/foundation.dart';

import '../../data/local/app_database.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/catalog/sale_unit.dart';
import '../../domain/ledger/fiado_validation.dart';
import '../../domain/ledger/subtotal.dart';
import '../../domain/money/money.dart';
import '../../domain/quantity/quantity.dart';

/// Una línea del carrito: un ítem del fiado todavía sin guardar.
@immutable
class CartLine {
  const CartLine({
    required this.id,
    required this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
  });

  /// Identificador local de la línea, solo para esta pantalla.
  final int id;

  /// Producto del catálogo del que se copió; null si es un ítem libre (RF-31).
  final String? productId;
  final String description;
  final Quantity quantity;

  /// Null mientras un ítem libre no tiene precio.
  final Money? unitPrice;
  final SaleUnit unit;

  CartLine copyWith({
    String? description,
    Quantity? quantity,
    Money? unitPrice,
    SaleUnit? unit,
  }) => CartLine(
    id: id,
    productId: productId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    unit: unit ?? this.unit,
  );
}

/// El carrito de un fiado: la lista de ítems que se van agregando con un
/// toque. Es solo estado: no usa la base ni dibuja nada. Las reglas de dinero
/// (subtotal, redondeo, unidad) son las del dominio.
class FiadoCart extends ChangeNotifier {
  static const int _oneUnit = 1000;

  final List<CartLine> _lines = [];
  int _nextId = 1;

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;

  /// Agrega un producto del catálogo con cantidad 1, copiando su nombre,
  /// precio y unidad (RF-30, RF-87). Si ya está en el carrito, suma 1 a esa
  /// línea.
  void addProduct(Product product) {
    final index = _lines.indexWhere((l) => l.productId == product.id);
    if (index >= 0) {
      _setQuantity(index, Quantity(_lines[index].quantity.milli + _oneUnit));
      return;
    }
    _lines.add(
      CartLine(
        id: _nextId++,
        productId: product.id,
        description: product.name,
        quantity: const Quantity(_oneUnit),
        unitPrice: Money(product.price),
        unit: SaleUnit.fromId(product.unit),
      ),
    );
    notifyListeners();
  }

  /// Agrega un ítem libre, sin producto ni precio (RF-31), por "unidad".
  void addFree() {
    _lines.add(
      CartLine(
        id: _nextId++,
        productId: null,
        description: '',
        quantity: const Quantity(_oneUnit),
        unitPrice: null,
        unit: SaleUnit.defaultUnit,
      ),
    );
    notifyListeners();
  }

  void increment(int id) {
    final index = _indexOf(id);
    if (index < 0) return;
    _setQuantity(index, Quantity(_lines[index].quantity.milli + _oneUnit));
  }

  /// Resta 1; si la cantidad queda en cero o menos, quita la línea.
  void decrement(int id) {
    final index = _indexOf(id);
    if (index < 0) return;
    final milli = _lines[index].quantity.milli;
    if (milli <= _oneUnit) {
      _lines.removeAt(index);
      notifyListeners();
      return;
    }
    _setQuantity(index, Quantity(milli - _oneUnit));
  }

  void remove(int id) {
    final index = _indexOf(id);
    if (index < 0) return;
    _lines.removeAt(index);
    notifyListeners();
  }

  /// Cambia solo lo indicado de una línea. El precio y la unidad valen solo
  /// para esa línea: el producto del catálogo no se toca (RF-30).
  void update(
    int id, {
    String? description,
    Quantity? quantity,
    Money? unitPrice,
    SaleUnit? unit,
  }) {
    final index = _indexOf(id);
    if (index < 0) return;
    _lines[index] = _lines[index].copyWith(
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      unit: unit,
    );
    notifyListeners();
  }

  /// Subtotal de una línea según el modo de montos del negocio (RF-34, RF-83);
  /// null si le falta el precio o redondea a cero.
  Money? subtotalOf(CartLine line, AmountMode mode) {
    final price = line.unitPrice;
    if (price == null || !price.isPositive || line.quantity.milli <= 0) {
      return null;
    }
    final subtotal = switch (mode) {
      AmountMode.integer => wholeLempiraSubtotal(
        quantity: line.quantity,
        unitPrice: price,
      ),
      AmountMode.twoDecimals => centavoSubtotal(
        quantity: line.quantity,
        unitPrice: price,
      ),
    };
    return subtotal.isPositive ? subtotal : null;
  }

  /// Suma de los subtotales ya redondeados.
  Money total(AmountMode mode) {
    var sum = Money.zero;
    for (final line in _lines) {
      sum = sum + (subtotalOf(line, mode) ?? Money.zero);
    }
    return sum;
  }

  /// Las líneas a las que todavía les falta el precio.
  List<CartLine> get linesMissingPrice => [
    for (final l in _lines)
      if (l.unitPrice == null) l,
  ];

  /// Los ítems listos para guardar, o null si el carrito está vacío o a alguna
  /// línea le falta el precio.
  List<FiadoItemDraft>? toDrafts() {
    if (_lines.isEmpty || linesMissingPrice.isNotEmpty) {
      return null;
    }
    return [
      for (final line in _lines)
        FiadoItemDraft(
          description: line.description.trim(),
          productId: line.productId,
          quantity: line.quantity,
          unitPrice: line.unitPrice!,
          unit: line.unit,
        ),
    ];
  }

  int _indexOf(int id) => _lines.indexWhere((l) => l.id == id);

  void _setQuantity(int index, Quantity quantity) {
    _lines[index] = _lines[index].copyWith(quantity: quantity);
    notifyListeners();
  }
}
