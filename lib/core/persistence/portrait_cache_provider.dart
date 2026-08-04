import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'file_portrait_cache.dart';
import 'portrait_cache.dart';

/// The app-wide [PortraitCache]. Override this in tests with an in-memory
/// or temp-directory-backed implementation instead of touching device
/// storage.
final portraitCacheProvider = Provider<PortraitCache>((ref) {
  return FilePortraitCache(
    resolveBaseDirectory: getApplicationDocumentsDirectory,
  );
});
