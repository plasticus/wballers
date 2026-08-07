import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/mail/application/mailbox.dart';
import 'package:womensbballmgr/features/mail/domain/mail_item.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../../support/franchise_test_helpers.dart';

Franchise _franchise() => createExpansionFranchise(
  gmName: 'Jordan Ellis',
  clubName: 'Comets',
  homeCity: 'Springfield, IL',
  conference: Conference.atlantic,
  replacedTeamAbbreviation: 'BOS',
  colors: kStarterPalettes.first,
  emoji: '🏀',
  simulationSeed: 1,
);

void main() {
  group('mailboxFor', () {
    test('includes the roster-gap system message while the active roster '
        'is short a player', () {
      final franchise = _franchise(); // 11 players -- the real day-0 gap.

      final items = mailboxFor(franchise);

      expect(
        items.whereType<AssistantGmMailItem>().single.id,
        kRosterGapMailId,
      );
    });

    test('drops the roster-gap message once the roster is full', () {
      final franchise = withFullActiveRoster(_franchise());

      final items = mailboxFor(franchise);

      expect(items.whereType<AssistantGmMailItem>(), isEmpty);
    });

    test('includes one TrainingReportMailItem per report, system message '
        'first, then reports newest-week-first', () {
      // A fresh franchise (11 players, real Day-0 gap) with a few
      // training reports layered on top -- both mail types present.
      final withReports = _withTrainingReports(_franchise(), [1, 3, 2]);

      final items = mailboxFor(withReports);

      expect(items.first, isA<AssistantGmMailItem>());
      final reportItems = items.whereType<TrainingReportMailItem>().toList();
      expect(reportItems.map((i) => i.report.week), [3, 2, 1]);
    });

    test('sorts training reports newest-first even with no system message '
        'present', () {
      final franchise = _withTrainingReports(
        withFullActiveRoster(_franchise()),
        [1, 3, 2],
      );

      final items = mailboxFor(franchise);

      expect(items.whereType<AssistantGmMailItem>(), isEmpty);
      expect(items.map((i) => (i as TrainingReportMailItem).report.week), [
        3,
        2,
        1,
      ]);
    });
  });

  group('unreadMailCount', () {
    test('counts every mailbox item not yet in readMailIds', () {
      final franchise = _withTrainingReports(_franchise(), [1, 2]);
      // 1 system message + 2 reports = 3, none read yet.
      expect(unreadMailCount(franchise), 3);

      final oneRead = franchise.copyWithReadMailIds({kRosterGapMailId});
      expect(unreadMailCount(oneRead), 2);

      final allRead = franchise.copyWithReadMailIds({
        kRosterGapMailId,
        'training_report_1',
        'training_report_2',
      });
      expect(unreadMailCount(allRead), 0);
    });

    test('is 0 for a franchise with nothing in its inbox at all', () {
      final franchise = withFullActiveRoster(_franchise());
      expect(unreadMailCount(franchise), 0);
    });
  });

  group('assistantGmRosterGapMessage', () {
    test('names the pool\'s best-potential free agent', () {
      final franchise = _franchise();
      final best = franchise.freeAgents.reduce(
        (a, b) => a.ratings.potential > b.ratings.potential ? a : b,
      );

      expect(assistantGmRosterGapMessage(franchise), contains(best.name));
    });

    test('still reads sensibly with no free agents at all', () {
      final base = _franchise();
      final franchise = base.copyWithRosterAndFreeAgents(
        newRoster: base.roster,
        newFreeAgents: const [],
      );

      expect(
        assistantGmRosterGapMessage(franchise),
        contains('one player short'),
      );
    });
  });
}

Franchise _withTrainingReports(Franchise franchise, List<int> weeks) {
  var result = franchise;
  for (final week in weeks) {
    result = result.copyWithTrainingResult(
      newRoster: result.roster,
      newNextTrainingWeek: week + 1,
      newReport: TrainingReport(week: week, results: const []),
    );
  }
  return result;
}
