import '../quantity/quantity.dart';

/// Unidad de venta de un producto o de un ítem de fiado (RF-86 a RF-89).
///
/// Es solo una etiqueta: el precio unitario es por esa unidad y la cantidad se
/// expresa en ella, sin convertir entre unidades ni cambiar ningún cálculo.
/// Debe coincidir con `shared/vectors/units.json`; un test lo comprueba. Los
/// ids nunca se renombran ni se reutilizan, porque se guardan en cada
/// producto e ítem.
enum SaleUnit {
  unit('unit', 'unidad', 'unidades', 'u'),
  pound('pound', 'libra', 'libras', 'lb'),
  ounce('ounce', 'onza', 'onzas', 'oz'),
  kilo('kilo', 'kilo', 'kilos', 'kg'),
  dozen('dozen', 'docena', 'docenas', 'doc'),
  liter('liter', 'litro', 'litros', 'lt'),
  gallon('gallon', 'galón', 'galones', 'gal'),
  box('box', 'caja', 'cajas', 'cj'),
  bag('bag', 'bolsa', 'bolsas', 'bls'),
  pack('pack', 'paquete', 'paquetes', 'paq');

  const SaleUnit(this.id, this.singular, this.plural, this.abbreviation);

  /// Identificador estable, el mismo de los datos compartidos y de la API.
  final String id;
  final String singular;
  final String plural;
  final String abbreviation;

  /// La unidad de lo que no indica otra (RF-86, RF-87).
  static const SaleUnit defaultUnit = SaleUnit.unit;

  static bool isValidId(String? id) => tryFromId(id) != null;

  /// La unidad con ese id, o null si no existe en la lista.
  static SaleUnit? tryFromId(String? id) {
    for (final unit in values) {
      if (unit.id == id) {
        return unit;
      }
    }
    return null;
  }

  static SaleUnit fromId(String id) =>
      tryFromId(id) ??
      (throw ArgumentError.value(id, 'id', 'unidad de venta desconocida'));

  /// El nombre que corresponde a la [quantity]: en singular solo cuando es
  /// exactamente una unidad ("1 libra") y en plural en cualquier otro caso
  /// ("2 libras", "0.5 libras").
  String nameFor(Quantity quantity) =>
      quantity.milli == 1000 ? singular : plural;
}
