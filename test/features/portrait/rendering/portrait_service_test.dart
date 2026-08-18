import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/portrait_cache.dart';
import 'package:womensbballmgr/features/portrait/domain/portrait_appearance.dart';
import 'package:womensbballmgr/features/portrait/generation/portrait_generator.dart';
import 'package:womensbballmgr/features/portrait/persistence/portrait_catalog_loader.dart';
import 'package:womensbballmgr/features/portrait/rendering/portrait_colors.dart';
import 'package:womensbballmgr/features/portrait/rendering/portrait_service.dart';

class _InMemoryPortraitCache implements PortraitCache {
  final Map<String, Uint8List> _store = {};
  int readCount = 0;
  int writeCount = 0;

  String _fullKey(String saveId, String key) => '$saveId/$key';

  @override
  Future<Uint8List?> read({required String saveId, required String key}) async {
    readCount++;
    return _store[_fullKey(saveId, key)];
  }

  @override
  Future<void> write({
    required String saveId,
    required String key,
    required Uint8List pngBytes,
  }) async {
    writeCount++;
    _store[_fullKey(saveId, key)] = pngBytes;
  }
}

const _appearance = PortraitAppearance(
  baseSprite: kDefaultBaseSprite,
  skinTone: 'medium',
  hairColor: 'black',
  eyes: 'eyes_1center',
  nose: 'nose_1',
  mouth: 'mouth_1',
  isCoach: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('portraitCacheKey', () {
    test('differs when version differs', () {
      final a = portraitCacheKey(ownerId: 'p1', version: 1);
      final b = portraitCacheKey(ownerId: 'p1', version: 2);
      expect(a, isNot(b));
    });

    test('differs when jersey color differs', () {
      final noJersey = portraitCacheKey(ownerId: 'p1', version: 1);
      final withJersey = portraitCacheKey(
        ownerId: 'p1',
        version: 1,
        jersey: const RgbColor(1, 2, 3),
      );
      final differentJersey = portraitCacheKey(
        ownerId: 'p1',
        version: 1,
        jersey: const RgbColor(4, 5, 6),
      );
      expect(noJersey, isNot(withJersey));
      expect(withJersey, isNot(differentJersey));
    });

    test('is stable for the same inputs', () {
      final a = portraitCacheKey(
        ownerId: 'p1',
        version: 1,
        jersey: const RgbColor(1, 2, 3),
      );
      final b = portraitCacheKey(
        ownerId: 'p1',
        version: 1,
        jersey: const RgbColor(1, 2, 3),
      );
      expect(a, b);
    });
  });

  group('resolvePortraitPng', () {
    test('renders and populates the cache on a miss', () async {
      final cache = _InMemoryPortraitCache();

      final bytes = await resolvePortraitPng(
        cache: cache,
        saveId: 'franchise-1',
        ownerId: 'p1',
        appearance: _appearance,
      );

      expect(bytes, isNotEmpty);
      expect(cache.writeCount, 1);
    });

    test('reads from the cache on a hit instead of re-rendering', () async {
      final cache = _InMemoryPortraitCache();

      final first = await resolvePortraitPng(
        cache: cache,
        saveId: 'franchise-1',
        ownerId: 'p1',
        appearance: _appearance,
      );
      final second = await resolvePortraitPng(
        cache: cache,
        saveId: 'franchise-1',
        ownerId: 'p1',
        appearance: _appearance,
      );

      expect(second, first);
      expect(cache.writeCount, 1);
      expect(cache.readCount, 2);
    });

    test(
      'a version bump forces a fresh render, not the stale cached PNG',
      () async {
        final cache = _InMemoryPortraitCache();

        final v1 = await resolvePortraitPng(
          cache: cache,
          saveId: 'franchise-1',
          ownerId: 'p1',
          appearance: _appearance,
        );
        final v2 = await resolvePortraitPng(
          cache: cache,
          saveId: 'franchise-1',
          ownerId: 'p1',
          appearance: const PortraitAppearance(
            version: 2,
            baseSprite: kDefaultBaseSprite,
            skinTone: 'medium',
            hairColor: 'black',
            eyes: 'eyes_1center',
            nose: 'nose_1',
            mouth: 'mouth_1',
            isCoach: false,
          ),
        );

        expect(cache.writeCount, 2);
        // Both renders are valid, independent PNGs -- not asserting on
        // pixel content, just that the second call didn't short-circuit to
        // the v1 cache entry.
        expect(v1, isNotEmpty);
        expect(v2, isNotEmpty);
      },
    );

    test('editing the appearance itself (same owner, same version) forces a '
        'fresh render too -- a real bug (2026-08-18, a direct GM report): '
        '"when I edit my coach\'s look, it doesn\'t seem like it sticks... '
        'only saves on that editor page, never shows up in actual usage" '
        '-- the cache key used to be keyed on version and owner id alone, '
        'both unchanged by an edit, so every screen kept reading the old '
        'cached PNG forever', () async {
      final cache = _InMemoryPortraitCache();

      await resolvePortraitPng(
        cache: cache,
        saveId: 'franchise-1',
        ownerId: 'coach-1',
        appearance: _appearance,
      );
      final edited = await resolvePortraitPng(
        cache: cache,
        saveId: 'franchise-1',
        ownerId: 'coach-1',
        appearance: _appearance.copyWith(skinTone: 'deep'),
      );

      expect(cache.writeCount, 2);
      expect(edited, isNotEmpty);
    });
  });

  test(
    'generated appearances resolve to a real cached PNG end-to-end',
    () async {
      final cache = _InMemoryPortraitCache();
      final weights = await loadPortraitWeights();
      final appearance = generatePortraitAppearance(
        Random(3),
        isCoach: false,
        weights: weights,
      );

      final bytes = await resolvePortraitPng(
        cache: cache,
        saveId: 'franchise-1',
        ownerId: 'generated-player',
        appearance: appearance,
      );

      expect(bytes, isNotEmpty);
    },
  );
}
