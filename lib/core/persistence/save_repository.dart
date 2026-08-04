/// Contract for local franchise saves.
///
/// Domain code depends on this interface rather than a device or web storage
/// API. Android and web implementations can therefore use different storage
/// mechanisms without changing game rules.
abstract interface class SaveRepository {
  Future<List<String>> listSaveIds();

  Future<String?> readSave(String saveId);

  Future<void> writeSave(String saveId, String serializedSave);

  Future<void> deleteSave(String saveId);
}
