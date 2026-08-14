import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/onboarding/quick_start_teams.dart';
import 'package:womensbballmgr/features/league/domain/initial_league.dart';

void main() {
  test('contains exactly 5 presets', () {
    expect(kQuickStartTeams, hasLength(5));
  });

  test('every abbreviation is exactly three uppercase letters and unique '
      'within the set', () {
    final abbreviations = kQuickStartTeams.map((t) => t.abbreviation).toSet();
    expect(abbreviations, hasLength(5));

    for (final abbreviation in abbreviations) {
      expect(
        RegExp(r'^[A-Z]{3}$').hasMatch(abbreviation),
        isTrue,
        reason: '$abbreviation should be exactly three uppercase letters',
      );
    }
  });

  test('no abbreviation collides with kLeagueTeamPool', () {
    final poolAbbreviations = kLeagueTeamPool
        .map((t) => t.abbreviation)
        .toSet();
    for (final preset in kQuickStartTeams) {
      expect(
        poolAbbreviations.contains(preset.abbreviation),
        isFalse,
        reason:
            '${preset.abbreviation} (${preset.clubName}) collides with a '
            'kLeagueTeamPool entry',
      );
    }
  });

  test('no emoji collides with kLeagueTeamPool', () {
    final poolEmoji = kLeagueTeamPool.map((t) => t.emoji).toSet();
    for (final preset in kQuickStartTeams) {
      expect(
        poolEmoji.contains(preset.emoji),
        isFalse,
        reason:
            '${preset.emoji} (${preset.clubName}) collides with a '
            'kLeagueTeamPool entry',
      );
    }
  });

  test('no club name collides with kLeagueTeamPool', () {
    final poolNames = kLeagueTeamPool.map((t) => t.name).toSet();
    for (final preset in kQuickStartTeams) {
      expect(
        poolNames.contains(preset.clubName),
        isFalse,
        reason: '${preset.clubName} collides with a kLeagueTeamPool entry',
      );
    }
  });

  test('every preset has at least one non-empty GM name option', () {
    for (final preset in kQuickStartTeams) {
      expect(
        preset.gmNames,
        isNotEmpty,
        reason: '${preset.clubName} has no GM name options',
      );
      for (final name in preset.gmNames) {
        expect(name.trim(), isNotEmpty, reason: preset.clubName);
      }
    }
  });

  test('color hex strings parse to opaque colors', () {
    for (final preset in kQuickStartTeams) {
      expect(preset.colors.primary.a, 1.0, reason: preset.clubName);
      expect(preset.colors.secondary.a, 1.0, reason: preset.clubName);
      expect(preset.colors.accent.a, 1.0, reason: preset.clubName);
    }
  });
}
