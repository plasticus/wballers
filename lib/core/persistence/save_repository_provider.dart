import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'file_save_repository.dart';
import 'save_repository.dart';

/// The app-wide [SaveRepository]. Override this in tests with an in-memory
/// or temp-directory-backed implementation instead of touching device
/// storage.
final saveRepositoryProvider = Provider<SaveRepository>((ref) {
  return FileSaveRepository(
    resolveBaseDirectory: getApplicationDocumentsDirectory,
  );
});
