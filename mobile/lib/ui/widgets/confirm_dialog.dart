import 'package:flutter/material.dart';

import '../theme.dart';

/// Aviso de confirmación con el mismo aspecto en toda la app: un ícono dentro
/// de un círculo, título y texto centrados, la acción principal arriba (botón
/// relleno) y la secundaria debajo (botón de texto).
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.confirmKey,
    this.cancelKey,
  });

  final IconData icon;
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final Key? confirmKey;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.turquoise.withValues(alpha: 0.2),
            child: Icon(icon, size: 28, color: AppColors.navy),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: confirmKey,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: cancelKey,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Muestra un [ConfirmDialog]. Devuelve `true` solo si se acepta; cancelar o
/// tocar fuera devuelve `false`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  Key? confirmKey,
  Key? cancelKey,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => ConfirmDialog(
      icon: icon,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmKey: confirmKey,
      cancelKey: cancelKey,
    ),
  );
  return result ?? false;
}
