import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/file_portrait_cache.dart';

void main() {
  late Directory tempDir;
  late FilePortraitCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wballers_portrait_test_');
    cache = FilePortraitCache(resolveBaseDirectory: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('read returns null for a key that was never written', () async {
    expect(await cache.read(saveId: 'franchise-1', key: 'p1-v1'), isNull);
  });

  test('write then read round-trips the bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    await cache.write(saveId: 'franchise-1', key: 'p1-v1', pngBytes: bytes);

    expect(await cache.read(saveId: 'franchise-1', key: 'p1-v1'), bytes);
  });

  test('write overwrites an existing entry for the same key', () async {
    await cache.write(
      saveId: 'franchise-1',
      key: 'p1-v1',
      pngBytes: Uint8List.fromList([1]),
    );
    await cache.write(
      saveId: 'franchise-1',
      key: 'p1-v1',
      pngBytes: Uint8List.fromList([2]),
    );

    expect(
      await cache.read(saveId: 'franchise-1', key: 'p1-v1'),
      Uint8List.fromList([2]),
    );
  });

  test('different saves never see each other\'s entries', () async {
    await cache.write(
      saveId: 'franchise-1',
      key: 'p1-v1',
      pngBytes: Uint8List.fromList([1]),
    );

    expect(await cache.read(saveId: 'franchise-2', key: 'p1-v1'), isNull);
  });

  test('rejects ids that could escape the cache directory', () async {
    expect(
      () => cache.write(
        saveId: '../escape',
        key: 'p1-v1',
        pngBytes: Uint8List(0),
      ),
      throwsArgumentError,
    );
    expect(
      () => cache.read(saveId: 'franchise-1', key: 'nested/path'),
      throwsArgumentError,
    );
  });

  test(
    'a cached entry survives being re-opened as a new cache instance',
    () async {
      await cache.write(
        saveId: 'franchise-1',
        key: 'p1-v1',
        pngBytes: Uint8List.fromList([9, 9]),
      );

      final reopened = FilePortraitCache(
        resolveBaseDirectory: () async => tempDir,
      );
      expect(
        await reopened.read(saveId: 'franchise-1', key: 'p1-v1'),
        Uint8List.fromList([9, 9]),
      );
    },
  );
}
