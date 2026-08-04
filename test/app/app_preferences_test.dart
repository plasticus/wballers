import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/app/app_preferences.dart';

void main() {
  group('resolveTextScale', () {
    test('multiplies system scale by the user multiplier', () {
      expect(resolveTextScale(systemScale: 1.0, userMultiplier: 1.5), 1.5);
      expect(
        resolveTextScale(systemScale: 1.2, userMultiplier: 1.5),
        closeTo(1.8, 1e-9),
      );
    });

    test('clamps to kMaxTextScale when the combined scale is too large', () {
      expect(
        resolveTextScale(systemScale: 2.0, userMultiplier: 3.0),
        kMaxTextScale,
      );
    });

    test('clamps to kMinTextScale when the combined scale is too small', () {
      expect(
        resolveTextScale(systemScale: 0.5, userMultiplier: 0.5),
        kMinTextScale,
      );
    });
  });
}
