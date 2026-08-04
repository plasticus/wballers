import 'package:womensbballmgr/core/persistence/save_repository.dart';

/// A [SaveRepository] backed by a plain [Map], for widget/provider tests
/// that need saves to work but shouldn't touch the real filesystem or a
/// platform channel (`path_provider`) that isn't available in `flutter
/// test`. Use [FileSaveRepository] with a temp directory instead when the
/// test is specifically about file persistence.
class InMemorySaveRepository implements SaveRepository {
  final Map<String, String> _saves = {};

  @override
  Future<void> deleteSave(String saveId) async {
    _saves.remove(saveId);
  }

  @override
  Future<List<String>> listSaveIds() async => _saves.keys.toList();

  @override
  Future<String?> readSave(String saveId) async => _saves[saveId];

  @override
  Future<void> writeSave(String saveId, String serializedSave) async {
    _saves[saveId] = serializedSave;
  }
}
