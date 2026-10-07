import 'sale_unit.dart';

/// Lo mínimo de un producto del catálogo para detectar repetidos.
final class ProductRef {
  const ProductRef({
    required this.id,
    required this.name,
    required this.unit,
    required this.archived,
  });

  final String id;
  final String name;
  final SaleUnit unit;
  final bool archived;
}

String _comparable(String name) => name.trim().toLowerCase();

/// El producto activo del negocio con el mismo nombre y la misma unidad que
/// el indicado, o null si no hay (RF-91). Ignora mayúsculas y espacios
/// exteriores; los espacios interiores y las tildes cuentan, como en los
/// homónimos de clientes (RF-17). Los archivados no cuentan.
///
/// Es un aviso, no un error: el usuario puede continuar si lo confirma. Al
/// editar un producto, [excludeId] es el suyo, para que no choque consigo
/// mismo. Un nombre vacío nunca tiene repetido: ya se rechaza aparte. Con
/// varios iguales devuelve el primero de [existing].
ProductRef? findDuplicateProduct({
  required String name,
  required SaleUnit unit,
  required Iterable<ProductRef> existing,
  String? excludeId,
}) {
  final target = _comparable(name);
  if (target.isEmpty) {
    return null;
  }
  for (final product in existing) {
    if (product.archived || product.id == excludeId) {
      continue;
    }
    if (product.unit == unit && _comparable(product.name) == target) {
      return product;
    }
  }
  return null;
}
