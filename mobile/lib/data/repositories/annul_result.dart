/// Resultado de anular un fiado o un abono (RF-43). [T] es el movimiento.
sealed class AnnulResult<T> {
  const AnnulResult();
}

/// El movimiento quedó anulado y su operación en la cola. Si ya lo estaba,
/// [alreadyAnnulled] es verdadero y no se cambió nada: se conservan quién y
/// cuándo lo anuló la primera vez.
final class Annulled<T> extends AnnulResult<T> {
  const Annulled(this.movement, {required this.alreadyAnnulled});

  final T movement;
  final bool alreadyAnnulled;
}

/// El movimiento no existe en ese negocio; no se escribió nada.
final class AnnulNotFound<T> extends AnnulResult<T> {
  const AnnulNotFound();
}

/// Solo el dueño puede anular (RF-45); no se escribió nada.
final class AnnulForbidden<T> extends AnnulResult<T> {
  const AnnulForbidden();
}
