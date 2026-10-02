/// Cómo mide las cantidades un negocio: solo unidades enteras o con fracciones.
enum QuantityMode {
  integer('integer'),
  fractional('fractional');

  const QuantityMode(this.id);

  /// Identificador estable, el mismo de los vectores compartidos.
  final String id;

  static QuantityMode fromId(String id) => values.firstWhere(
    (m) => m.id == id,
    orElse: () =>
        throw ArgumentError.value(id, 'id', 'modo de cantidad desconocido'),
  );
}
