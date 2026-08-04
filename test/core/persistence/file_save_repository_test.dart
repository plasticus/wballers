import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/file_save_repository.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';

void main() {
  late Directory tempDir;
  late FileSaveRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wballers_save_test_');
    repository = FileSaveRepository(resolveBaseDirectory: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('readSave returns null for a save that was never written', () async {
    expect(await repository.readSave('missing'), isNull);
  });

  test('writeSave then readSave round-trips the content', () async {
    await repository.writeSave('franchise-1', '{"hello":"world"}');

    expect(await repository.readSave('franchise-1'), '{"hello":"world"}');
  });

  test('writeSave overwrites an existing save', () async {
    await repository.writeSave('franchise-1', 'first');
    await repository.writeSave('franchise-1', 'second');

    expect(await repository.readSave('franchise-1'), 'second');
  });

  test('listSaveIds reports every written save and nothing else', () async {
    await repository.writeSave('franchise-1', 'a');
    await repository.writeSave('franchise-2', 'b');

    expect(
      await repository.listSaveIds(),
      containsAll(['franchise-1', 'franchise-2']),
    );
    expect(await repository.listSaveIds(), hasLength(2));
  });

  test('deleteSave removes a save', () async {
    await repository.writeSave('franchise-1', 'a');
    await repository.deleteSave('franchise-1');

    expect(await repository.readSave('franchise-1'), isNull);
    expect(await repository.listSaveIds(), isEmpty);
  });

  test('deleteSave on a missing save does not throw', () async {
    await repository.deleteSave('never-existed');
  });

  test('rejects save ids that could escape the saves directory', () async {
    expect(() => repository.writeSave('../escape', 'x'), throwsArgumentError);
    expect(() => repository.readSave('nested/path'), throwsArgumentError);
  });

  test(
    'a save survives being re-opened as a new repository instance',
    () async {
      await repository.writeSave('franchise-1', 'persisted');

      final reopened = FileSaveRepository(
        resolveBaseDirectory: () async => tempDir,
      );
      expect(await reopened.readSave('franchise-1'), 'persisted');
    },
  );

  test(
    'SaveEnvelope round-trips schema version and payload through the repository',
    () async {
      const envelope = SaveEnvelope(
        schemaVersion: 1,
        payload: {'franchiseName': 'Test Club', 'wins': 0},
      );

      await repository.writeSave('franchise-1', envelope.toJson());

      final raw = await repository.readSave('franchise-1');
      final restored = SaveEnvelope.fromJson(raw!);

      expect(restored.schemaVersion, 1);
      expect(restored.payload, {'franchiseName': 'Test Club', 'wins': 0});
    },
  );
}
