import 'package:flutter/material.dart';

import '../../domain/account/account_validation.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../l10n/strings.dart';
import '../theme.dart';

/// El texto en español de un error de validación de cuenta o negocio.
String accountErrorText(AccountError error) => switch (error) {
  AccountError.emailRequired => Strings.emailRequired,
  AccountError.emailInvalid => Strings.emailInvalid,
  AccountError.passwordRequired => Strings.passwordRequired,
  AccountError.passwordTooShort => Strings.passwordTooShort,
  AccountError.passwordTooLong => Strings.passwordTooLong,
  AccountError.businessNameRequired => Strings.businessNameRequired,
};

/// Marco común de las pantallas de entrada: fondo suave, contenido centrado con
/// un ancho máximo y desplazable, para que el teclado no tape nada.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.leading,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Opcional: un botón de volver u otra acción arriba.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null)
                    Align(alignment: Alignment.centerLeft, child: leading),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El error de la acción (credenciales malas, sin conexión...) justo encima del
/// botón, con el color de error de la app.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.debt.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.debt.withValues(alpha: 0.5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.debt),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: AppColors.debt)),
        ),
      ],
    ),
  );
}

/// El botón principal de un formulario: mientras se trabaja se ve el progreso
/// y no se puede pulsar otra vez.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
        : Text(label),
  );
}

/// Elegir cómo se manejan los montos y las cantidades del negocio (RF-7). Sin
/// valor inicial: el dueño decide, porque pasar de decimales a enteros después
/// no se permite (RF-9).
class ModeChoices extends StatelessWidget {
  const ModeChoices({
    super.key,
    required this.amount,
    required this.quantity,
    required this.onAmount,
    required this.onQuantity,
    this.amountError,
    this.quantityError,
  });

  final AmountMode? amount;
  final QuantityMode? quantity;
  final ValueChanged<AmountMode> onAmount;
  final ValueChanged<QuantityMode> onQuantity;
  final String? amountError;
  final String? quantityError;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Choice<AmountMode>(
        title: Strings.amountModeTitle,
        hint: Strings.amountModeHint,
        error: amountError,
        errorKey: const ValueKey('amount-mode-error'),
        selected: amount,
        onSelected: onAmount,
        options: const [
          (AmountMode.integer, Strings.amountModeInteger, 'amount-integer'),
          (
            AmountMode.twoDecimals,
            Strings.amountModeDecimals,
            'amount-two_decimals',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Choice<QuantityMode>(
        title: Strings.quantityModeTitle,
        hint: Strings.quantityModeHint,
        error: quantityError,
        errorKey: const ValueKey('quantity-mode-error'),
        selected: quantity,
        onSelected: onQuantity,
        options: const [
          (
            QuantityMode.integer,
            Strings.quantityModeInteger,
            'quantity-integer',
          ),
          (
            QuantityMode.fractional,
            Strings.quantityModeFractional,
            'quantity-fractional',
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        Strings.modesCannotReturn,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.hint,
    required this.error,
    required this.errorKey,
    required this.selected,
    required this.onSelected,
    required this.options,
  });

  final String title;
  final String hint;
  final String? error;
  final Key errorKey;
  final T? selected;
  final ValueChanged<T> onSelected;
  final List<(T, String, String)> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            selected: selected == null ? <T>{} : {selected as T},
            onSelectionChanged: (values) {
              if (values.isNotEmpty) {
                onSelected(values.first);
              }
            },
            segments: [
              for (final (value, label, keyName) in options)
                ButtonSegment<T>(
                  value: value,
                  label: Text(label, key: ValueKey(keyName)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (error != null)
          Text(
            error!,
            key: errorKey,
            style: const TextStyle(color: AppColors.debt, fontSize: 12),
          )
        else
          Text(hint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
