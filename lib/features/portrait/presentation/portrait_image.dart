import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/portrait_cache_provider.dart';
import '../domain/portrait_appearance.dart';
import '../rendering/portrait_colors.dart';
import '../rendering/portrait_service.dart';

/// Displays a player's or coach's rendered portrait, or an accessible
/// placeholder when [appearance] is `null` or rendering hasn't finished --
/// per `portraits.md`'s "a missing cache must never make a player
/// unusable," a missing portrait is never an error state in the UI.
class PortraitImage extends ConsumerStatefulWidget {
  const PortraitImage({
    super.key,
    required this.saveId,
    required this.ownerId,
    required this.appearance,
    this.jersey,
    this.size = 48,
  });

  final String saveId;
  final String ownerId;
  final PortraitAppearance? appearance;

  /// The team jersey color to recolor an athlete's shirt collar with.
  /// Ignored for coach appearances.
  final RgbColor? jersey;
  final double size;

  @override
  ConsumerState<PortraitImage> createState() => _PortraitImageState();
}

class _PortraitImageState extends ConsumerState<PortraitImage> {
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    _startRender();
  }

  @override
  void didUpdateWidget(PortraitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saveId != widget.saveId ||
        oldWidget.ownerId != widget.ownerId ||
        oldWidget.appearance != widget.appearance ||
        oldWidget.jersey != widget.jersey) {
      _startRender();
    }
  }

  void _startRender() {
    final appearance = widget.appearance;
    _future = appearance == null
        ? null
        : resolvePortraitPng(
            cache: ref.read(portraitCacheProvider),
            saveId: widget.saveId,
            ownerId: widget.ownerId,
            appearance: appearance,
            jersey: widget.jersey,
          );
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return _PortraitFallback(size: widget.size);
    }

    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return _PortraitFallback(size: widget.size);
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

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'No portrait available',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(size / 8),
        ),
        child: Icon(
          Icons.person,
          size: size * 0.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
