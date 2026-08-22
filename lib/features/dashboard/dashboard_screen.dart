import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_spacing.dart';
import '../../core/widgets/ad_placement_placeholder.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/wbl_logo.dart';
import '../coach/presentation/available_head_coaches_screen.dart';
import '../draft/presentation/draft_day_screen.dart';
import '../franchise/application/current_franchise_provider.dart';
import '../franchise/domain/franchise.dart';
import '../franchise/onboarding/onboarding_screen.dart';
import '../franchise/presentation/main_menu_screen.dart';
import '../franchise/presentation/team_roster_screen.dart';
import '../guide/presentation/guide_screen.dart';
import '../league/domain/team.dart';
import '../league/league_screen.dart';
import '../mail/application/mailbox.dart';
import '../mail/domain/mail_item.dart';
import '../mail/presentation/mail_screen.dart';
import '../matchup/domain/defensive_tactic.dart';
import '../market/presentation/player_market_screen.dart';
import '../roster/domain/roster_legality.dart';
import '../roster/domain/roster_status.dart';
import '../season/application/franchise_rosters.dart';
import '../season/application/season_recap_history_provider.dart';
import '../season/domain/game_day.dart';
import '../season/domain/game_result.dart';
import '../season/domain/scheduled_game.dart';
import '../season/domain/season_progress.dart';
import '../season/domain/standings_entry.dart';
import '../season/generation/all_star_generator.dart';
import '../season/generation/continental_cup_generator.dart'
    show continentalCupEliminationRound;
import '../season/generation/postseason_generator.dart' show seasonChampion;
import '../season/generation/season_schedule_generator.dart'
    show kPreseasonWeek, weekLabel;
import '../season/presentation/all_star_game_result_screen.dart';
import '../season/presentation/game_result_screen.dart';
import '../season/presentation/match_preview_screen.dart';
import '../season/presentation/season_recap_history_screen.dart';
import '../season/presentation/season_recap_screen.dart';
import '../season/presentation/skills_competition_result_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../stats/presentation/stats_screen.dart';
import '../trade/domain/trade_window.dart';
import '../training/domain/training_report.dart';
import '../training/presentation/training_report_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _selectedIndex = 0;

  static const _titles = ['Dashboard', 'Team', 'League', 'Stats', 'Mail'];

  @override
  Widget build(BuildContext context) {
    // Automatic recovery for a save that fails to load -- most commonly
    // the active slot at app boot, but this covers any later transition
    // into AsyncError too (2026-08-10, a direct GM report: opening the
    // app to a franchise stuck failing to load had no way out before
    // this -- MainMenuScreen's own Delete button, added earlier the same
    // day, needs the GM to actually get there first). Fires once per
    // real state transition (ref.listen, not every rebuild), and only
    // while AppShell itself is mounted -- navigating away here removes
    // it from the tree, so there's no risk of it firing again once the
    // GM is already on MainMenuScreen picking a different slot.
    ref.listen<AsyncValue<Franchise?>>(currentFranchiseProvider, (
      previous,
      next,
    ) {
      if (!next.hasError) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainMenuScreen()),
          (route) => false,
        );
      });
    });

    final franchise = ref.watch(currentFranchiseProvider).value;
    final unreadCount = franchise == null ? 0 : unreadMailCount(franchise);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: WblLogo(size: 32),
        ),
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Game Guide',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GuideScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_selectedIndex) {
            0 => const DashboardScreen(),
            1 => const TeamRosterScreen(),
            2 => const LeagueScreen(),
            3 => const StatsScreen(),
            4 => const MailScreen(),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Team',
          ),
          const NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'League',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: _MailIcon(unreadCount: unreadCount, selected: false),
            selectedIcon: _MailIcon(unreadCount: unreadCount, selected: true),
            label: 'Mail',
          ),
        ],
      ),
    );
  }
}

/// A mail icon with a red unread-count badge (2026-08-07, a direct GM
/// ask) -- only shown once there's actually something unread, so an
/// empty inbox looks like every other plain nav icon.
class _MailIcon extends StatelessWidget {
  const _MailIcon({required this.unreadCount, required this.selected});

  final int unreadCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? Icons.mail : Icons.mail_outline);
    if (unreadCount == 0) return icon;
    return Badge(label: Text('$unreadCount'), child: icon);
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final franchiseState = ref.watch(currentFranchiseProvider);
    final hasFranchise =
        franchiseState is AsyncData<Franchise?> && franchiseState.value != null;

    // The ad placeholder stays pinned outside the scroll view; only the
    // content above it scrolls. A plain Column + Spacer here would overflow
    // at large text scales instead of scrolling, so this shape is load-bearing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title-screen hero only makes sense before a franchise
                // exists -- once the GM is actually managing a club, it just
                // pushes everything else down like a splash screen that
                // never went away.
                if (!hasFranchise) ...[
                  const Center(child: WblLogo(size: 96)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Women\'s Basketball Manager',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Build a franchise. Shape a league. Leave a legacy.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                switch (franchiseState) {
                  AsyncData(:final value?) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FranchiseSummaryCard(franchise: value),
                      if (_blockedByRosterGap(value)) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _AssistantGmMailCard(franchise: value),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _SeasonAdvanceCard(franchise: value),
                      if (_hasTrainingReportToShow(value)) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _TrainingReadyCard(franchise: value),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _RecentNewsCard(franchise: value),
                      const SizedBox(height: AppSpacing.lg),
                      const _SeasonRecapsCard(),
                    ],
                  ),
                  AsyncData() => const _NoFranchiseCard(),
                  AsyncError() => ErrorStateView(
                    message: 'Could not load your franchise save.',
                  ),
                  _ => const LoadingView(message: 'Loading your franchise…'),
                },
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AdPlacementPlaceholder(placement: 'Dashboard banner'),
      ],
    );
  }
}

class _NoFranchiseCard extends StatelessWidget {
  const _NoFranchiseCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No franchise yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Create an expansion club to receive your coach, your team identity, and a starting roster.',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              );
            },
            child: const Text('Create Expansion Franchise'),
          ),
        ],
      ),
    );
  }
}

class _FranchiseSummaryCard extends StatelessWidget {
  const _FranchiseSummaryCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = franchise.roster
        .where((m) => m.status == RosterStatus.active)
        .length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The chosen emoji standing in for a real team crest -- no
              // custom-logo-upload system exists, so this is the closest
              // thing the club has to one.
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: franchise.team.colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  franchise.team.emoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  franchise.team.name,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${franchise.team.location} · ${franchise.team.conference.label}',
          ),
          Text('GM ${franchise.gmName}'),
          Text('Head Coach ${franchise.coach.name}'),
          const SizedBox(height: AppSpacing.sm),
          Text('$activeCount players on the active roster'),
        ],
      ),
    );
  }
}

/// Whether a training week is still waiting to be resolved -- true once
/// [lastFullyCompletedWeek] has moved past [Franchise.nextTrainingWeek],
/// the same guard [runTraining] itself uses. In normal play this is
/// basically always false: [CurrentFranchiseNotifier.advanceGameDay]
/// already resolves every week the moment it completes
/// (`_catchUpTraining`'s doc comment). This only still fires for a save
/// that predates that auto-resolve, or anything else that moved
/// [Franchise.seasonProgress] some other way -- [_TrainingReadyCard]
/// falls back to actually resolving it on tap for exactly that case.
bool _isTrainingReportReady(Franchise franchise) {
  final week = lastFullyCompletedWeek(franchise.seasonProgress);
  return week != null && week >= franchise.nextTrainingWeek;
}

/// The most recently-resolved [TrainingReport] the GM hasn't opened yet,
/// if any -- `null` mail id lookup mirrors [unreadMailCount]/[mailboxFor]'s
/// own read-tracking, just narrowed to training reports since that's the
/// only kind of unread mail this card cares about surfacing. This is what
/// the Dashboard card points at in the normal case: the report already
/// exists (auto-resolved by [CurrentFranchiseNotifier.advanceGameDay]),
/// it just hasn't been seen yet.
TrainingReport? _newestUnreadTrainingReport(Franchise franchise) {
  final unread = [
    for (final report in franchise.trainingReports)
      if (!franchise.readMailIds.contains(trainingReportMailId(report.week)))
        report,
  ]..sort((a, b) => b.week.compareTo(a.week));
  return unread.isEmpty ? null : unread.first;
}

/// Whether [_TrainingReadyCard] has anything to show at all -- either an
/// unresolved week ([_isTrainingReportReady], the old-save fallback path)
/// or an already-resolved report the GM hasn't opened yet
/// ([_newestUnreadTrainingReport], the normal path now that training
/// auto-resolves).
bool _hasTrainingReportToShow(Franchise franchise) {
  return _isTrainingReportReady(franchise) ||
      _newestUnreadTrainingReport(franchise) != null;
}

/// "May 3 · Week 1" -- the current point on the fictional season calendar,
/// a direct GM ask (2026-08-09: "we need to see what the actual date is,
/// and what Week that is"). "Current" is the next game day still on the
/// schedule (what's coming up, the same day [_UpcomingGamesList] would
/// show first) -- once nothing's left to advance to, falls back to the
/// last day actually played, so a finished season still shows a real date
/// instead of nothing. `null` schedule (no game days at all) shouldn't
/// happen for a real franchise, but falls back to just [weekLabel] with no
/// date rather than crashing.
String _currentDateLabel(SeasonProgress progress) {
  final gameDays = gameDaysInOrder(progress.schedule);
  if (gameDays.isEmpty) return weekLabel(kPreseasonWeek);
  final (week, day) = progress.nextGameDayIndex < gameDays.length
      ? gameDays[progress.nextGameDayIndex]
      : gameDays.last;
  return '${formatFictionalDate(week, day)} · ${weekLabel(week)}';
}

int _activeRosterCount(Franchise franchise) =>
    franchise.roster.where((m) => m.status == RosterStatus.active).length;

/// Whether the Dashboard's own roster-gap mail card/advance-block should
/// show -- mirrors `current_franchise_provider.dart`'s `_blockedByRosterGap`
/// exactly ([isFranchiseDayZero], still short a player), which is the
/// real gate [advanceGameDay] itself enforces. This file's own two gates
/// (`_AssistantGmMailCard`'s visibility, [_SeasonAdvanceCard]'s button)
/// used to just check [_activeRosterCount] alone, with no Day-0 guard at
/// all, then later just `franchise.season == 0` -- both too loose,
/// wrongly resurrecting the Day-0 "sign a free agent" framing (and fully
/// blocking the Advance button) for any ordinary mid-season roster dip,
/// even well after the franchise's real Day 0 had passed (2026-08-20 and
/// 2026-08-21, 2 separate GM bug reports of the same underlying gap --
/// see [isFranchiseDayZero]'s own doc comment for the second one).
bool _blockedByRosterGap(Franchise franchise) =>
    isFranchiseDayZero(franchise) &&
    _activeRosterCount(franchise) < kActiveRosterSize;

/// "You need to hire a free agent before we can advance" -- a direct GM
/// ask for a real Day-0 hook: a fresh expansion roster starts one player
/// short of [kActiveRosterSize] on purpose
/// (`roster/generation/starting_roster_generator.dart`'s doc comment),
/// and the season genuinely can't advance until that gap is filled
/// (`CurrentFranchiseNotifier.advanceGameDay`'s own guard). Shown exactly
/// when [_blockedByRosterGap] is true -- Day 0 only, not just any time the
/// active roster happens to be short (an injury benching, say) -- see that
/// function's own doc comment.
///
/// Same message [mailboxFor] surfaces as a real Mail inbox item
/// (`assistantGmRosterGapMessage`, one source of truth for the wording) --
/// this card is just the same content shown inline where the GM already
/// is, not a separate duplicate. Tapping through marks it read, same as
/// opening it from the Mail tab would.
class _AssistantGmMailCard extends ConsumerWidget {
  const _AssistantGmMailCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'From Your Assistant GM',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(assistantGmRosterGapMessage(franchise)),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () {
              ref
                  .read(currentFranchiseProvider.notifier)
                  .markMailRead(kRosterGapMailId);
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
    );
  }
}

/// "Your training staff has feedback" -- points the GM at whatever
/// training report they haven't seen yet and hands off to
/// [TrainingReportScreen] for the surfaced moment, same "here's your
/// transient window" deal [_SeasonAdvanceCard] gives a game result.
/// Distinct from `MailScreen`, which is the passive archive of every
/// report once it's been seen -- this card is just pointing at unread
/// mail early, same as `_AssistantGmMailCard` does for the roster-gap
/// nudge.
///
/// In normal play the report already exists by the time this card shows
/// -- [CurrentFranchiseNotifier.advanceGameDay] auto-resolves training the
/// moment a week completes (`_catchUpTraining`'s doc comment) -- so a tap
/// just opens [_newestUnreadTrainingReport]. [runTrainingAndPersist] is
/// tried first only as a fallback for a save that predates auto-resolve
/// (`_isTrainingReportReady`'s doc comment); it's a no-op the rest of the
/// time.
class _TrainingReadyCard extends ConsumerStatefulWidget {
  const _TrainingReadyCard({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_TrainingReadyCard> createState() => _TrainingReadyCardState();
}

class _TrainingReadyCardState extends ConsumerState<_TrainingReadyCard> {
  var _isResolving = false;

  Future<void> _resolveTraining() async {
    setState(() => _isResolving = true);
    final resolved = await ref
        .read(currentFranchiseProvider.notifier)
        .runTrainingAndPersist();
    if (!mounted) return;
    setState(() => _isResolving = false);

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;
    final report = resolved ?? _newestUnreadTrainingReport(updatedFranchise);
    if (report == null) return;

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TrainingReportScreen(franchise: updatedFranchise, report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Training Report Ready', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Your training staff has feedback on the roster.'),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _isResolving ? null : _resolveTraining,
            child: _isResolving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('View Training Report'),
          ),
        ],
      ),
    );
  }
}

/// A quiet preview of recent training reports -- the 2 most recent, each
/// tappable straight to its full report, plus a link to the full
/// `MailScreen` inbox (training reports are one of the two things that
/// live there now, alongside Assistant GM messages -- see the Mail
/// feature's own doc comments). Deliberately placed at the very bottom of
/// the Dashboard's scroll, below the actionable Season/Training cards --
/// this is something to catch up on, not something competing with "what
/// do I need to do right now."
class _RecentNewsCard extends StatelessWidget {
  const _RecentNewsCard({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recent = [...franchise.trainingReports]
      ..sort((a, b) => b.week.compareTo(a.week));
    final preview = recent.take(2).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Training Reports',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const MailScreen()));
                },
                child: const Text('View All'),
              ),
            ],
          ),
          if (preview.isEmpty)
            const Text(
              'No news yet -- check back once your team starts '
              'training and playing games.',
            )
          else
            for (final report in preview)
              _RecentNewsRow(franchise: franchise, report: report),
        ],
      ),
    );
  }
}

class _RecentNewsRow extends StatelessWidget {
  const _RecentNewsRow({required this.franchise, required this.report});

  final Franchise franchise;
  final TrainingReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changedCount = report.results.length;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TrainingReportScreen(franchise: franchise, report: report),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                changedCount == 0
                    ? 'Week ${report.week} Training Report -- no one moved '
                          'the needle.'
                    : 'Week ${report.week} Training Report -- $changedCount '
                          'player${changedCount == 1 ? '' : 's'} changed.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Dashboard's own re-entry point back into every completed
/// season's recap, once the next one is already underway (2026-08-22,
/// a direct GM report: "Couldn't tell if my star player retired. I
/// skimmed the end season report a little too fast. I need a way to
/// re-open that report once season 2 has started", plus a same-day
/// follow-up: "I want to keep post season reports forever ... They all
/// need to live somewhere"). Renders nothing at all -- not even an
/// empty card -- until [seasonRecapSeasonsProvider] actually has at
/// least one season saved, which only happens after a real season
/// transition (`season_recap_history_provider.dart`'s own doc
/// comment); a fresh Season 1 franchise with no completed season yet
/// has nothing to look back on.
class _SeasonRecapsCard extends ConsumerWidget {
  const _SeasonRecapsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(seasonRecapSeasonsProvider);
    if (seasons.value == null || seasons.value!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.history, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Season Recaps', style: theme.textTheme.titleMedium),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SeasonRecapHistoryScreen(),
                ),
              );
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

/// Season status plus the one action that actually moves it forward:
/// [Franchise.seasonProgress]'s record so far, a preview of the next game
/// day (who the GM's own team plays, if anyone that day), and the
/// "Advance to Next Game Day" button itself. Deliberately day-granular,
/// not week-granular -- see `season_advancer.dart`'s doc comment on why
/// an "Advance Week" action would blow past individual games.
///
/// If the GM's own team is part of the game day just advanced, this hands
/// off to [GameResultScreen] for that one game's box score instead of
/// letting it disappear silently into the standings like every other
/// team's -- everything else in the day still gets simulated exactly the
/// same way (`advanceGameDay`'s doc comment).
class _SeasonAdvanceCard extends ConsumerStatefulWidget {
  const _SeasonAdvanceCard({required this.franchise});

  final Franchise franchise;

  @override
  ConsumerState<_SeasonAdvanceCard> createState() => _SeasonAdvanceCardState();
}

class _SeasonAdvanceCardState extends ConsumerState<_SeasonAdvanceCard> {
  var _isAdvancing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final franchise = widget.franchise;

    if (franchise.draftInProgress != null) {
      // A real bug, live on-device (2026-08-19, a direct GM report): "I
      // left the draft to look at my roster. And now .. where did the
      // draft go?! No idea. I think it's a safe bet most coaches will
      // leave the draft room to look at their roster. During the draft,
      // there should not be an advance to next game day button -- there
      // should just be a button to jump you back into the draft." By the
      // time `SeasonRecapScreen.beginNextSeason` hands off to a fresh
      // `DraftDayScreen`, the new season's own `seasonProgress` is
      // already a blank slate (no games played, not complete), so
      // without this check the normal advance-game-day card below had no
      // idea a draft was still open -- backing out of Draft Day (the
      // system back button, or just navigating to Roster) stranded the
      // GM with no way back in at all.
      // [Franchise.season] has already been bumped by the time a draft
      // exists (`beginNextSeason` sets both in the same transition) --
      // this is genuinely the season the draft belongs to, same
      // 0-indexed/display-as-+1 convention every other "Season N" label
      // in the app already follows.
      final displaySeason = franchise.season + 1;
      final newSeasonGameDays = gameDaysInOrder(
        franchise.seasonProgress.schedule,
      );
      final firstPreseasonDay = newSeasonGameDays.isEmpty
          ? null
          : newSeasonGameDays.first;
      // Your own natal Round 1 slot -- how the just-finished season's
      // standings/lottery actually shook out, confirmed for real once
      // the draft order exists, not just the recap screen's own
      // pre-draft lottery *projection* (2026-08-22, a direct GM ask: "I
      // want it to also confirm my draft pick position"). Doesn't
      // account for a slot traded away/acquired
      // (`pickOwnershipOverrides`) -- this answers "how did we finish,"
      // the same question the recap screen's own projection already
      // answers, not "who's actually on the clock for pick 1" (which
      // `DraftInProgress.onTheClock` already handles, trades included).
      final ownDraftPosition =
          franchise.draftInProgress!.order.indexOf(
            franchise.team.abbreviation,
          ) +
          1;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Draft In Progress', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Finish drafting your rookies before the season can '
              'continue.',
              style: theme.textTheme.bodySmall,
            ),
            if (ownDraftPosition > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You pick #$ownDraftPosition in Round 1.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            // Placeholder flavor dates -- a direct GM ask (2026-08-21):
            // "shows me the date of the trade window opening, and the
            // date of the first pre-season game." None of these are
            // mechanically enforced (the trade window's real open
            // condition is [isTradeWindowOpen], "the draft's finalized" --
            // not a fixed date), but a GM mid-draft still wants a sense
            // of what's coming next.
            if (firstPreseasonDay != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _DraftScheduleRow(
                label: 'Draft',
                date: formatFictionalDateOffset(
                  firstPreseasonDay.$1,
                  firstPreseasonDay.$2,
                  -14,
                ),
              ),
              _DraftScheduleRow(
                label: 'Trade Window Opens',
                date: formatFictionalDateOffset(
                  firstPreseasonDay.$1,
                  firstPreseasonDay.$2,
                  -7,
                ),
              ),
              _DraftScheduleRow(
                label: 'First Preseason Game',
                date: formatFictionalDate(
                  firstPreseasonDay.$1,
                  firstPreseasonDay.$2,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(currentFranchiseProvider.notifier)
                    .markDraftScreenOpened();
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DraftDayScreen()),
                );
              },
              child: Text(
                franchise.draftInProgress!.hasBeenOpened
                    ? 'Resume Season $displaySeason Draft'
                    : 'Begin Season $displaySeason Draft',
              ),
            ),
          ],
        ),
      );
    }

    final progress = franchise.seasonProgress;
    final leagueTeams = [
      franchise.team,
      for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
    ];
    final record = recordFor(
      franchise.team.abbreviation,
      currentStandings(progress, leagueTeams),
    );

    final champion = seasonChampion(progress.playedGames);
    final isCupWeek = nextGameDayTypes(
      progress,
    ).contains(GameType.continentalCup);
    final cupEliminationRound = continentalCupEliminationRound(
      progress.playedGames,
      franchise.team.abbreviation,
    );
    // Neither All-Star day is a normal team-vs-team game for the GM's own
    // club, so it isn't a "bye" in the sense this note means -- excluded
    // the same way `_advanceOrPreview` treats it as its own special case.
    final nextDayTypes = nextGameDayTypes(progress);
    // A direct GM ask (2026-08-20): "make the dashboard show the all
    // star break" -- same "Continental Cup Week" note treatment
    // [isCupWeek] already gets, just for whichever of the break's 2 days
    // ([kSkillsCompetitionDay]/[kAllStarGameDay]) is coming up next.
    final isAllStarBreakDay =
        nextDayTypes.contains(GameType.skillsCompetition) ||
        nextDayTypes.contains(GameType.allStarGame);
    // The postseason now plays out through this exact same day-by-day
    // advance (2026-08-20, a direct GM report: "it needs to play all the
    // games through the normal system") -- same "name the moment" note
    // [isCupWeek] gets, reading the actual round straight off *today's*
    // scheduled game(s) specifically, not just any postseason game
    // anywhere in the schedule.
    int? postseasonRoundToday;
    if (nextDayTypes.contains(GameType.postseason)) {
      final gameDays = gameDaysInOrder(progress.schedule);
      final (todayWeek, todayDay) = gameDays[progress.nextGameDayIndex];
      postseasonRoundToday = progress.schedule.games
          .firstWhere(
            (g) =>
                g.type == GameType.postseason &&
                g.week == todayWeek &&
                g.day == todayDay,
          )
          .postseasonRound;
    }
    final isOwnByeDay =
        !progress.isComplete &&
        !nextDayTypes.contains(GameType.skillsCompetition) &&
        !nextDayTypes.contains(GameType.allStarGame) &&
        nextOwnGame(progress, franchise.team.abbreviation) == null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // [Franchise.season] is zero-based (its own doc comment) --
          // display is 1-based, a direct GM ask (2026-08-19): "It should
          // say the current season number. Start with 1."
          Text(
            'Season ${franchise.season + 1}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_currentDateLabel(progress), style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Text('${record.wins}-${record.losses}'),
          const SizedBox(height: AppSpacing.sm),
          if (champion != null) ...[
            Text(
              '🏆 ${teamByAbbreviation(franchise, champion).name} are the '
              'champions!',
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SeasonRecapScreen(franchise: franchise),
                  ),
                );
              },
              // "Complete Season N" -- a direct GM ask (2026-08-21): "I
              // should now have a button on my dashboard that says
              // something like, Complete Season 1. I click it, it gives
              // me the end of season report." Same button, same
              // SeasonRecapScreen destination it already opened -- just
              // named for what a champion-crowned GM actually wants to do
              // next, not what the screen itself is called.
              child: Text('Complete Season ${franchise.season + 1}'),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Off-season only -- gated the same way "Complete Season N"
            // itself is, a champion crowned but the next season not yet
            // begun (2026-08-19, a direct GM ask: "During the offseason,
            // maybe there's a new button on the Dashboard").
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AvailableHeadCoachesScreen(franchise: franchise),
                  ),
                );
              },
              child: const Text('Available Head Coaches'),
            ),
          ] else ...[
            if (postseasonRoundToday != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Postseason -- '
                    '${postseasonRoundName(postseasonRoundToday)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else if (isCupWeek) ...[
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Continental Cup Week',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (cupEliminationRound != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your club was eliminated in '
                  '${continentalCupRoundPhrase(cupEliminationRound)} -- '
                  'these games are for the rest of the league.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ] else if (isAllStarBreakDay) ...[
              Row(
                children: [
                  Icon(
                    Icons.stars_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    nextDayTypes.contains(GameType.skillsCompetition)
                        ? 'All-Star Break -- Skills Competition'
                        : 'All-Star Break -- All-Star Game',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else if (isOwnByeDay) ...[
              // A plain regular-season/preseason bye -- the greedy
              // schedule packer doesn't guarantee every team a game on
              // every game day (`season_schedule_generator.dart`), so
              // this is normal, not a bug -- but with nothing on screen
              // saying so, advancing on a day the GM's own team sits out
              // read as confusing (a direct GM report, 2026-08-15: "I
              // need to know why" my team isn't playing this game day).
              Row(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'No Game Today',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your team has the day off -- other league games are '
                'still being simulated.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _UpcomingGamesList(franchise: franchise),
            const SizedBox(height: AppSpacing.md),
            if (_blockedByRosterGap(franchise))
              // The Assistant GM mail card above already explains why and
              // links to Player Market -- this just confirms there's
              // genuinely nothing to press here yet, not a dead end.
              Text(
                'Sign a free agent to fill your roster before advancing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else ...[
              FilledButton(
                onPressed: _isAdvancing ? null : _advanceOrPreview,
                child: _isAdvancing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Advance to Next Game Day'),
              ),
              // Only offered once the postseason has actually started --
              // a direct GM ask (2026-08-21): "I don't give a damn who
              // wins it, I just want to get to the end of the season
              // report, draft, etc." Loops the exact same day-by-day
              // `advanceGameDay` the button above uses
              // (`simulateRestOfPostseason`'s own doc comment), it just
              // doesn't stop to show every result along the way.
              if (postseasonRoundToday != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _isAdvancing ? null : _simulateRestOfPostseason,
                  child: const Text('Sim Rest of Postseason'),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  /// Routes to `MatchPreviewScreen` when the GM's own team is scheduled to
  /// play on the very next game day (`nextOwnGame`) -- a direct GM ask for
  /// "some kind of splash before my games, not just straight to the
  /// result." A bye day (no own game today, even if games are scheduled
  /// for every other team) skips straight to [_advance] exactly like
  /// before -- there's nothing of the GM's own to preview.
  void _advanceOrPreview() {
    final franchise = widget.franchise;
    final types = nextGameDayTypes(franchise.seasonProgress);
    // Neither All-Star day is a normal team-vs-team game -- `nextOwnGame`
    // would always read as a bye for the GM here regardless of whether
    // they actually have an All-Star, since neither placeholder squad
    // abbreviation ever matches a real team's (2026-08-10, TODO.md items
    // 5/6). Routed to its own dedicated advance method + result screen
    // instead of falling through to the generic path below, which would
    // otherwise just silently skip the day (`season_advancer.dart`'s
    // `_simulatable`).
    if (types.contains(GameType.skillsCompetition)) {
      _advanceSkillsCompetition();
      return;
    }
    if (types.contains(GameType.allStarGame)) {
      _advanceAllStarGame();
      return;
    }
    final ownGame = nextOwnGame(
      franchise.seasonProgress,
      franchise.team.abbreviation,
    );
    if (ownGame == null) {
      _advance();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchPreviewScreen(franchise: franchise, game: ownGame),
      ),
    );
  }

  Future<void> _advanceSkillsCompetition() async {
    setState(() => _isAdvancing = true);
    final result = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceSkillsCompetitionDay();
    if (!mounted) return;
    setState(() => _isAdvancing = false);
    if (result == null) return;

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SkillsCompetitionResultScreen(
          franchise: updatedFranchise,
          result: result,
        ),
      ),
    );
  }

  Future<void> _advanceAllStarGame() async {
    setState(() => _isAdvancing = true);
    final advance = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceAllStarGameDay();
    if (!mounted) return;
    setState(() => _isAdvancing = false);
    if (advance == null) return;

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;
    final skillsResult = updatedFranchise.skillsCompetitionResults.firstWhere(
      (r) => r.week == kAllStarWeek,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllStarGameResultScreen(
          franchise: updatedFranchise,
          playedGame: advance.playedGame,
          squads: skillsResult.squads,
        ),
      ),
    );
  }

  Future<void> _advance() async {
    setState(() => _isAdvancing = true);
    final results = await ref
        .read(currentFranchiseProvider.notifier)
        .advanceGameDay();
    if (!mounted) return;
    setState(() => _isAdvancing = false);
    if (results == null) return;

    final ownAbbreviation = widget.franchise.team.abbreviation;
    GameResult? ownGame;
    for (final result in results) {
      if (result.game.homeTeamAbbreviation == ownAbbreviation ||
          result.game.awayTeamAbbreviation == ownAbbreviation) {
        ownGame = result;
        break;
      }
    }

    if (!mounted) return;
    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;

    if (ownGame != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameResultScreen(
            franchise: updatedFranchise,
            result: ownGame!,
            // A Dashboard-triggered advance never offers a tactic
            // picker -- always the implicit default `advanceGameDay`
            // itself falls back to when `ownDefenseTactic` isn't
            // passed.
            ownDefenseTactic: DefensiveTactic.balanced,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_advanceSummary(results))));
    }
  }

  /// Handles the "Sim Rest of Postseason" button -- see that button's own
  /// doc comment. No result screen to push afterward (there's no single
  /// "own game" to show -- the whole point is skipping past every one of
  /// them); the dashboard rebuild after the provider call already shows
  /// the crowned champion, same as any other advance.
  Future<void> _simulateRestOfPostseason() async {
    setState(() => _isAdvancing = true);
    await ref
        .read(currentFranchiseProvider.notifier)
        .simulateRestOfPostseason();
    if (!mounted) return;
    setState(() => _isAdvancing = false);

    final updatedFranchise = ref.read(currentFranchiseProvider).value;
    if (updatedFranchise == null) return;
    final champion = seasonChampion(
      updatedFranchise.seasonProgress.playedGames,
    );
    if (champion == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${teamByAbbreviation(updatedFranchise, champion).name} are the '
          'champions!',
        ),
      ),
    );
  }

  /// The snackbar copy for a game day the GM's own team had a bye on.
  /// Names the Continental Cup specifically when that's what just
  /// simulated (2026-08-10, TODO.md item 12: a direct GM ask -- a
  /// generic "N games simulated" reads as confusing once the GM's own
  /// team is already out of the Cup and nothing on screen says why the
  /// app is still simulating anything at all) -- falls back to the plain
  /// count for a regular-season/preseason day, where there's no more
  /// specific label worth naming.
  String _advanceSummary(List<GameResult> results) {
    final cupGames = results
        .where((result) => result.game.type == GameType.continentalCup)
        .length;
    if (cupGames == results.length) {
      return 'Simulating $cupGames Continental Cup '
          'game${cupGames == 1 ? '' : 's'} across the league.';
    }
    return '${results.length} game${results.length == 1 ? '' : 's'} '
        'simulated across the league.';
  }
}

/// The GM's next few games, not just the very next one -- date, home/away,
/// opponent (with their own emoji, same "reads like a real scoreboard"
/// spirit as [_FranchiseSummaryCard]'s crest), and their current record.
/// One entry in [_UpcomingGamesList] -- a real [ScheduledGame], or the
/// Trade Deadline milestone spliced in at its real chronological
/// position (see that list's own doc comment).
sealed class _UpcomingItem {
  const _UpcomingItem();
}

class _UpcomingGameEntry extends _UpcomingItem {
  const _UpcomingGameEntry(this.game);
  final ScheduledGame game;
}

class _TradeDeadlineEntry extends _UpcomingItem {
  const _TradeDeadlineEntry();
}

class _AllStarBreakEntry extends _UpcomingItem {
  const _AllStarBreakEntry();
}

class _UpcomingGamesList extends StatelessWidget {
  const _UpcomingGamesList({required this.franchise});

  final Franchise franchise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final games = upcomingGamesFor(
      franchise.seasonProgress,
      franchise.team.abbreviation,
    );
    if (games.isEmpty) {
      return const Text('No games left on the schedule.');
    }

    final leagueTeams = [
      franchise.team,
      for (final aiTeam in franchise.league.aiTeams) aiTeam.team,
    ];
    final standings = currentStandings(franchise.seasonProgress, leagueTeams);

    // Splices the Trade Deadline and All-Star Break milestones in right
    // before the first visible game past each boundary -- "the little
    // dashboard calendar," a direct GM ask (2026-08-19 for the deadline,
    // 2026-08-20 for the break: "make the dashboard show the all star
    // break") for both to show up here too, not just the real Calendar
    // screen. Neither All-Star day is a real [ScheduledGame] for the GM's
    // own team ([upcomingGamesFor] only ever returns games where the GM's
    // team is actually the home/away side, and both All-Star days use the
    // placeholder conference-squad abbreviations instead --
    // `all_star_generator.dart`'s own doc comment) -- without this splice
    // the break is entirely invisible here, the week just silently skips
    // from the regular season straight to the postseason opener. Each
    // milestone only shows while it's still genuinely ahead
    // ([isTradeWindowOpen]/[isAllStarWeekUpcoming]) and its boundary
    // actually falls inside this short "next 3" horizon -- once it's
    // passed, or it's still too far out to be one of the next few games,
    // nothing is spliced in.
    final items = <_UpcomingItem>[];
    var deadlineInserted = false;
    var allStarBreakInserted = false;
    final showDeadline = isTradeWindowOpen(franchise);
    final showAllStarBreak = isAllStarWeekUpcoming(franchise);
    for (final game in games) {
      if (showDeadline && !deadlineInserted && game.week > kTradeDeadlineWeek) {
        items.add(const _TradeDeadlineEntry());
        deadlineInserted = true;
      }
      if (showAllStarBreak &&
          !allStarBreakInserted &&
          game.week > kAllStarWeek) {
        items.add(const _AllStarBreakEntry());
        allStarBreakInserted = true;
      }
      items.add(_UpcomingGameEntry(game));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Games', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        for (final item in items)
          switch (item) {
            _UpcomingGameEntry() => _UpcomingGameRow(
              franchise: franchise,
              game: item.game,
              standings: standings,
            ),
            _TradeDeadlineEntry() => const _TradeDeadlineRow(),
            _AllStarBreakEntry() => const _AllStarBreakRow(),
          },
      ],
    );
  }
}

/// A compact single line calling out the Trade Deadline, same visual
/// weight as [_UpcomingGameRow] so it reads as part of the same list
/// rather than a separate banner.
/// A compact "label -- date" line for the Draft In Progress card's
/// placeholder schedule (2026-08-21, a direct GM ask: "give it a calendar
/// date... shows me the date of the trade window opening, and the date
/// of the first pre-season game").
class _DraftScheduleRow extends StatelessWidget {
  const _DraftScheduleRow({required this.label, required this.date});

  final String label;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label:', style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpacing.xs),
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeDeadlineRow extends StatelessWidget {
  const _TradeDeadlineRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.lock_clock_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Trade Deadline -- end of Week $kTradeDeadlineWeek',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact single line calling out the All-Star Break, same treatment
/// [_TradeDeadlineRow] gets -- a direct GM ask (2026-08-20): "make the
/// dashboard show the all star break."
class _AllStarBreakRow extends StatelessWidget {
  const _AllStarBreakRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.stars_outlined,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'All-Star Break -- Week $kAllStarWeek',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingGameRow extends StatelessWidget {
  const _UpcomingGameRow({
    required this.franchise,
    required this.game,
    required this.standings,
  });

  final Franchise franchise;
  final ScheduledGame game;
  final List<StandingsEntry> standings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHome = game.homeTeamAbbreviation == franchise.team.abbreviation;
    final opponentAbbreviation = isHome
        ? game.awayTeamAbbreviation
        : game.homeTeamAbbreviation;
    final opponent = teamByAbbreviation(franchise, opponentAbbreviation);
    final opponentRecord = recordFor(opponentAbbreviation, standings);

    final cupBadge = game.type == GameType.continentalCup ? '🏆 ' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (game.type == GameType.preseason) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRESEASON',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              '$cupBadge${formatFictionalDate(game.week, game.day)} '
              '${isHome ? 'vs' : '@'} ${opponent.emoji} ${opponent.name} '
              '(${opponentRecord.wins}-${opponentRecord.losses})',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
