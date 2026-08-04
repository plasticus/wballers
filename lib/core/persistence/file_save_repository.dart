import 'dart:io';

import 'save_repository.dart';

final _validSaveId = RegExp(r'^[A-Za-z0-9_-]+$');

/// [SaveRepository] backed by JSON files in a device directory.
///
/// Each save is one file, `<saveId>.json`, inside [resolveBaseDirectory]'s
/// directory. Writes go through a temp-file-then-rename so a crash or kill
/// mid-write can never leave a half-written save on disk.
class FileSaveRepository implements SaveRepository {
  FileSaveRepository({required this.resolveBaseDirectory});

  final Future<Directory> Function() resolveBaseDirectory;
  Future<Directory>? _savesDirectory;

  Future<Directory> _directory() {
    return _savesDirectory ??= resolveBaseDirectory().then((base) async {
      final dir = Directory('${base.path}${Platform.pathSeparator}saves');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    });
  }

  File _fileFor(Directory dir, String saveId) {
    if (!_validSaveId.hasMatch(saveId)) {
      throw ArgumentError.value(
        saveId,
        'saveId',
        'must be alphanumeric, "-" or "_"',
      );
    }
    return File('${dir.path}${Platform.pathSeparator}$saveId.json');
  }

  @override
  Future<List<String>> listSaveIds() async {
    final dir = await _directory();
    final entries = await dir.list().toList();
    return entries
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.json'))
        .map((name) => name.substring(0, name.length - '.json'.length))
        .toList();
  }

  @override
  Future<String?> readSave(String saveId) async {
    final file = _fileFor(await _directory(), saveId);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> writeSave(String saveId, String serializedSave) async {
    final dir = await _directory();
    final file = _fileFor(dir, saveId);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(serializedSave, flush: true);
    await tempFile.rename(file.path);
  }

  @override
  Future<void> deleteSave(String saveId) async {
    final file = _fileFor(await _directory(), saveId);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
