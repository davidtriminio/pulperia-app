import 'amount_mode.dart';
import 'quantity_mode.dart';

/// Motivo por el que se rechaza un cambio de modo del negocio.
enum ModeChangeError {
  downgradeNotAllowed('mode_downgrade_not_allowed');

  const ModeChangeError(this.code);

  /// Código estable, el mismo de los vectores compartidos.
  final String code;
}

sealed class ModeChangeResult {
  const ModeChangeResult();
}

final class ModeChangeAllowed extends ModeChangeResult {
  const ModeChangeAllowed();
}

final class ModeChangeDenied extends ModeChangeResult {
  const ModeChangeDenied(this.error);

  final ModeChangeError error;
}

/// Cambiar el modo de montos: solo se puede pasar de enteros a 2 decimales
/// (RF-8), nunca al revés (RF-9). Pedir el mismo modo no cambia nada.
ModeChangeResult changeAmountMode({
  required AmountMode current,
  required AmountMode requested,
}) {
  final isDowngrade =
      current == AmountMode.twoDecimals && requested == AmountMode.integer;
  return isDowngrade
      ? const ModeChangeDenied(ModeChangeError.downgradeNotAllowed)
      : const ModeChangeAllowed();
}

/// Cambiar el modo de cantidades: solo se puede pasar de enteras a
/// fraccionarias (RF-8), nunca al revés (RF-9). Pedir el mismo modo no cambia
/// nada.
ModeChangeResult changeQuantityMode({
  required QuantityMode current,
  required QuantityMode requested,
}) {
  final isDowngrade =
      current == QuantityMode.fractional && requested == QuantityMode.integer;
  return isDowngrade
      ? const ModeChangeDenied(ModeChangeError.downgradeNotAllowed)
      : const ModeChangeAllowed();
}
