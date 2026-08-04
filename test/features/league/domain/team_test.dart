import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';

void main() {
  test('Conference.label is capitalized and says "Conference"', () {
    expect(Conference.atlantic.label, 'Atlantic Conference');
    expect(Conference.pacific.label, 'Pacific Conference');
  });
}
