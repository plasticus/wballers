import 'dart:typed_data';

import 'package:womensbballmgr/core/persistence/portrait_cache.dart';

/// A [PortraitCache] backed by a plain [Map], for widget/provider tests
/// that need portrait caching to work but shouldn't touch the real
/// filesystem or a platform channel (`path_provider`) that isn't
/// available in `flutter test`. Use [FilePortraitCache] with a temp
/// directory instead when the test is specifically about file persistence.
class InMemoryPortraitCache implements PortraitCache {
  final Map<String, Uint8List> _entries = {};

  @override
  Future<Uint8List?> read({required String saveId, required String key}) async {
    return _entries['$saveId/$key'];
  }

  @override
  Future<void> write({
    required String saveId,
    required String key,
    required Uint8List pngBytes,
  }) async {
    _entries['$saveId/$key'] = pngBytes;
  }
}
