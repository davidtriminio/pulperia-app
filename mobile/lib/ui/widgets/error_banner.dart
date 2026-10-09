import 'package:flutter/material.dart';

import '../theme.dart';

/// Aviso de error de un formulario (fuera de un campo): tarjeta rojiza con
/// una franja a la izquierda, icono y texto en negrita. Con varios mensajes
/// los apila en la misma tarjeta.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(String text, {super.key})
    : messages = const [],
      _one = text;

  const ErrorBanner.all(this.messages, {super.key}) : _one = null;

  final List<String> messages;
  final String? _one;

  @override
  Widget build(BuildContext context) {
    final lines = _one != null ? [_one] : messages;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.debtSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.debt.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: AppColors.debt),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.debt,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            Text(
                              line,
                              style: const TextStyle(
                                color: AppColors.debtDark,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje de error bajo un campo, para `InputDecoration.error`: icono y
/// texto en negrita en vez del texto plano de `errorText`. Con `null` no
/// muestra nada.
Widget? fieldError(String? text) {
  if (text == null) return null;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: AppColors.debt,
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.debtDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
      ),
    ],
  );
}
