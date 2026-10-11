/// Estado de un negocio en la plataforma (D-30): pendiente de activación,
/// activo o suspendido. Los identificadores son los del servidor.
enum BusinessStatus {
  pending('pending'),
  active('active'),
  suspended('suspended');

  const BusinessStatus(this.id);

  final String id;

  /// Solo un negocio activo recibe lotes y entrega cambios; uno pendiente o
  /// suspendido los rechaza sin perder nada (RF-98, RF-102).
  bool get acceptsData => this == BusinessStatus.active;

  static BusinessStatus fromId(String id) => values.firstWhere(
    (s) => s.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'Estado desconocido'),
  );
}
