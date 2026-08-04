import 'dart:convert';

/// Wraps a save payload with the schema version it was written under.
///
/// [SaveRepository] stores opaque strings; feature code is responsible for
/// wrapping its serialized state in a [SaveEnvelope] before writing, and for
/// migrating [payload] forward when [schemaVersion] is older than the
/// current schema. This keeps the storage layer free of game-schema
/// knowledge while still letting every save on disk declare its version.
class SaveEnvelope {
  const SaveEnvelope({required this.schemaVersion, required this.payload});

  factory SaveEnvelope.fromJson(String source) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return SaveEnvelope(
      schemaVersion: decoded['schemaVersion'] as int,
      payload: decoded['payload'] as Map<String, dynamic>,
    );
  }

  final int schemaVersion;
  final Map<String, dynamic> payload;

  String toJson() =>
      jsonEncode({'schemaVersion': schemaVersion, 'payload': payload});
}
