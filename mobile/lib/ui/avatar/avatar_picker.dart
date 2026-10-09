import 'package:flutter/material.dart';

import '../widgets/error_banner.dart';
import '../../domain/avatar/avatar.dart';
import '../../l10n/strings.dart';
import '../theme.dart';
import 'avatar_view.dart';
import 'hex_color.dart';

/// Selector de avatar en tres pasos: personaje, tono de piel y fondo (RF-14,
/// RF-72).
///
/// El tono de piel y el fondo vienen con un valor por defecto para que basten
/// un par de toques; el personaje no tiene valor por defecto y no se puede
/// avanzar sin elegirlo (RF-16), con un aviso que lo dice.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({super.key, this.initial, required this.onContinue});

  /// Avatar actual al editar un cliente; `null` al crear uno nuevo.
  final Avatar? initial;

  /// Se llama con el avatar completo al terminar el último paso.
  final ValueChanged<Avatar> onContinue;

  /// Tono de piel por defecto: el segundo, de tonalidad media-clara.
  static String get defaultSkinId => AvatarPalette.skinTones[1].id;

  /// Fondo por defecto: un azul claro que contrasta con todos los personajes.
  static String get defaultBackgroundId => AvatarPalette.backgrounds[7].id;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  static const _stepLabels = [
    Strings.avatarStepCharacter,
    Strings.avatarStepSkin,
    Strings.avatarStepBackground,
  ];

  int _step = 0;
  String? _characterId;
  late String _skinId;
  late String _backgroundId;

  @override
  void initState() {
    super.initState();
    _characterId = widget.initial?.characterId;
    _skinId = widget.initial?.skinId ?? AvatarPicker.defaultSkinId;
    _backgroundId =
        widget.initial?.backgroundId ?? AvatarPicker.defaultBackgroundId;
  }

  bool get _hasCharacter => _characterId != null;

  Avatar _avatar({String? character, String? skin, String? background}) =>
      Avatar(
        // Un id vacío se dibuja con el marcador neutro de AvatarView.
        characterId: character ?? _characterId ?? '',
        skinId: skin ?? _skinId,
        backgroundId: background ?? _backgroundId,
      );

  void _goTo(int step) {
    // Sin personaje no se puede pasar de la primera pantalla.
    if (step > 0 && !_hasCharacter) {
      return;
    }
    setState(() => _step = step);
  }

  void _finish() => widget.onContinue(
    Avatar(
      characterId: _characterId!,
      skinId: _skinId,
      backgroundId: _backgroundId,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _stepLabels.length - 1;

    return Column(
      children: [
        _PreviewCard(avatar: _avatar()),
        _StepHeader(
          step: _step,
          labels: _stepLabels,
          reached: _hasCharacter ? _stepLabels.length : 1,
          onTap: _goTo,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: SingleChildScrollView(
              key: ValueKey('avatar-step-body-$_step'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: switch (_step) {
                0 => _grid(
                  columns: 4,
                  children: [
                    for (final id in AvatarPalette.characterIds)
                      _Tile(
                        tileKey: 'pick-$id',
                        selected: _characterId == id,
                        size: 68,
                        onTap: () => setState(() => _characterId = id),
                        child: AvatarView(
                          avatar: _avatar(character: id),
                          size: 62,
                        ),
                      ),
                  ],
                ),
                1 => _grid(
                  columns: 3,
                  children: [
                    for (final s in AvatarPalette.skinTones)
                      _Tile(
                        tileKey: 'pick-${s.id}',
                        selected: _skinId == s.id,
                        size: 76,
                        onTap: () => setState(() => _skinId = s.id),
                        child: _Swatch(hexColor(s.hex), 66),
                      ),
                  ],
                ),
                _ => _grid(
                  columns: 4,
                  children: [
                    for (final b in AvatarPalette.backgrounds)
                      _Tile(
                        tileKey: 'pick-${b.id}',
                        selected: _backgroundId == b.id,
                        size: 68,
                        onTap: () => setState(() => _backgroundId = b.id),
                        child: _Swatch(hexColor(b.hex), 58),
                      ),
                  ],
                ),
              },
            ),
          ),
        ),
        _Footer(
          step: _step,
          isLast: isLast,
          canAdvance: _hasCharacter,
          hint: _step == 0 && !_hasCharacter
              ? Strings.avatarChooseCharacterHint
              : null,
          onBack: () => _goTo(_step - 1),
          onNext: () => _goTo(_step + 1),
          onFinish: _finish,
        ),
      ],
    );
  }

  Widget _grid({required int columns, required List<Widget> children}) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }
}

/// El avatar grande con lo elegido hasta ahora, sobre una tarjeta suave.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.avatar});

  final Avatar avatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F5F3), Color(0xFFDCE9F2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: AvatarView(
            key: const ValueKey('avatar-preview'),
            avatar: avatar,
            size: 124,
          ),
        ),
      ),
    );
  }
}

/// Los tres pasos como píldoras numeradas; el actual va resaltado y los
/// completados llevan una marca.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.labels,
    required this.reached,
    required this.onTap,
  });

  final int step;
  final List<String> labels;

  /// Cuántos pasos se pueden alcanzar ahora (sin personaje, solo el primero).
  final int reached;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _StepPill(
                index: i,
                label: labels[i],
                current: i == step,
                done: i < step,
                enabled: i < reached,
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.current,
    required this.done,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool current;
  final bool done;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = current
        ? AppColors.navy
        : done
        ? AppColors.turquoise
        : Colors.white;
    final foreground = current
        ? Colors.white
        : done
        ? AppColors.ink
        : theme.colorScheme.outline;

    return InkWell(
      key: ValueKey('avatar-step-$index'),
      borderRadius: BorderRadius.circular(24),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: current || done
                ? Colors.transparent
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            done
                ? Icon(Icons.check, size: 16, color: foreground)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.isLast,
    required this.canAdvance,
    required this.hint,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  final int step;
  final bool isLast;
  final bool canAdvance;
  final String? hint;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ErrorBanner(hint!),
              ),
            Row(
              children: [
                if (step > 0) ...[
                  TextButton(
                    key: const ValueKey('avatar-back'),
                    onPressed: onBack,
                    child: const Text(Strings.avatarBack),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: isLast
                      ? FilledButton(
                          key: const ValueKey('avatar-continue'),
                          onPressed: canAdvance ? onFinish : null,
                          child: const Text(Strings.avatarDone),
                        )
                      : FilledButton(
                          key: const ValueKey('avatar-next'),
                          onPressed: canAdvance ? onNext : null,
                          child: const Text(Strings.avatarNext),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Una opción tocable. La elegida lleva un aro y una marca visibles, además de
/// estar marcada como seleccionada para los lectores de pantalla.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.tileKey,
    required this.selected,
    required this.size,
    required this.onTap,
    required this.child,
  });

  final String tileKey;
  final bool selected;
  final double size;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey(tileKey),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.navy : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child,
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.check_circle,
                    key: ValueKey('selected-$tileKey'),
                    size: 22,
                    color: AppColors.navy,
                    shadows: const [Shadow(color: Colors.white, blurRadius: 6)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, this.size);

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    ),
  );
}
