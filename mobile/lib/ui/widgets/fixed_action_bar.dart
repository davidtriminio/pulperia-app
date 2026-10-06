import 'package:flutter/material.dart';

import '../theme.dart';

/// Barra inferior fija de los formularios de movimientos: a la izquierda el
/// total (o el monto) y a la derecha el botón de registrar. Va en el
/// `bottomNavigationBar` del `Scaffold`, así que no se desplaza con el
/// contenido y queda por encima del teclado. Un error del formulario se
/// muestra justo encima.
class FixedActionBar extends StatelessWidget {
  const FixedActionBar({
    super.key,
    required this.totalLabel,
    required this.totalText,
    required this.totalKey,
    required this.buttonLabel,
    required this.buttonKey,
    required this.onPressed,
    this.errorText,
    this.errorKey,
  });

  final String totalLabel;
  final String totalText;
  final Key totalKey;
  final String buttonLabel;
  final Key buttonKey;

  /// Null deshabilita el botón (mientras se guarda).
  final VoidCallback? onPressed;
  final String? errorText;
  final Key? errorKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorText!,
                    key: errorKey,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            totalText,
                            key: totalKey,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    key: buttonKey,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 52),
                    ),
                    onPressed: onPressed,
                    child: Text(buttonLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
