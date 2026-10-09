import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/account/account_validation.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../input_limits.dart';
import 'auth_widgets.dart';

/// Crear un negocio adicional del que el usuario es dueño (RF-79, RF-7, RF-78).
/// Requiere conexión. Va dentro de la pantalla de elección (no es una ruta
/// aparte): al crearlo, el negocio nuevo queda como el activo y se llama a
/// [onCreated].
class CreateBusinessView extends ConsumerStatefulWidget {
  const CreateBusinessView({
    super.key,
    required this.onCancel,
    required this.onCreated,
  });

  final VoidCallback onCancel;
  final VoidCallback onCreated;

  @override
  ConsumerState<CreateBusinessView> createState() => _CreateBusinessViewState();
}

class _CreateBusinessViewState extends ConsumerState<CreateBusinessView> {
  final _name = TextEditingController();
  AmountMode? _amount;
  QuantityMode? _quantity;
  AccountError? _nameError;
  bool _missingModes = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final nameError = validateBusinessName(_name.text);
    setState(() {
      _nameError = nameError;
      _missingModes = true;
      _error = null;
    });
    final amount = _amount;
    final quantity = _quantity;
    if (nameError != null || amount == null || quantity == null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .createBusiness(
            name: _name.text,
            amountMode: amount,
            quantityMode: quantity,
          );
      if (mounted) {
        widget.onCreated();
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthPage(
    key: const ValueKey('create-business-screen'),
    title: Strings.newBusinessTitle,
    subtitle: Strings.createAccountSubtitle,
    leading: IconButton(
      key: const ValueKey('create-business-back'),
      icon: const Icon(Icons.arrow_back),
      onPressed: _busy ? null : widget.onCancel,
    ),
    children: [
      TextField(
        key: const ValueKey('register-business-name'),
        controller: _name,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(InputLimits.name)],
        decoration: InputDecoration(
          labelText: Strings.fieldBusinessName,
          errorText: _nameError == null ? null : accountErrorText(_nameError!),
        ),
      ),
      const SizedBox(height: 20),
      ModeChoices(
        amount: _amount,
        quantity: _quantity,
        amountError: _missingModes && _amount == null
            ? Strings.amountModeRequired
            : null,
        quantityError: _missingModes && _quantity == null
            ? Strings.quantityModeRequired
            : null,
        onAmount: (mode) => setState(() => _amount = mode),
        onQuantity: (mode) => setState(() => _quantity = mode),
      ),
      const SizedBox(height: 20),
      if (_error != null) ...[
        KeyedSubtree(
          key: const ValueKey('auth-error'),
          child: ErrorBanner(_error!),
        ),
        const SizedBox(height: 12),
      ],
      KeyedSubtree(
        key: const ValueKey('business-create-submit'),
        child: BusyButton(
          label: Strings.createBusinessAction,
          busy: _busy,
          onPressed: _submit,
        ),
      ),
    ],
  );
}
