import 'dart:typed_data';

/// Local cache for rendered portrait PNGs -- purely derived, rebuildable
/// data (`PortraitAppearance`, `features/portrait`, is the source of
/// truth). Scoped to a save so different franchises' cached portraits
/// never collide.
abstract interface class PortraitCache {
  Future<Uint8List?> read({required String saveId, required String key});

  Future<void> write({
    required String saveId,
    required String key,
    required Uint8List pngBytes,
  });
}
