import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session_state.dart';
import '../../domain/account/account_validation.dart';
import '../../domain/business/amount_mode.dart';
import '../../domain/business/quantity_mode.dart';
import '../../l10n/error_messages.dart';
import '../../l10n/strings.dart';
import '../auth/auth_widgets.dart';
import '../input_limits.dart';

/// Ajustes del negocio (RF-7 a RF-9, RF-80): el nombre y cómo se manejan los
/// montos y las cantidades. Solo el dueño y con conexión (D-3). Pasar de
/// decimales a enteros no se ofrece (RF-9).
class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  late final TextEditingController _name;
  late final String _originalName;
  late final AmountMode _originalAmount;
  late final QuantityMode _originalQuantity;
  late AmountMode _amount;
  late QuantityMode _quantity;
  AccountError? _nameError;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(activeSessionProvider);
    _originalName = session.businessName;
    _originalAmount = session.amountMode;
    _originalQuantity = session.quantityMode;
    _name = TextEditingController(text: _originalName);
    _amount = _originalAmount;
    _quantity = _originalQuantity;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed =>
      _name.text.trim() != _originalName ||
      _amount != _originalAmount ||
      _quantity != _originalQuantity;

  Future<void> _save() async {
    if (_busy || !_changed) {
      return;
    }
    final nameError = validateBusinessName(_name.text);
    setState(() {
      _nameError = nameError;
      _error = null;
    });
    if (nameError != null) {
      return;
    }

    final name = _name.text.trim();
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .updateBusinessSettings(
            name: name != _originalName ? name : null,
            amountMode: _amount != _originalAmount ? _amount : null,
            quantityMode: _quantity != _originalQuantity ? _quantity : null,
          );
      if (mounted) {
        Navigator.of(context).pop();
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
  Widget build(BuildContext context) {
    final state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn || state.active == null) {
      return const SizedBox.shrink();
    }
    return Scaffold(
      key: const ValueKey('settings-screen'),
      appBar: AppBar(title: const Text(Strings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              key: const ValueKey('settings-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              inputFormatters: [
                LengthLimitingTextInputFormatter(InputLimits.name),
              ],
              decoration: InputDecoration(
                labelText: Strings.fieldBusinessName,
                error: fieldError(
                  _nameError == null ? null : accountErrorText(_nameError!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ModeChoices(
              amount: _amount,
              quantity: _quantity,
              amountIntegerEnabled: _originalAmount == AmountMode.integer,
              quantityIntegerEnabled: _originalQuantity == QuantityMode.integer,
              onAmount: (mode) => setState(() => _amount = mode),
              onQuantity: (mode) => setState(() => _quantity = mode),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              KeyedSubtree(
                key: const ValueKey('settings-error'),
                child: ErrorBanner(_error!),
              ),
              const SizedBox(height: 12),
            ],
            KeyedSubtree(
              key: const ValueKey('settings-save'),
              child: BusyButton(
                label: Strings.saveChanges,
                busy: _busy,
                onPressed: _save,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              Strings.settingsOnline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
