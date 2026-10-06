import 'package:flutter_test/flutter_test.dart';
import 'package:pulperia_mobile/data/local/app_database.dart';
import 'package:pulperia_mobile/domain/business/amount_mode.dart';
import 'package:pulperia_mobile/domain/catalog/sale_unit.dart';
import 'package:pulperia_mobile/domain/money/money.dart';
import 'package:pulperia_mobile/domain/quantity/quantity.dart';
import 'package:pulperia_mobile/ui/ledger/fiado_cart.dart';

Product product(
  String id,
  String name,
  int price, {
  String unit = 'unit',
  bool archived = false,
}) => Product(
  id: id,
  businessId: 'b-1',
  name: name,
  price: price,
  unit: unit,
  archived: archived,
  version: 1,
  createdBy: 'u-1',
  createdAt: DateTime.utc(2026, 10, 1),
);

void main() {
  late FiadoCart cart;
  final arroz = product('p-1', 'Arroz', 2500);
  final carne = product('p-2', 'Carne', 9000, unit: 'pound');

  setUp(() => cart = FiadoCart());

  group('agregar productos (RF-30)', () {
    test('un carrito nuevo está vacío', () {
      expect(cart.lines, isEmpty);
      expect(cart.isEmpty, isTrue);
    });

    test('agregar un producto crea una línea con cantidad 1', () {
      cart.addProduct(arroz);

      final line = cart.lines.single;
      expect(line.productId, 'p-1');
      expect(line.quantity, const Quantity(1000));
    });

    test('copia el nombre, el precio y la unidad del producto (RF-87)', () {
      cart.addProduct(carne);

      final line = cart.lines.single;
      expect(line.description, 'Carne');
      expect(line.unitPrice, const Money(9000));
      expect(line.unit, SaleUnit.pound);
    });

    test('agregar el mismo producto otra vez suma 1 a su cantidad', () {
      cart.addProduct(arroz);
      cart.addProduct(arroz);
      cart.addProduct(arroz);

      expect(cart.lines, hasLength(1));
      expect(cart.lines.single.quantity, const Quantity(3000));
    });

    test('productos distintos van en líneas distintas, en orden', () {
      cart.addProduct(arroz);
      cart.addProduct(carne);

      expect(cart.lines.map((l) => l.productId), ['p-1', 'p-2']);
    });

    test('volver a tocar un producto con precio cambiado suma a esa línea', () {
      cart.addProduct(arroz);
      cart.update(cart.lines.single.id, unitPrice: const Money(2000));

      cart.addProduct(arroz);

      expect(cart.lines, hasLength(1));
      expect(cart.lines.single.quantity, const Quantity(2000));
      expect(cart.lines.single.unitPrice, const Money(2000));
    });
  });

  group('sumar, restar y quitar', () {
    test('sumar aumenta la cantidad en 1', () {
      cart.addProduct(arroz);

      cart.increment(cart.lines.single.id);

      expect(cart.lines.single.quantity, const Quantity(2000));
    });

    test('restar disminuye la cantidad en 1', () {
      cart.addProduct(arroz);
      cart.increment(cart.lines.single.id);

      cart.decrement(cart.lines.single.id);

      expect(cart.lines.single.quantity, const Quantity(1000));
    });

    test('restar de 1 quita la línea', () {
      cart.addProduct(arroz);

      cart.decrement(cart.lines.single.id);

      expect(cart.isEmpty, isTrue);
    });

    test('restar por debajo de 1 (0.5) también quita la línea', () {
      cart.addProduct(arroz);
      cart.update(cart.lines.single.id, quantity: const Quantity(500));

      cart.decrement(cart.lines.single.id);

      expect(cart.isEmpty, isTrue);
    });

    test('con una cantidad fraccionaria se suma y resta de 1 en 1', () {
      cart.addProduct(carne);
      cart.update(cart.lines.single.id, quantity: const Quantity(2500));

      cart.decrement(cart.lines.single.id);
      expect(cart.lines.single.quantity, const Quantity(1500));
      cart.increment(cart.lines.single.id);
      expect(cart.lines.single.quantity, const Quantity(2500));
    });

    test('quitar elimina la línea sin tocar las demás', () {
      cart.addProduct(arroz);
      cart.addProduct(carne);

      cart.remove(cart.lines.first.id);

      expect(cart.lines.map((l) => l.productId), ['p-2']);
    });

    test('operar sobre una línea que no existe no hace nada', () {
      cart.addProduct(arroz);

      cart.increment(999);
      cart.decrement(999);
      cart.remove(999);

      expect(cart.lines.single.quantity, const Quantity(1000));
    });
  });

  group('subtotal y total con el redondeo del negocio (RF-34, RF-83)', () {
    test('con 2 decimales redondea cada subtotal al centavo', () {
      cart.addProduct(product('p-3', 'Aceite', 1250));
      cart.update(cart.lines.single.id, quantity: const Quantity(333));

      final line = cart.lines.single;
      expect(
        cart.subtotalOf(line, AmountMode.twoDecimals),
        const Money(416), // 0.333 × 12.50 = 4.1625
      );
    });

    test('con montos enteros redondea al lempira, la mitad sube', () {
      cart.addProduct(product('p-3', 'Frijol', 2500));
      cart.update(cart.lines.single.id, quantity: const Quantity(500));

      expect(
        cart.subtotalOf(cart.lines.single, AmountMode.integer),
        const Money(1300), // 12.5 → 13
      );
    });

    test('el total suma los subtotales ya redondeados', () {
      cart.addProduct(arroz); // 25.00
      cart.addProduct(arroz); // 50.00 con cantidad 2
      cart.addProduct(product('p-3', 'Aceite', 1250));
      cart.update(cart.lines.last.id, quantity: const Quantity(333)); // 4.16

      expect(cart.total(AmountMode.twoDecimals), const Money(5416));
    });

    test('un carrito vacío suma cero', () {
      expect(cart.total(AmountMode.twoDecimals), Money.zero);
    });

    test('cambiar la unidad no cambia el subtotal (RF-89)', () {
      cart.addProduct(arroz);
      final id = cart.lines.single.id;
      final before = cart.total(AmountMode.twoDecimals);

      cart.update(id, unit: SaleUnit.dozen);

      expect(cart.total(AmountMode.twoDecimals), before);
      expect(cart.lines.single.unit, SaleUnit.dozen);
    });
  });

  group('editar una línea', () {
    test('cambia solo lo indicado', () {
      cart.addProduct(arroz);
      final id = cart.lines.single.id;

      cart.update(id, description: 'Arroz grande');

      final line = cart.lines.single;
      expect(line.description, 'Arroz grande');
      expect(line.unitPrice, const Money(2500));
      expect(line.productId, 'p-1');
    });

    test('cambiar el precio vale solo para esa línea (RF-30)', () {
      cart.addProduct(arroz);

      cart.update(cart.lines.single.id, unitPrice: const Money(2000));

      expect(cart.lines.single.unitPrice, const Money(2000));
      expect(arroz.price, 2500);
    });
  });

  group('ítems libres (RF-31)', () {
    test('un ítem libre no tiene producto ni precio, y usa "unidad"', () {
      cart.addFree();

      final line = cart.lines.single;
      expect(line.productId, isNull);
      expect(line.unitPrice, isNull);
      expect(line.unit, SaleUnit.unit);
      expect(line.quantity, const Quantity(1000));
    });

    test('sin precio no aporta al total ni al subtotal', () {
      cart.addFree();

      expect(
        cart.subtotalOf(cart.lines.single, AmountMode.twoDecimals),
        isNull,
      );
      expect(cart.total(AmountMode.twoDecimals), Money.zero);
    });

    test('con precio ya aporta', () {
      cart.addFree();
      cart.update(
        cart.lines.single.id,
        description: 'Un favor',
        unitPrice: const Money(1500),
      );

      expect(cart.total(AmountMode.twoDecimals), const Money(1500));
    });

    test('dos ítems libres son líneas distintas', () {
      cart.addFree();
      cart.addFree();

      expect(cart.lines, hasLength(2));
      expect(cart.lines[0].id, isNot(cart.lines[1].id));
    });
  });

  group('borradores para guardar', () {
    test('cada línea se convierte en un ítem del fiado', () {
      cart.addProduct(carne);
      cart.update(cart.lines.single.id, quantity: const Quantity(2500));

      final drafts = cart.toDrafts()!;

      expect(drafts, hasLength(1));
      expect(drafts.single.productId, 'p-2');
      expect(drafts.single.description, 'Carne');
      expect(drafts.single.quantity, const Quantity(2500));
      expect(drafts.single.unitPrice, const Money(9000));
      expect(drafts.single.unit, SaleUnit.pound);
    });

    test('si una línea no tiene precio no hay borradores', () {
      cart.addProduct(arroz);
      cart.addFree();

      expect(cart.toDrafts(), isNull);
      expect(cart.linesMissingPrice.map((l) => l.productId), [null]);
    });

    test('un carrito vacío no tiene borradores', () {
      expect(cart.toDrafts(), isNull);
    });
  });

  test('avisa a quien escucha en cada cambio', () {
    var changes = 0;
    cart.addListener(() => changes++);

    cart.addProduct(arroz);
    cart.increment(cart.lines.single.id);
    cart.decrement(cart.lines.single.id);
    cart.update(cart.lines.single.id, description: 'x');
    cart.remove(cart.lines.single.id);

    expect(changes, 5);
  });
}
