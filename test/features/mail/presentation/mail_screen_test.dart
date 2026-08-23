import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/persistence/save_envelope.dart';
import 'package:womensbballmgr/core/persistence/save_repository_provider.dart';
import 'package:womensbballmgr/features/franchise/application/current_franchise_provider.dart';
import 'package:womensbballmgr/features/franchise/domain/franchise.dart';
import 'package:womensbballmgr/features/franchise/onboarding/expansion_franchise_factory.dart';
import 'package:womensbballmgr/features/franchise/persistence/franchise_json.dart';
import 'package:womensbballmgr/features/league/domain/team.dart';
import 'package:womensbballmgr/features/mail/presentation/mail_screen.dart';
import 'package:womensbballmgr/features/training/domain/training_report.dart';

import '../../../support/franchise_test_helpers.dart';
import '../../../support/in_memory_save_repository.dart';

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

Future<InMemorySaveRepository> _seededRepository(Franchise franchise) async {
  final repository = InMemorySaveRepository();
  final envelope = SaveEnvelope(
    schemaVersion: 1,
    payload: franchiseToJson(franchise),
  );
  await repository.writeSave(kCurrentFranchiseSaveId, envelope.toJson());
  return repository;
}

void main() {
  testWidgets('shows the roster-complete follow-up once the roster is full and '
      'there are no training reports yet -- the inbox is never truly '
      'empty for a real franchise anymore (2026-08-10, a direct GM ask: '
      'a follow-up message after the roster-gap one gets resolved)', (
    tester,
  ) async {
    final franchise = withFullActiveRoster(_franchise());
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: MailScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Roster Set'), findsOneWidget);
    expect(find.textContaining('No mail yet'), findsNothing);
  });

  testWidgets('prompts to create a franchise when none exists', (tester) async {
    final repository = InMemorySaveRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: MailScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Expansion Franchise'), findsOneWidget);
  });

  testWidgets(
    'lists the Assistant GM message and training reports (newest first), '
    'unread ones bold',
    (tester) async {
      var franchise = _franchise(); // still short a player -- real gap.
      franchise = franchise.copyWithTrainingResult(
        newRoster: franchise.roster,
        newNextTrainingWeek: 2,
        newReport: const TrainingReport(week: 1, results: []),
      );
      franchise = franchise.copyWithReadMailIds({'training_report_1'});
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: MailScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last Roster Spot'), findsOneWidget);
      // Dated now (2026-08-23, a direct GM ask: "I think we need to start
      // dating emails") -- "From X" is a prefix of "From X · <date>", not
      // the whole row's text anymore.
      expect(find.textContaining('From Assistant GM'), findsOneWidget);
      expect(find.text('Week 1 Training Report'), findsOneWidget);
      expect(find.textContaining('From Training Staff'), findsOneWidget);

      // The unmarked-read system message is bold, the already-read
      // training report is not.
      final subjectText = tester.widget<Text>(find.text('Last Roster Spot'));
      final reportText = tester.widget<Text>(
        find.text('Week 1 Training Report'),
      );
      expect(subjectText.style?.fontWeight, FontWeight.bold);
      expect(reportText.style?.fontWeight, FontWeight.normal);
    },
  );

  testWidgets('tapping the Assistant GM message opens its email-styled detail, '
      'marks it read, and links to the Player Market', (tester) async {
    final franchise = _franchise();
    final repository = await _seededRepository(franchise);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: MailScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Last Roster Spot'));
    await tester.pumpAndSettle();

    // Email-styled To/From/Subject header block.
    expect(find.text('To'), findsOneWidget);
    expect(find.text(franchise.gmName), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('Assistant GM'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Open Player Market'), findsOneWidget);

    final saved = await repository.readSave(kCurrentFranchiseSaveId);
    final savedFranchise = franchiseFromJson(
      SaveEnvelope.fromJson(saved!).payload,
    );
    expect(savedFranchise.readMailIds, contains('assistant_gm_roster_gap'));
  });

  testWidgets(
    'tapping a training report opens its full report and marks it read',
    (tester) async {
      var franchise = withFullActiveRoster(_franchise());
      franchise = franchise.copyWithTrainingResult(
        newRoster: franchise.roster,
        newNextTrainingWeek: 2,
        newReport: const TrainingReport(week: 1, results: []),
      );
      final repository = await _seededRepository(franchise);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [saveRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: MailScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Week 1 Training Report'));
      await tester.pumpAndSettle();

      expect(find.text('Training Report'), findsOneWidget);
      expect(find.text('No one moved the needle this week.'), findsOneWidget);

      final saved = await repository.readSave(kCurrentFranchiseSaveId);
      final savedFranchise = franchiseFromJson(
        SaveEnvelope.fromJson(saved!).payload,
      );
      expect(savedFranchise.readMailIds, contains('training_report_1'));
    },
  );
}
