import 'dart:io';
import 'dart:typed_data';

import 'portrait_cache.dart';

final _validId = RegExp(r'^[A-Za-z0-9_-]+$');

void _requireValidId(String value, String name) {
  if (!_validId.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'must be alphanumeric, "-" or "_"');
  }
}

/// [PortraitCache] backed by PNG files in a device directory, one file per
/// save+key at `saves/<saveId>/portraits/<key>.png`. Writes go through a
/// temp-file-then-rename, same as [FileSaveRepository], so a crash mid-write
/// can't leave a corrupt cache entry.
class FilePortraitCache implements PortraitCache {
  FilePortraitCache({required this.resolveBaseDirectory});

  final Future<Directory> Function() resolveBaseDirectory;

  Future<Directory> _directoryFor(String saveId) async {
    _requireValidId(saveId, 'saveId');
    final base = await resolveBaseDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}saves${Platform.pathSeparator}'
      '$saveId${Platform.pathSeparator}portraits',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _fileFor(Directory dir, String key) {
    _requireValidId(key, 'key');
    return File('${dir.path}${Platform.pathSeparator}$key.png');
  }

  @override
  Future<Uint8List?> read({required String saveId, required String key}) async {
    final file = _fileFor(await _directoryFor(saveId), key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> write({
    required String saveId,
    required String key,
    required Uint8List pngBytes,
  }) async {
    final dir = await _directoryFor(saveId);
    final file = _fileFor(dir, key);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsBytes(pngBytes, flush: true);
    await tempFile.rename(file.path);
  }
}
