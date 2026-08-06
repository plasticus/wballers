import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../league/domain/initial_league.dart';
import '../../league/domain/league_draw.dart';
import '../../league/domain/team.dart';
import '../../league/team_row.dart';
import '../../portrait/persistence/portrait_catalog_loader.dart';
import '../application/current_franchise_provider.dart';
import 'expansion_franchise_factory.dart';

/// Name yourself (the GM) and the club, choose a conference, and generate
/// a weak starting roster with a hired coach. Phase 1's expansion
/// onboarding flow.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _gmNameController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _homeCityController = TextEditingController();
  var _conference = Conference.atlantic;
  // Not `late final` -- "Reroll League" replaces both after the fact, see
  // [_rerollLeague].
  late int _simulationSeed;
  late List<Team> _leagueTeams;
  late String _replacedTeamAbbreviation;
  late TeamColors _selectedColors;
  late String _selectedEmoji;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // The one place real (non-seeded) randomness enters the system --
    // everything downstream, including which 20 of the 40-team pool this
    // playthrough's league actually draws, is deterministic from here.
    _simulationSeed = Random().nextInt(1 << 31);
    _leagueTeams = drawLeagueTeams(
      Random(_simulationSeed + kLeagueDrawSeedOffset),
    );
    // A fresh random suggestion per playthrough (and per conference switch)
    // -- the GM can always pick a different team instead.
    _replacedTeamAbbreviation = _randomTeamAbbreviation(_conference);
    // Same pattern: a random default from the curated set, GM-overridable.
    _selectedColors =
        kStarterPalettes[Random().nextInt(kStarterPalettes.length)];
    _selectedEmoji = _randomWingsEmoji();
    for (final controller in [
      _gmNameController,
      _clubNameController,
      _homeCityController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  /// Rerolls the whole league draw: a fresh [_simulationSeed] and the 20
  /// teams it draws (see the class doc comment), plus everything that
  /// depends on which 20 -- a fresh replaced-team default, and, if the
  /// current emoji pick doesn't belong to the new [_wingsTeams] anymore,
  /// a fresh emoji default too (kept as-is if it's still available,
  /// same "don't discard a choice that's still valid" spirit as
  /// conference switching leaving [_selectedColors] alone).
  void _rerollLeague() {
    setState(() {
      _simulationSeed = Random().nextInt(1 << 31);
      _leagueTeams = drawLeagueTeams(
        Random(_simulationSeed + kLeagueDrawSeedOffset),
      );
      _replacedTeamAbbreviation = _randomTeamAbbreviation(_conference);
      final wings = _wingsTeams;
      if (!wings.any((team) => team.emoji == _selectedEmoji)) {
        _selectedEmoji = _randomWingsEmoji();
      }
    });
  }

  @override
  void dispose() {
    _gmNameController.dispose();
    _clubNameController.dispose();
    _homeCityController.dispose();
    super.dispose();
  }

  List<Team> get _conferenceTeams =>
      _leagueTeams.where((team) => team.conference == _conference).toList();

  /// The 20 `kLeagueTeamPool` teams *not* drawn into this playthrough's
  /// league -- nothing the GM would ever see in-league. Their emoji are
  /// what the team-emoji picker offers, so the GM's own pick is
  /// guaranteed distinct from every team actually in their league,
  /// without needing a separate curated list to keep in sync by hand.
  List<Team> get _wingsTeams {
    final drawnAbbreviations = _leagueTeams.map((t) => t.abbreviation).toSet();
    return kLeagueTeamPool
        .where((team) => !drawnAbbreviations.contains(team.abbreviation))
        .toList();
  }

  String _randomTeamAbbreviation(Conference conference) {
    final teams = _leagueTeams
        .where((team) => team.conference == conference)
        .toList();
    return teams[Random().nextInt(teams.length)].abbreviation;
  }

  String _randomWingsEmoji() {
    final wings = _wingsTeams;
    return wings[Random().nextInt(wings.length)].emoji;
  }

  bool get _isValid =>
      _gmNameController.text.trim().isNotEmpty &&
      _clubNameController.text.trim().isNotEmpty &&
      _homeCityController.text.trim().isNotEmpty;

  Future<void> _createFranchise() async {
    setState(() => _isSubmitting = true);

    final portraitWeights = await ref.read(portraitWeightsProvider.future);
    final portraitManifest = await ref.read(portraitManifestProvider.future);
    final franchise = createExpansionFranchise(
      gmName: _gmNameController.text.trim(),
      clubName: _clubNameController.text.trim(),
      homeCity: _homeCityController.text.trim(),
      conference: _conference,
      simulationSeed: _simulationSeed,
      replacedTeamAbbreviation: _replacedTeamAbbreviation,
      colors: _selectedColors,
      emoji: _selectedEmoji,
      portraitWeights: portraitWeights,
      portraitManifest: portraitManifest,
    );

    await ref
        .read(currentFranchiseProvider.notifier)
        .createFranchise(franchise);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Expansion Franchise')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Every legend starts with an expansion team.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "You're the General Manager: build the roster and set the "
                'direction. Your coach handles in-game decisions.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _gmNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Your name (General Manager)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _clubNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Club name',
                  helperText: 'The full team name, e.g. "New Orleans Brass"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _homeCityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Home city',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Conference', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<Conference>(
                segments: const [
                  ButtonSegment(
                    value: Conference.atlantic,
                    label: Text('Atlantic'),
                  ),
                  ButtonSegment(
                    value: Conference.pacific,
                    label: Text('Pacific'),
                  ),
                ],
                selected: {_conference},
                onSelectionChanged: (selection) => setState(() {
                  _conference = selection.first;
                  _replacedTeamAbbreviation = _randomTeamAbbreviation(
                    _conference,
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Team colors', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'We picked one at random -- tap a different palette if '
                'you\'d rather use that instead.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final palette in kStarterPalettes)
                    _PaletteSwatch(
                      key: ValueKey(palette.primaryHex),
                      colors: palette,
                      isSelected: palette == _selectedColors,
                      onTap: () => setState(() => _selectedColors = palette),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Team emoji', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Borrowed from the 20 teams that didn\'t make this '
                'league -- so it\'s never shared with a club you\'ll '
                'actually play against.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final team in _wingsTeams)
                    _EmojiOption(
                      key: ValueKey(team.abbreviation),
                      emoji: team.emoji,
                      isSelected: team.emoji == _selectedEmoji,
                      onTap: () => setState(() => _selectedEmoji = team.emoji),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Choose the team to replace',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your new club takes this team\'s place in the '
                '${_conference.label}. We picked one at random -- check a '
                'different one if you\'d rather replace them instead.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < _conferenceTeams.length; i++) ...[
                      Row(
                        children: [
                          Checkbox(
                            value:
                                _conferenceTeams[i].abbreviation ==
                                _replacedTeamAbbreviation,
                            onChanged: (checked) {
                              if (checked != true) return;
                              setState(
                                () => _replacedTeamAbbreviation =
                                    _conferenceTeams[i].abbreviation,
                              );
                            },
                          ),
                          Expanded(child: TeamRow(team: _conferenceTeams[i])),
                        ],
                      ),
                      if (i != _conferenceTeams.length - 1)
                        const Divider(height: AppSpacing.lg),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: _isSubmitting ? null : _rerollLeague,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Reroll League'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _isValid && !_isSubmitting ? _createFranchise : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Franchise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One curated color option: a filled circle in the palette's primary
/// color, with a checkmark (not just a border/color change) when selected
/// -- color alone never carries the only signal (accessibility rule in
/// ARCHITECTURE.md).
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.colors,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final TeamColors colors;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected ? 'Team colors, selected' : 'Team colors',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isSelected ? Icon(Icons.check, color: colors.accent) : null,
        ),
      ),
    );
  }
}

/// One curated team-emoji option -- a tappable tile showing [emoji] at a
/// legible size, with a border-width change (not just a color change) for
/// the selected state, same accessibility reasoning as [_PaletteSwatch].
class _EmojiOption extends StatelessWidget {
  const _EmojiOption({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected ? 'Team emoji $emoji, selected' : 'Team emoji $emoji',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}
