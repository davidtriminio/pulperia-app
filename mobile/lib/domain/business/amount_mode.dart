/// Cómo maneja los montos un negocio: lempiras enteros o con 2 decimales.
enum AmountMode {
  integer('integer'),
  twoDecimals('two_decimals');

  const AmountMode(this.id);

  /// Identificador estable, el mismo de los vectores compartidos.
  final String id;

  static AmountMode fromId(String id) => values.firstWhere(
    (m) => m.id == id,
    orElse: () =>
        throw ArgumentError.value(id, 'id', 'modo de monto desconocido'),
  );
}
