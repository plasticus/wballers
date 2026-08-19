import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/roster/domain/roster_membership.dart';

import 'portrait_test_helpers.dart';

/// A [franchiseForPortraitTests] fixture whose first roster player already
/// has [nickname] -- shared by the nickname-editing tests
/// (`portrait_editor_screen_nickname_*_test.dart`), each its own file per
/// this codebase's existing convention for portrait-editor tests (one
/// `testWidgets` per file -- packing several into one file made the 2nd+
/// test's real `rootBundle` asset load hang indefinitely, a real
/// `tester.runAsync` + platform-channel interaction issue, not something
/// a bigger fixed wait budget could fix).
Franchise franchiseForNicknameTests({required String nickname}) {
  final franchise = franchiseForPortraitTests();
  final first = franchise.roster.first;
  final withNickname = first.player.copyWithNickname(nickname);
  final rosterWithNickname = [
    RosterMembership(player: withNickname, status: first.status),
    ...franchise.roster.skip(1),
  ];
  return franchise.copyWithRoster(rosterWithNickname);
}
