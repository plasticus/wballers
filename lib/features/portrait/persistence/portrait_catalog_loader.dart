import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/portrait_manifest.dart';
import '../domain/portrait_weights.dart';

Future<PortraitManifest> loadPortraitManifest() async {
  final raw = await rootBundle.loadString('manifest.json');
  return portraitManifestFromJson(jsonDecode(raw) as Map<String, dynamic>);
}

Future<PortraitWeights> loadPortraitWeights() async {
  final raw = await rootBundle.loadString('weights.json');
  return portraitWeightsFromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Loaded once per app run -- this is static bundled content, not
/// per-save state.
final portraitManifestProvider = FutureProvider<PortraitManifest>((ref) {
  return loadPortraitManifest();
});

final portraitWeightsProvider = FutureProvider<PortraitWeights>((ref) {
  return loadPortraitWeights();
});
