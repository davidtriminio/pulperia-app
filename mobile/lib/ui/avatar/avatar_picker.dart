import 'package:flutter/material.dart';

import '../../domain/avatar/avatar.dart';
import '../../l10n/strings.dart';
import 'avatar_view.dart';
import 'hex_color.dart';

/// Selector de avatar: se elige un personaje, un tono de piel y un fondo. No
/// se puede continuar hasta tener los tres (RF-16), y se indica qué falta.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({super.key, this.initial, required this.onContinue});

  /// Avatar actual al editar un cliente; `null` al crear uno nuevo.
  final Avatar? initial;

  /// Se llama con el avatar completo al pulsar "Continuar".
  final ValueChanged<Avatar> onContinue;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _characterId;
  String? _skinId;
  String? _backgroundId;

  @override
  void initState() {
    super.initState();
    _characterId = widget.initial?.characterId;
    _skinId = widget.initial?.skinId;
    _backgroundId = widget.initial?.backgroundId;
  }

  bool get _complete =>
      _characterId != null && _skinId != null && _backgroundId != null;

  Avatar _preview({String? character, String? skin, String? background}) =>
      Avatar(
        // Un id vacío se dibuja con el marcador neutro de AvatarView.
        characterId: character ?? _characterId ?? '',
        // Sin tono elegido se dibuja con uno medio, no en gris.
        skinId: skin ?? _skinId ?? AvatarPalette.skinTones[1].id,
        backgroundId: background ?? _backgroundId ?? '',
      );

  @override
  Widget build(BuildContext context) {
    final missing = [
      if (_characterId == null) Strings.avatarMissingCharacter,
      if (_skinId == null) Strings.avatarMissingSkin,
      if (_backgroundId == null) Strings.avatarMissingBackground,
    ];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: AvatarView(avatar: _preview(), size: 112)),
                const SizedBox(height: 16),
                _Section(
                  title: Strings.avatarCharacter,
                  children: [
                    for (final id in AvatarPalette.characterIds)
                      _Tile(
                        tileKey: 'pick-$id',
                        selected: _characterId == id,
                        onTap: () => setState(() => _characterId = id),
                        child: AvatarView(
                          avatar: _preview(character: id),
                          size: 52,
                        ),
                      ),
                  ],
                ),
                _Section(
                  title: Strings.avatarSkin,
                  children: [
                    for (final s in AvatarPalette.skinTones)
                      _Tile(
                        tileKey: 'pick-${s.id}',
                        selected: _skinId == s.id,
                        onTap: () => setState(() => _skinId = s.id),
                        child: _Swatch(hexColor(s.hex)),
                      ),
                  ],
                ),
                _Section(
                  title: Strings.avatarBackground,
                  children: [
                    for (final b in AvatarPalette.backgrounds)
                      _Tile(
                        tileKey: 'pick-${b.id}',
                        selected: _backgroundId == b.id,
                        onTap: () => setState(() => _backgroundId = b.id),
                        child: _Swatch(hexColor(b.hex)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final text in missing)
                Text(
                  text,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('avatar-continue'),
                onPressed: _complete
                    ? () => widget.onContinue(
                        Avatar(
                          characterId: _characterId!,
                          skinId: _skinId!,
                          backgroundId: _backgroundId!,
                        ),
                      )
                    : null,
                child: const Text(Strings.continueAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String tileKey;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey(tileKey),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 3,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    ),
  );
}
