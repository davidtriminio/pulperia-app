import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/client_repository.dart';
import '../../domain/avatar/avatar.dart';
import '../../domain/client/client_validation.dart';
import '../../domain/client/homonym.dart';
import '../../l10n/strings.dart';
import '../avatar/avatar_picker.dart';
import '../avatar/avatar_view.dart';
import '../theme.dart';
import 'client_messages.dart';
import 'clients_screen.dart';

/// Crear o editar un cliente (RF-14 a RF-19, RF-73, RF-74, RF-77). Con
/// [existing] edita ese cliente; sin él crea uno nuevo.
class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.existing});

  final Client? existing;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _note;
  Avatar? _avatar;
  bool _saving = false;
  final Map<ClientField, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _note = TextEditingController(text: c?.note ?? '');
    if (c != null) {
      _avatar = Avatar(
        characterId: c.characterId,
        skinId: c.skinId,
        backgroundId: c.backgroundId,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await Navigator.of(context).push<Avatar>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text(Strings.chooseAvatar)),
          body: AvatarPicker(
            initial: _avatar,
            onContinue: (avatar) => Navigator.of(context).pop(avatar),
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _avatar = picked;
        _errors.removeWhere(
          (field, _) => const {
            ClientField.avatarCharacter,
            ClientField.avatarSkin,
            ClientField.avatarBackground,
          }.contains(field),
        );
      });
    }
  }

  ClientDraft get _draft => ClientDraft(
    name: _name.text,
    phone: _phone.text,
    address: _address.text,
    note: _note.text,
    characterId: _avatar?.characterId,
    skinId: _avatar?.skinId,
    backgroundId: _avatar?.backgroundId,
  );

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final draft = _draft;
    final validation = validateClient(draft);
    if (validation is InvalidClient) {
      setState(() {
        _errors
          ..clear()
          ..addEntries(
            validation.issues.map(
              (i) => MapEntry(i.field, clientIssueMessage(i)),
            ),
          );
      });
      return;
    }
    setState(_errors.clear);

    final repository = ref.read(clientRepositoryProvider);
    final businessId = ref.read(activeBusinessIdProvider);
    final userId = ref.read(activeUserProvider).id;
    final existing = widget.existing;

    // El aviso de nombre repetido (RF-17) solo se da si el nombre cambia a
    // uno que ya usa otro cliente; el propio cliente no cuenta.
    final others = (await repository.clientNames(businessId))
        .where((c) => c.id != existing?.id)
        .map((c) => c.name);
    final nameChanged =
        existing == null ||
        existing.name.trim().toLowerCase() != draft.name.trim().toLowerCase();
    if (nameChanged && hasHomonym(draft.name, others)) {
      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(Strings.homonymTitle),
          content: const Text(Strings.homonymBody),
          actions: [
            TextButton(
              key: const ValueKey('homonym-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(Strings.cancel),
            ),
            FilledButton(
              key: const ValueKey('homonym-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(Strings.homonymConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() => _saving = true);
    final result = existing == null
        ? await repository.create(
            businessId: businessId,
            userId: userId,
            draft: draft,
          )
        : await repository.update(
            businessId: businessId,
            userId: userId,
            clientId: existing.id,
            draft: draft,
          );
    if (!mounted) {
      return;
    }

    switch (result) {
      case ClientSaved():
        ref.invalidate(activeClientsProvider);
        Navigator.of(context).pop(true);
      case ClientRejected(:final issues):
        setState(() {
          _saving = false;
          _errors
            ..clear()
            ..addEntries(
              issues.map((i) => MapEntry(i.field, clientIssueMessage(i))),
            );
        });
      case ClientNotFound():
        setState(() => _saving = false);
        _showMessage(Strings.clientNotFound);
      case ClientForbidden():
        setState(() => _saving = false);
        _showMessage(Strings.saveError);
    }
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final avatarErrors = [
      _errors[ClientField.avatarCharacter],
      _errors[ClientField.avatarSkin],
      _errors[ClientField.avatarBackground],
    ].nonNulls.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? Strings.newClient : Strings.editClient,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: InkWell(
                key: const ValueKey('avatar-field'),
                customBorder: const CircleBorder(),
                onTap: _pickAvatar,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.turquoise, width: 3),
                  ),
                  child: _avatar == null
                      ? const CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 32,
                            color: AppColors.navy,
                          ),
                        )
                      : AvatarView(avatar: _avatar!, size: 96),
                ),
              ),
            ),
            TextButton(
              onPressed: _pickAvatar,
              child: Text(
                _avatar == null ? Strings.chooseAvatar : Strings.changeAvatar,
              ),
            ),
            for (final message in avatarErrors)
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('field-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: Strings.fieldName,
                errorText: _errors[ClientField.name],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: Strings.fieldPhone,
                errorText: _errors[ClientField.phone],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-address'),
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: Strings.fieldAddress,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('field-note'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: Strings.fieldNote,
                errorText: _errors[ClientField.note],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _note,
                  builder: (context, value, _) {
                    final over = value.text.length > maxNoteLength;
                    final scheme = Theme.of(context).colorScheme;
                    return Text(
                      '${value.text.length}/$maxNoteLength',
                      key: const ValueKey('note-counter'),
                      style: TextStyle(
                        fontSize: 12,
                        color: over ? scheme.error : scheme.outline,
                        fontWeight: over ? FontWeight.w700 : FontWeight.w400,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('client-save'),
              onPressed: _saving ? null : _save,
              child: const Text(Strings.save),
            ),
          ],
        ),
      ),
    );
  }
}
