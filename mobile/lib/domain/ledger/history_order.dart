/// Lo que hace falta de un movimiento para ubicarlo en el historial.
abstract interface class HistoryPosition {
  String get id;

  /// Fecha en que se creó el movimiento en el dispositivo (UTC).
  DateTime get occurredAt;

  /// Orden de llegada al servidor; null mientras el movimiento no se ha
  /// sincronizado.
  int? get serverSeq;
}

int _compare(HistoryPosition a, HistoryPosition b) {
  final byDate = a.occurredAt.compareTo(b.occurredAt);
  if (byDate != 0) {
    return byDate;
  }

  final seqA = a.serverSeq;
  final seqB = b.serverSeq;
  if (seqA != null && seqB != null) {
    final bySeq = seqA.compareTo(seqB);
    if (bySeq != 0) {
      return bySeq;
    }
  } else if (seqA != null) {
    return -1;
  } else if (seqB != null) {
    return 1;
  }

  return a.id.compareTo(b.id);
}

/// Ordena el historial de un cliente del movimiento más antiguo al más
/// reciente (RF-41, D-18). Orden total, así que el resultado nunca depende del
/// orden de entrada:
///
/// 1. Fecha de creación en el dispositivo: refleja cuándo ocurrió la venta
///    aunque se sincronice tarde.
/// 2. Con la misma fecha, orden de llegada al servidor; lo aún no
///    sincronizado va después de lo sincronizado.
/// 3. Con todo igual, el id (comparación ordinal del texto).
///
/// Devuelve una lista nueva y no modifica la recibida.
List<T> sortHistory<T extends HistoryPosition>(Iterable<T> entries) =>
    [...entries]..sort(_compare);
