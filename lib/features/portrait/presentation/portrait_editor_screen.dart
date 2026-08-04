import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../player/domain/player.dart';
import '../domain/portrait_appearance.dart';
import '../domain/portrait_manifest.dart';
import '../domain/portrait_weights.dart';
import '../generation/portrait_generator.dart' show kDefaultBaseSprite;
import '../persistence/portrait_catalog_loader.dart';
import '../rendering/portrait_colors.dart';
import '../rendering/portrait_renderer.dart';

/// Edit a player's or coach's portrait appearance (`portraits.md`). Pass
/// [playerId] to edit a roster player; omit it to edit the coach.
class PortraitEditorScreen extends ConsumerWidget {
  const PortraitEditorScreen({
    required this.franchise,
    this.playerId,
    super.key,
  });

  final Franchise franchise;
  final String? playerId;

  bool get _isCoach => playerId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(portraitManifestProvider);
    final weightsAsync = ref.watch(portraitWeightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCoach ? 'Edit Coach Portrait' : 'Edit Player Portrait'),
      ),
      body: SafeArea(
        child: switch ((manifestAsync, weightsAsync)) {
          (AsyncData(value: final manifest), AsyncData(value: final weights)) =>
            _EditorBody(
              franchise: franchise,
              playerId: playerId,
              manifest: manifest,
              weights: weights,
            ),
          (AsyncError(), _) || (_, AsyncError()) => const ErrorStateView(
            message: 'Could not load portrait options.',
          ),
          _ => const LoadingView(message: 'Loading portrait options…'),
        },
      ),
    );
  }
}

String _stripPngExtension(String filename) => filename.endsWith('.png')
    ? filename.substring(0, filename.length - '.png'.length)
    : filename;

String _humanize(String key) {
  return key
      .split('_')
      .map(
        (word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
      )
      .join(' ');
}

class _EditorBody extends ConsumerStatefulWidget {
  const _EditorBody({
    required this.franchise,
    required this.playerId,
    required this.manifest,
    required this.weights,
  });

  final Franchise franchise;
  final String? playerId;
  final PortraitManifest manifest;
  final PortraitWeights weights;

  bool get isCoach => playerId == null;

  @override
  ConsumerState<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends ConsumerState<_EditorBody> {
  late PortraitAppearance _draft;
  late TextEditingController _nicknameController;
  var _isSaving = false;

  /// `null` when editing the coach -- nicknames are earned through on-court
  /// achievements (`achievement.dart`), which only players have.
  Player? get _targetPlayer {
    if (widget.isCoach) return null;
    return widget.franchise.roster
        .firstWhere((m) => m.player.id == widget.playerId)
        .player;
  }

  /// Special/neon hair colors are unlock-only (`portraits.md`) -- gated on
  /// having earned at least one achievement, the only unlock mechanism that
  /// currently exists.
  bool get _specialColorsUnlocked =>
      _targetPlayer != null && _targetPlayer!.achievements.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _draft = _existingAppearance() ?? _defaultAppearance();
    _nicknameController = TextEditingController(
      text: _targetPlayer?.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  PortraitAppearance? _existingAppearance() {
    if (widget.isCoach) return widget.franchise.coach.appearance;
    return _targetPlayer!.appearance;
  }

  /// A starting point for a franchise old enough not to have generated
  /// portraits at all -- built straight from the loaded catalog rather
  /// than leaving the editor with nothing to show.
  PortraitAppearance _defaultAppearance() {
    final skinTone = widget.weights.skinTone.keys.first;
    return PortraitAppearance(
      baseSprite: kDefaultBaseSprite,
      skinTone: skinTone,
      hairColor: widget.weights.hairColorByTone[skinTone]!.keys.first,
      eyes: _stripPngExtension(widget.manifest.eyes.first),
      nose: _stripPngExtension(widget.manifest.nose.first),
      mouth: _stripPngExtension(widget.manifest.mouth.first),
      isCoach: widget.isCoach,
    );
  }

  void _apply(PortraitAppearance Function(PortraitAppearance) update) {
    setState(() => _draft = update(_draft));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final notifier = ref.read(currentFranchiseProvider.notifier);
    if (widget.isCoach) {
      await notifier.updateCoachAppearance(_draft);
    } else {
      await notifier.updatePlayerAppearance(widget.playerId!, _draft);
      final nickname = _nicknameController.text.trim();
      await notifier.updatePlayerNickname(
        widget.playerId!,
        nickname.isEmpty ? null : nickname,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jersey = widget.isCoach
        ? null
        : parseHexColor(widget.franchise.team.colors.primaryHex);
    final hairColorOptions = widget
        .weights
        .hairColorByTone[_draft.skinTone]!
        .keys
        .toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _LivePreview(appearance: _draft, jersey: jersey, size: 128),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              children: [
                if (!widget.isCoach) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nickname', style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: _nicknameController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'e.g. "The Wall"',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _requiredPicker(
                        theme: theme,
                        label: 'Skin tone',
                        value: _draft.skinTone,
                        keys: widget.weights.skinTone.keys.toList(),
                        onChanged: (tone) => _apply((d) {
                          final colorsForTone =
                              widget.weights.hairColorByTone[tone]!;
                          final keepsHairColor = colorsForTone.containsKey(
                            d.hairColor,
                          );
                          return d.copyWith(
                            skinTone: tone,
                            hairColor: keepsHairColor
                                ? null
                                : colorsForTone.keys.first,
                          );
                        }),
                      ),
                      _requiredPicker(
                        theme: theme,
                        label: 'Hair color',
                        value: _draft.hairColor,
                        keys: hairColorOptions,
                        onChanged: (color) =>
                            _apply((d) => d.copyWith(hairColor: color)),
                      ),
                      if (_specialColorsUnlocked)
                        _optionalPicker(
                          theme: theme,
                          label: 'Special hair color (unlocked)',
                          noneLabel: 'Use natural color',
                          value: _draft.topHairColor,
                          keys: widget.weights.neonHair.keys
                              .where((key) => key != 'natural')
                              .toList(),
                          onChanged: (color) =>
                              _apply((d) => d.copyWith(topHairColor: color)),
                        ),
                      _optionalPicker(
                        theme: theme,
                        label: 'Hair style',
                        noneLabel: 'Bald',
                        value: _draft.hair,
                        keys: widget.manifest.hair
                            .map(_stripPngExtension)
                            .toList(),
                        onChanged: (hair) =>
                            _apply((d) => d.copyWith(hair: hair)),
                      ),
                      _requiredPicker(
                        theme: theme,
                        label: 'Eyes',
                        value: _draft.eyes,
                        keys: widget.manifest.eyes
                            .map(_stripPngExtension)
                            .toList(),
                        onChanged: (eyes) =>
                            _apply((d) => d.copyWith(eyes: eyes)),
                      ),
                      _optionalPicker(
                        theme: theme,
                        label: 'Eyebrows',
                        noneLabel: 'None',
                        value: _draft.eyebrows,
                        keys: widget.manifest.eyebrows
                            .map(_stripPngExtension)
                            .toList(),
                        onChanged: (eyebrows) =>
                            _apply((d) => d.copyWith(eyebrows: eyebrows)),
                      ),
                      _requiredPicker(
                        theme: theme,
                        label: 'Nose',
                        value: _draft.nose,
                        keys: widget.manifest.nose
                            .map(_stripPngExtension)
                            .toList(),
                        onChanged: (nose) =>
                            _apply((d) => d.copyWith(nose: nose)),
                      ),
                      _requiredPicker(
                        theme: theme,
                        label: 'Mouth',
                        value: _draft.mouth,
                        keys: widget.manifest.mouth
                            .map(_stripPngExtension)
                            .toList(),
                        onChanged: (mouth) =>
                            _apply((d) => d.copyWith(mouth: mouth)),
                      ),
                      _optionalPicker(
                        theme: theme,
                        label: 'Accessories',
                        noneLabel: 'None',
                        value: _draft.accessories,
                        keys: widget.manifest.accessories
                            .map(_stripPngExtension)
                            .toList(),
                        onChanged: (accessories) =>
                            _apply((d) => d.copyWith(accessories: accessories)),
                      ),
                      if (widget.isCoach) ...[
                        _optionalPicker(
                          theme: theme,
                          label: 'Shoulders',
                          noneLabel: 'None',
                          value: _draft.shoulders,
                          keys: widget.manifest.shoulders
                              .map(_stripPngExtension)
                              .toList(),
                          onChanged: (shoulders) =>
                              _apply((d) => d.copyWith(shoulders: shoulders)),
                        ),
                        _optionalPicker(
                          theme: theme,
                          label: 'Hat',
                          noneLabel: 'None',
                          value: _draft.hat,
                          keys: widget.manifest.hats
                              .map(_stripPngExtension)
                              .toList(),
                          onChanged: (hat) =>
                              _apply((d) => d.copyWith(hat: hat)),
                        ),
                        _optionalPicker(
                          theme: theme,
                          label: 'Glasses',
                          noneLabel: 'None',
                          value: _draft.glasses,
                          keys: widget.manifest.glasses
                              .map(_stripPngExtension)
                              .toList(),
                          onChanged: (glasses) =>
                              _apply((d) => d.copyWith(glasses: glasses)),
                        ),
                        _optionalPicker(
                          theme: theme,
                          label: 'Facial hair',
                          noneLabel: 'None',
                          value: _draft.facial,
                          keys: widget.manifest.facial
                              .map(_stripPngExtension)
                              .toList(),
                          onChanged: (facial) =>
                              _apply((d) => d.copyWith(facial: facial)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save Portrait'),
          ),
        ],
      ),
    );
  }
}

Widget _requiredPicker({
  required ThemeData theme,
  required String label,
  required String value,
  required List<String> keys,
  required ValueChanged<String> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final key in keys)
              DropdownMenuItem(value: key, child: Text(_humanize(key))),
          ],
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ],
    ),
  );
}

Widget _optionalPicker({
  required ThemeData theme,
  required String label,
  required String noneLabel,
  required String? value,
  required List<String> keys,
  required ValueChanged<String?> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: null, child: Text(noneLabel)),
            for (final key in keys)
              DropdownMenuItem(value: key, child: Text(_humanize(key))),
          ],
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

/// Renders [appearance] directly (no cache -- a draft mid-edit shouldn't
/// pollute the save's portrait cache) and re-renders whenever it changes.
class _LivePreview extends StatefulWidget {
  const _LivePreview({
    required this.appearance,
    required this.jersey,
    required this.size,
  });

  final PortraitAppearance appearance;
  final RgbColor? jersey;
  final double size;

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _startRender();
  }

  @override
  void didUpdateWidget(_LivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance ||
        oldWidget.jersey != widget.jersey) {
      _startRender();
    }
  }

  void _startRender() {
    _future = renderPortraitPng(widget.appearance, jersey: widget.jersey);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 8),
          child: Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
