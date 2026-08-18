import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/domain/pending_retirement.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/mail/application/mailbox.dart';
import 'package:womensbballmgr/features/mail/domain/mail_item.dart';
import 'package:womensbballmgr/features/player/domain/retirement_reason.dart';
import 'package:womensbballmgr/features/season/domain/played_game.dart';
import 'package:womensbballmgr/features/season/domain/scheduled_game.dart';
import 'package:womensbballmgr/features/season/domain/skills_competition.dart';
import 'package:womensbballmgr/features/season/generation/all_star_generator.dart';
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

    test('swaps the roster-gap message for the roster-complete follow-up '
        'once the roster is full (2026-08-10, a direct GM ask)', () {
      final franchise = withFullActiveRoster(_franchise());

      final items = mailboxFor(franchise);

      expect(
        items.whereType<AssistantGmMailItem>().single.id,
        kRosterCompleteMailId,
      );
    });

    test('the roster-complete message stays in the inbox once the GM has '
        'read it -- it\'s just marked read, not removed (2026-08-15, a '
        'direct GM report: mail was disappearing right after being read)', () {
      final franchise = withFullActiveRoster(
        _franchise(),
      ).copyWithReadMailIds({kRosterCompleteMailId});

      final items = mailboxFor(franchise);

      expect(
        items.whereType<AssistantGmMailItem>().single.id,
        kRosterCompleteMailId,
      );
    });

    test('the roster-gap message keeps reappearing even after being read '
        '-- it\'s real re-derived state, not a one-time nudge', () {
      final franchise =
          _franchise() // still short a player
              .copyWithReadMailIds({kRosterGapMailId});

      final items = mailboxFor(franchise);

      expect(
        items.whereType<AssistantGmMailItem>().single.id,
        kRosterGapMailId,
      );
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

    test('sorts training reports newest-first', () {
      final franchise = _withTrainingReports(
        withFullActiveRoster(_franchise()),
        [1, 3, 2],
      );

      final items = mailboxFor(franchise);

      expect(
        items.whereType<AssistantGmMailItem>().single.id,
        kRosterCompleteMailId,
      );
      final reportItems = items.whereType<TrainingReportMailItem>().toList();
      expect(reportItems.map((i) => i.report.week), [3, 2, 1]);
    });

    test('the roster-complete message sinks below real mail once there is '
        'any -- unlike the roster-gap message, it isn\'t pinned forever '
        '(2026-08-18, a direct GM report: "Roster Set" was "clinging to '
        'the top of my inbox in perpetuity")', () {
      final franchise = _withTrainingReports(
        withFullActiveRoster(_franchise()),
        [1],
      );

      final items = mailboxFor(franchise);

      final rosterCompleteIndex = items.indexWhere(
        (item) =>
            item is AssistantGmMailItem && item.id == kRosterCompleteMailId,
      );
      final reportIndex = items.indexWhere(
        (item) => item is TrainingReportMailItem,
      );
      expect(reportIndex, lessThan(rosterCompleteIndex));
    });
  });

  group('All-Star week mail (2026-08-10, TODO.md items 5/6)', () {
    test('includes a SkillsCompetitionMailItem once the day resolves', () {
      final franchise = _franchise().copyWithSkillsCompetitionResult(
        SkillsCompetitionResult(
          week: kAllStarWeek,
          squads: {
            Conference.atlantic: List.generate(10, (i) => 'atl-$i'),
            Conference.pacific: List.generate(10, (i) => 'pac-$i'),
          },
          events: [
            for (final event in SkillsEvent.values)
              SkillsEventResult(
                event: event,
                standings: const [
                  SkillsEventStanding(playerId: 'atl-0', score: 90),
                  SkillsEventStanding(playerId: 'pac-0', score: 80),
                ],
              ),
          ],
        ),
      );

      final items = mailboxFor(franchise);

      expect(items.whereType<SkillsCompetitionMailItem>(), hasLength(1));
    });

    test('includes an AllStarGameMailItem once the game has been played', () {
      final base = _franchise();
      final playedGame = PlayedGame(
        game: const ScheduledGame(
          week: kAllStarWeek,
          day: kAllStarGameDay,
          homeTeamAbbreviation: kAtlanticAllStarsAbbreviation,
          awayTeamAbbreviation: kPacificAllStarsAbbreviation,
          type: GameType.allStarGame,
        ),
        homeScore: 120,
        awayScore: 110,
      );
      final franchise = base
          .copyWithSkillsCompetitionResult(
            SkillsCompetitionResult(
              week: kAllStarWeek,
              squads: {
                Conference.atlantic: List.generate(10, (i) => 'atl-$i'),
                Conference.pacific: List.generate(10, (i) => 'pac-$i'),
              },
              events: [
                for (final event in SkillsEvent.values)
                  SkillsEventResult(
                    event: event,
                    standings: const [
                      SkillsEventStanding(playerId: 'atl-0', score: 90),
                      SkillsEventStanding(playerId: 'pac-0', score: 80),
                    ],
                  ),
              ],
            ),
          )
          .copyWithSeasonProgress(
            base.seasonProgress.copyWithGameDayPlayed([playedGame]),
          );

      final items = mailboxFor(franchise);

      expect(items.whereType<AllStarGameMailItem>(), hasLength(1));
    });

    test('a later-week SkillsCompetitionMailItem sorts above an '
        'earlier-week TrainingReportMailItem -- newest mail on top '
        'regardless of type (2026-08-15, a direct GM ask)', () {
      final franchise = _withTrainingReports(_franchise(), [1])
          .copyWithSkillsCompetitionResult(
            SkillsCompetitionResult(
              week: 5,
              squads: {
                Conference.atlantic: List.generate(10, (i) => 'atl-$i'),
                Conference.pacific: List.generate(10, (i) => 'pac-$i'),
              },
              events: [
                for (final event in SkillsEvent.values)
                  SkillsEventResult(
                    event: event,
                    standings: const [
                      SkillsEventStanding(playerId: 'atl-0', score: 90),
                      SkillsEventStanding(playerId: 'pac-0', score: 80),
                    ],
                  ),
              ],
            ),
          );

      final items = mailboxFor(franchise);
      final reportlike = items
          .where(
            (item) =>
                item is SkillsCompetitionMailItem ||
                item is TrainingReportMailItem,
          )
          .toList();

      expect(reportlike.first, isA<SkillsCompetitionMailItem>());
      expect(reportlike.last, isA<TrainingReportMailItem>());
    });
  });

  group('RetirementDecisionMailItem mail (2026-08-11, 0D_Season_2_Roadmap.md: '
      'Aging & roster churn)', () {
    test('includes one RetirementDecisionMailItem per pending decision, '
        'resolving the real player off Franchise.roster', () {
      final base = withFullActiveRoster(_franchise());
      final target = base.roster.first.player;
      final franchise = base.copyWithPendingRetirements([
        PendingRetirement(
          playerId: target.id,
          reason: RetirementReason.hitMandatoryAge,
        ),
      ]);

      final items = mailboxFor(franchise);

      final retirementItems = items.whereType<RetirementDecisionMailItem>();
      expect(retirementItems, hasLength(1));
      expect(retirementItems.single.player.id, target.id);
      expect(
        retirementItems.single.pending.reason,
        RetirementReason.hitMandatoryAge,
      );
    });

    test('sorts before training reports -- genuinely actionable, unlike the '
        'roster-complete message (which is *not* pinned; see mailboxFor\'s '
        'own doc comment)', () {
      final base = _withTrainingReports(withFullActiveRoster(_franchise()), [
        1,
      ]);
      final target = base.roster.first.player;
      final franchise = base.copyWithPendingRetirements([
        PendingRetirement(
          playerId: target.id,
          reason: RetirementReason.hitMandatoryAge,
        ),
      ]);

      final items = mailboxFor(franchise);

      final retirementIndex = items.indexWhere(
        (item) => item is RetirementDecisionMailItem,
      );
      final firstReportIndex = items.indexWhere(
        (item) => item is TrainingReportMailItem,
      );
      expect(retirementIndex, lessThan(firstReportIndex));
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

    test('is 0 once the one always-present system message has been read '
        '-- a full roster with no training reports yet still has the '
        'roster-complete follow-up in it', () {
      final franchise = withFullActiveRoster(
        _franchise(),
      ).copyWithReadMailIds({kRosterCompleteMailId});
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
