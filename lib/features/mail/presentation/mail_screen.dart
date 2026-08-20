import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../franchise/application/current_franchise_provider.dart';
import '../../franchise/domain/franchise.dart';
import '../../franchise/onboarding/onboarding_screen.dart';
import '../../franchise/presentation/team_roster_screen.dart';
import '../../market/presentation/player_market_screen.dart';
import '../../player/domain/position.dart';
import '../../player/domain/player_injury.dart';
import '../../player/domain/retirement_reason.dart';
import '../../player/presentation/retirement_decision_screen.dart';
import '../../season/domain/game_day.dart';
import '../../season/presentation/all_star_game_result_screen.dart';
import '../../season/presentation/skills_competition_result_screen.dart';
import '../../training/presentation/training_report_screen.dart';
import '../application/mailbox.dart';
import '../domain/mail_item.dart';

/// The GM's inbox -- replaces the old, purely-passive `NewsScreen` (a
/// direct GM ask: "drop the News button off the home screen, should be
/// replaced with a Mail button"). Lists everything [mailboxFor] derives
/// for the current franchise: proactive [AssistantGmMailItem]s first,
/// then every [TrainingReportMailItem] newest week first -- the same
/// feed the old News tab showed, just no longer the only thing living
/// here.
class MailScreen extends ConsumerWidget {
  const MailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franchiseState = ref.watch(currentFranchiseProvider);

    return switch (franchiseState) {
      AsyncData(:final value?) => _MailInbox(franchise: value),
      AsyncData() => const _NoFranchiseView(),
      AsyncError() => const ErrorStateView(
        message: 'Could not load your franchise save.',
      ),
      _ => const LoadingView(message: 'Loading your mail…'),
    };
  }
}

class _NoFranchiseView extends StatelessWidget {
  const _NoFranchiseView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.mail_outline,
      message: 'Create an expansion franchise to start receiving mail.',
      action: FilledButton(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        },
        child: const Text('Create Expansion Franchise'),
      ),
    );
  }
}

class _MailInbox extends ConsumerWidget {
  const _MailInbox({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = mailboxFor(franchise);

    if (items.isEmpty) {
      return const EmptyStateView(
        icon: Icons.mail_outline,
        message:
            'No mail yet -- check back once your team starts training '
            'and playing games.',
      );
    }

    return ListView(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _MailRow(franchise: franchise, item: items[i]),
          if (i != items.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MailRow extends ConsumerWidget {
  const _MailRow({required this.franchise, required this.item});

  final Franchise franchise;
  final MailItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = !franchise.readMailIds.contains(item.id);
    final item0 = item;

    final (from, icon, preview) = switch (item0) {
      AssistantGmMailItem() => ('Assistant GM', Icons.mail_outline, item0.body),
      TrainingReportMailItem() => (
        'Training Staff',
        Icons.fitness_center_outlined,
        item0.report.results.isEmpty
            ? 'No one moved the needle this week.'
            : '${item0.report.results.length} player'
                  '${item0.report.results.length == 1 ? '' : 's'} changed.',
      ),
      AllStarSelectionMailItem() => (
        'League Office',
        Icons.campaign_outlined,
        item0.selections.isEmpty
            ? 'No one from our roster earned a nod this year.'
            : '${item0.selections.length} of our own selected: '
                  '${item0.selections.map((p) => p.name).join(', ')}',
      ),
      SkillsCompetitionMailItem() => (
        'League Office',
        Icons.stars_outlined,
        'Results are in for Full Press Frenzy, H-O-R-S-E, and the '
            'Defensive Skills Challenge.',
      ),
      AllStarGameMailItem() => (
        'League Office',
        Icons.emoji_events_outlined,
        'Final: ${item0.playedGame.homeScore}-${item0.playedGame.awayScore}.',
      ),
      RetirementDecisionMailItem() => (
        'Coaching Staff',
        Icons.watch_later_outlined,
        item0.pending.reason.label,
      ),
      LeagueRetirementsMailItem() => (
        'Assistant GM',
        Icons.event_busy_outlined,
        item0.retirements.length == 1
            ? '1 player around the league retired this off-season.'
            : '${item0.retirements.length} players around the league '
                  'retired this off-season.',
      ),
      RosterLegalityMailItem() => (
        'Assistant GM',
        Icons.warning_amber_outlined,
        item0.legality.violationMessages.first,
      ),
      InjuryReportMailItem() => (
        'Assistant GM',
        Icons.local_hospital_outlined,
        item0.entries.length == 1
            ? '1 new injury around the league today.'
            : '${item0.entries.length} new injuries around the league '
                  'today.',
      ),
      InjuryRecoveredMailItem() => (
        'Assistant GM',
        Icons.check_circle_outline,
        '${item0.player.name} is fully healed and still parked in '
            'Reserve/Inactive.',
      ),
    };

    return AppCard(
      child: InkWell(
        onTap: () async {
          await ref
              .read(currentFranchiseProvider.notifier)
              .markMailRead(item0.id);
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => switch (item0) {
                AssistantGmMailItem() => _AssistantGmMailDetailScreen(
                  franchise: franchise,
                  item: item0,
                ),
                TrainingReportMailItem() => TrainingReportScreen(
                  franchise: franchise,
                  report: item0.report,
                ),
                AllStarSelectionMailItem() => _AllStarSelectionMailDetailScreen(
                  franchise: franchise,
                  item: item0,
                ),
                SkillsCompetitionMailItem() => SkillsCompetitionResultScreen(
                  franchise: franchise,
                  result: item0.result,
                ),
                AllStarGameMailItem() => AllStarGameResultScreen(
                  franchise: franchise,
                  playedGame: item0.playedGame,
                  squads: item0.squads,
                ),
                RetirementDecisionMailItem() => RetirementDecisionScreen(
                  franchise: franchise,
                  item: item0,
                ),
                LeagueRetirementsMailItem() =>
                  _LeagueRetirementsMailDetailScreen(
                    franchise: franchise,
                    item: item0,
                  ),
                RosterLegalityMailItem() => _RosterLegalityMailDetailScreen(
                  franchise: franchise,
                  item: item0,
                ),
                InjuryReportMailItem() => _InjuryReportMailDetailScreen(
                  franchise: franchise,
                  item: item0,
                ),
                InjuryRecoveredMailItem() => _InjuryRecoveredMailDetailScreen(
                  franchise: franchise,
                  item: item0,
                ),
              },
            ),
          );
        },
        child: Row(
          children: [
            // A filled dot, not color alone, marks unread -- the same
            // "never rely on color alone" rule every other status
            // indicator in this app follows.
            if (isUnread) ...[
              Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
            ] else
              const SizedBox(width: 8 + AppSpacing.xs),
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item0.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'From $from',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// An [AssistantGmMailItem] opened full-screen, styled like a real email
/// (To/From/Subject header block, then the message body) -- a direct GM
/// ask: "That note should show up in Mail, and look kind of like an
/// email, you know?"
class _AssistantGmMailDetailScreen extends StatelessWidget {
  const _AssistantGmMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final AssistantGmMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    _MailHeaderRow(label: 'From', value: 'Assistant GM'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(item.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PlayerMarketScreen(franchise: franchise),
                    ),
                  );
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Open Player Market'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An [AllStarSelectionMailItem] opened full-screen -- the same real-email
/// styling every other mail detail screen uses, "From" the League Office
/// (same source [SkillsCompetitionMailItem]/[AllStarGameMailItem] already
/// use for All-Star week announcements, not the Assistant GM) since this
/// is roster news breaking league-wide, not a note from the GM's own
/// staff. A direct GM ask (2026-08-20): "At the start of the all star
/// break, I should get an email telling me if any of my players were
/// chosen."
class _AllStarSelectionMailDetailScreen extends StatelessWidget {
  const _AllStarSelectionMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final AllStarSelectionMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selections = item.selections;
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    const _MailHeaderRow(label: 'From', value: 'League Office'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(
                      selections.isEmpty
                          ? 'This year\'s All-Star squads have been '
                                'announced. No one from ${franchise.team.name} '
                                'made the cut -- keep building, there\'s '
                                'always next season.'
                          : selections.length == 1
                          ? 'This year\'s All-Star squads have been '
                                'announced, and we\'ve got one of our own '
                                'in the game:'
                          : 'This year\'s All-Star squads have been '
                                'announced, and we\'ve got '
                                '${selections.length} of our own in the '
                                'game:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (selections.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      for (final player in selections)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '⭐ ${player.name} '
                            '(${player.primaryPosition.abbreviation})',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SkillsCompetitionResultScreen(
                        franchise: franchise,
                        result: item.result,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.stars_outlined),
                label: const Text('View Skills Competition'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [LeagueRetirementsMailItem] opened full-screen -- "From" the
/// Assistant GM (a direct GM ask, 2026-08-20: "an email from asst gm
/// notifying of all retirements"), one line per [LeagueRetirement], name
/// plus former team plus why. Deliberately no navigation button below the
/// message -- unlike [SkillsCompetitionMailItem]/[AllStarGameMailItem],
/// there's no dedicated result screen a retirement roundup could deep-link
/// into; the retired players themselves are gone from the league for
/// good, nothing left to tap through to.
class _LeagueRetirementsMailDetailScreen extends StatelessWidget {
  const _LeagueRetirementsMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final LeagueRetirementsMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retirements = item.retirements;
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    const _MailHeaderRow(label: 'From', value: 'Assistant GM'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(
                      retirements.length == 1
                          ? 'Boss -- one retirement to report from around '
                                'the league this off-season:'
                          : 'Boss -- ${retirements.length} retirements to '
                                'report from around the league this '
                                'off-season:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final retirement in retirements)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${retirement.primaryPosition.abbreviation} '
                              '${retirement.name} '
                              '(${retirement.teamAbbreviation})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              retirement.reason.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A [RosterLegalityMailItem] opened full-screen -- one line per
/// [RosterLegality.violationMessages] entry, plus a shortcut to the Team
/// Roster screen where the GM actually fixes it (2026-08-20, a direct GM
/// ask: "I feel like I should get an email right after the draft from
/// the asst gm"). Nothing here blocks anything -- same "notify, don't
/// enforce" posture the GM's own roster has always had
/// ([RosterLegality]'s own doc comment: "that's a self-inflicted
/// disadvantage, not something the game blocks").
class _RosterLegalityMailDetailScreen extends StatelessWidget {
  const _RosterLegalityMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final RosterLegalityMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = item.legality.violationMessages;
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    const _MailHeaderRow(label: 'From', value: 'Assistant GM'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(
                      messages.length == 1
                          ? 'Boss -- one roster legality issue to flag '
                                'before we go any further:'
                          : 'Boss -- ${messages.length} roster legality '
                                'issues to flag before we go any further:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final message in messages)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• $message',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamRosterScreen()),
                  );
                },
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Open Team Roster'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An [InjuryReportMailItem] opened full-screen -- one line per league
/// injury from that game day, its own team and severity shown plainly
/// (2026-08-20, following the injuries design pass -- "for flavor text
/// vs formula, I'm fine with just facts only" already set the tone for
/// this whole system's UI).
class _InjuryReportMailDetailScreen extends StatelessWidget {
  const _InjuryReportMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final InjuryReportMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = item.entries;
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    const _MailHeaderRow(label: 'From', value: 'Assistant GM'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    _MailHeaderRow(
                      label: 'Date',
                      value: formatFictionalDate(item.week, item.day),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(
                      entries.length == 1
                          ? 'Boss -- one injury to report from around the '
                                'league:'
                          : 'Boss -- ${entries.length} injuries to report '
                                'from around the league:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.name} (${entry.teamAbbreviation})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${entry.severity.label} -- '
                              '${entry.severity.baseDurationGames} games',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An [InjuryRecoveredMailItem] opened full-screen -- a plain reminder
/// that [InjuryRecoveredMailItem.player] is healthy again but still
/// sitting in Reserve/Inactive, plus a shortcut to actually move them
/// back (2026-08-20, a direct GM ask: "so that you have a reminder to put
/// them back in the active roster if you want"). Nothing here forces the
/// move -- same "notify, don't enforce" posture [RosterLegalityMailItem]
/// already has.
class _InjuryRecoveredMailDetailScreen extends StatelessWidget {
  const _InjuryRecoveredMailDetailScreen({
    required this.franchise,
    required this.item,
  });

  final Franchise franchise;
  final InjuryRecoveredMailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MailHeaderRow(label: 'To', value: franchise.gmName),
                    const _MailHeaderRow(label: 'From', value: 'Assistant GM'),
                    _MailHeaderRow(label: 'Subject', value: item.subject),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(height: 1),
                    ),
                    Text(
                      'Boss -- ${item.player.name} is fully recovered, but '
                      'still parked in Reserve/Inactive. Move her back to '
                      'the active roster whenever you\'re ready.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TeamRosterScreen()),
                  );
                },
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Open Team Roster'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MailHeaderRow extends StatelessWidget {
  const _MailHeaderRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
