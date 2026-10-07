import 'package:flutter/material.dart';

/// Caja para el monto (o el bloque de saldo) al final de una fila: ocupa solo
/// lo que mide, pero nunca más de [maxFraction] del ancho de la pantalla, y
/// un monto enorme se encoge en vez de desbordar.
///
/// Se usa en lugar de `Flexible` junto a un `Expanded`: ambos se repartirían
/// el espacio libre a partes iguales y el monto quedaría a mitad de la fila,
/// con un hueco vacío a su derecha.
class AmountBox extends StatelessWidget {
  const AmountBox({super.key, required this.child, this.maxFraction = 0.4});

  final Widget child;
  final double maxFraction;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * maxFraction;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}
