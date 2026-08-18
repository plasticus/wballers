import 'dart:typed_data';

import '../../../core/persistence/portrait_cache.dart';
import '../domain/portrait_appearance.dart';
import 'portrait_colors.dart';
import 'portrait_renderer.dart';

/// Builds the cache key `portraits.md`'s invalidation rules require: the
/// appearance's own [version], [contentFingerprint] (2026-08-18 -- see
/// [PortraitAppearance.contentFingerprint]'s own doc comment for the real
/// bug this closes), and [jersey] all change the rendered bytes, so a
/// stale cache hit on any of them would show the wrong portrait, not just
/// an error -- all 3 have to be part of the key.
String portraitCacheKey({
  required String ownerId,
  required int version,
  String contentFingerprint = '',
  RgbColor? jersey,
}) {
  final jerseyKey = jersey == null
      ? 'nojersey'
      : '${jersey.r}_${jersey.g}_${jersey.b}';
  return '$ownerId-v$version-$contentFingerprint-$jerseyKey';
}

/// Returns [appearance]'s rendered PNG, reading from [cache] when possible
/// and rendering (then populating the cache) on a miss. A missing or
/// corrupt cache entry never blocks display -- it just costs one
/// re-render, per `portraits.md`'s "a missing cache must never make a
/// player unusable."
Future<Uint8List> resolvePortraitPng({
  required PortraitCache cache,
  required String saveId,
  required String ownerId,
  required PortraitAppearance appearance,
  RgbColor? jersey,
}) async {
  final key = portraitCacheKey(
    ownerId: ownerId,
    version: appearance.version,
    contentFingerprint: appearance.contentFingerprint,
    jersey: jersey,
  );

  final cached = await cache.read(saveId: saveId, key: key);
  if (cached != null) {
    return cached;
  }

  final rendered = await renderPortraitPng(appearance, jersey: jersey);
  await cache.write(saveId: saveId, key: key, pngBytes: rendered);
  return rendered;
}
