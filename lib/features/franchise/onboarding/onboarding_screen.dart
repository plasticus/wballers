import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../league/domain/league_draw.dart';
import '../../league/domain/team.dart';
import '../../league/team_row.dart';
import 'coach_selection_screen.dart';
import 'expansion_franchise_factory.dart';
import 'team_emoji_options.dart';

/// Name yourself (the GM), name the club, choose a conference/colors/
/// emoji, and pick which of the drawn league's 20 teams to replace.
/// Continuing from here doesn't create the franchise yet -- it hands off
/// to [CoachSelectionScreen] first (Phase 1's expansion onboarding flow
/// now has two steps, identity then a real staffing decision).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _gmNameController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _homeCityController = TextEditingController();
  final _homeStateController = TextEditingController();
  final _abbreviationController = TextEditingController();
  var _conference = Conference.atlantic;
  // Not `late final` -- "Reroll League" replaces both after the fact, see
  // [_rerollLeague].
  late int _simulationSeed;
  late List<Team> _leagueTeams;
  late String _replacedTeamAbbreviation;
  late TeamColors _selectedColors;
  late String _selectedEmoji;

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
    _selectedEmoji = _randomEmojiOption();
    for (final controller in [
      _gmNameController,
      _clubNameController,
      _homeCityController,
      _homeStateController,
      _abbreviationController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  /// Rerolls the whole league draw: a fresh [_simulationSeed] and the 20
  /// teams it draws (see the class doc comment), plus everything that
  /// depends on which 20 -- a fresh replaced-team default, and, if the
  /// current emoji pick collides with a newly-drawn team, a fresh emoji
  /// default too (kept as-is if it's still available, same "don't discard
  /// a choice that's still valid" spirit as conference switching leaving
  /// [_selectedColors] alone).
  void _rerollLeague() {
    setState(() {
      _simulationSeed = Random().nextInt(1 << 31);
      _leagueTeams = drawLeagueTeams(
        Random(_simulationSeed + kLeagueDrawSeedOffset),
      );
      _replacedTeamAbbreviation = _randomTeamAbbreviation(_conference);
      if (_availableEmojiOptions.every((e) => e != _selectedEmoji)) {
        _selectedEmoji = _randomEmojiOption();
      }
    });
  }

  @override
  void dispose() {
    _gmNameController.dispose();
    _clubNameController.dispose();
    _homeCityController.dispose();
    _homeStateController.dispose();
    _abbreviationController.dispose();
    super.dispose();
  }

  List<Team> get _conferenceTeams =>
      _leagueTeams.where((team) => team.conference == _conference).toList();

  /// The full curated emoji pool, minus whatever this playthrough's 20
  /// drawn teams already use -- so the GM's own pick is guaranteed
  /// distinct from every team actually in their league, without needing a
  /// separate curated list to keep in sync by hand.
  List<String> get _availableEmojiOptions {
    final drawnEmoji = _leagueTeams.map((t) => t.emoji).toSet();
    return kTeamEmojiOptions.where((e) => !drawnEmoji.contains(e)).toList();
  }

  String _randomTeamAbbreviation(Conference conference) {
    final teams = _leagueTeams
        .where((team) => team.conference == conference)
        .toList();
    return teams[Random().nextInt(teams.length)].abbreviation;
  }

  String _randomEmojiOption() {
    final options = _availableEmojiOptions;
    return options[Random().nextInt(options.length)];
  }

  /// Exactly 3 letters, same shape as every `kLeagueTeamPool` entry
  /// (`Team.abbreviation`'s own doc comment) -- a derived abbreviation
  /// can't tell "DSM" from "DMD" apart for a team like the "Des Moines
  /// Dragons" hint example, so this is now a real GM choice, not
  /// guessed from the team name.
  static final _abbreviationPattern = RegExp(r'^[A-Za-z]{3}$');

  bool get _isValid =>
      _gmNameController.text.trim().isNotEmpty &&
      _clubNameController.text.trim().isNotEmpty &&
      _homeCityController.text.trim().isNotEmpty &&
      _homeStateController.text.trim().isNotEmpty &&
      _abbreviationPattern.hasMatch(_abbreviationController.text.trim());

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachSelectionScreen(
          gmName: _gmNameController.text.trim(),
          clubName: _clubNameController.text.trim(),
          homeCity: _homeCityController.text.trim(),
          homeState: _homeStateController.text.trim(),
          abbreviation: _abbreviationController.text.trim().toUpperCase(),
          conference: _conference,
          simulationSeed: _simulationSeed,
          replacedTeamAbbreviation: _replacedTeamAbbreviation,
          colors: _selectedColors,
          emoji: _selectedEmoji,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gmName = _gmNameController.text.trim();
    final clubName = _clubNameController.text.trim();
    final homeCity = _homeCityController.text.trim();
    final homeState = _homeStateController.text.trim();
    final abbreviation = _abbreviationController.text.trim().toUpperCase();

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
                  labelText: 'Name of General Manager',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Team Name is the *whole* branded name, verbatim -- not
              // just a nickname the app silently prepends a city to
              // (2026-08-10, a direct GM report with a screenshot: a
              // club named "Deebers" was only ever showing as "Deebers"
              // in the league, not "Des Moines Deebers" like the preview
              // below implied). Typing the full name here also answers
              // the GM's own follow-up -- naming a club after a state
              // instead of its home city ("the Iowa Deebers, who play in
              // Des Moines") just means typing "Iowa Deebers" here; City/
              // State below is independent flavor text, not a name
              // source.
              TextField(
                controller: _clubNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Team Name',
                  hintText: 'e.g. Des Moines Dragons',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _homeCityController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Home City',
                        hintText: 'Des Moines',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _homeStateController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'State/Province',
                        hintText: 'IA',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _abbreviationController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Abbr.',
                        hintText: 'DSM',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              if (gmName.isNotEmpty ||
                  clubName.isNotEmpty ||
                  homeCity.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                _IdentityPreviewCard(
                  gmName: gmName,
                  clubName: clubName,
                  homeCity: homeCity,
                  homeState: homeState,
                  abbreviation: abbreviation,
                  emoji: _selectedEmoji,
                  conference: _conference,
                  colors: _selectedColors,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Conference', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<Conference>(
                // Pacific (west) shown before Atlantic (east) -- reads
                // left-to-right the way a US map does, a direct GM ask
                // (2026-08-09).
                segments: const [
                  ButtonSegment(
                    value: Conference.pacific,
                    label: Text('Pacific'),
                  ),
                  ButtonSegment(
                    value: Conference.atlantic,
                    label: Text('Atlantic'),
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
                'Pick a crest from the pool below -- never shared with a '
                'club you\'ll actually play against.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              _EmojiGrid(
                options: _availableEmojiOptions,
                selectedEmoji: _selectedEmoji,
                onSelected: (emoji) => setState(() => _selectedEmoji = emoji),
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
                  onPressed: _rerollLeague,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Reroll League'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _isValid ? _continue : null,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A live preview of how the club will read once created -- updates as
/// the GM types, so the identity choice feels concrete before committing
/// to it. Below the GM-name line, renders a real [TeamRow] off a
/// throwaway [Team] built from the in-progress fields -- pixel-identical
/// to how this club will actually show up on the League screen
/// (2026-08-10, a direct GM report with a screenshot: the old preview's
/// own "$homeCity $clubName" line didn't match what actually got saved
/// as [Team.name], so what the GM saw here didn't match the league once
/// created -- showing the *real* row widget instead of a hand-rolled
/// approximation makes that mismatch structurally impossible from here
/// on).
class _IdentityPreviewCard extends StatelessWidget {
  const _IdentityPreviewCard({
    required this.gmName,
    required this.clubName,
    required this.homeCity,
    required this.homeState,
    required this.abbreviation,
    required this.emoji,
    required this.conference,
    required this.colors,
  });

  final String gmName;
  final String clubName;
  final String homeCity;
  final String homeState;
  final String abbreviation;
  final String emoji;
  final Conference conference;
  final TeamColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayGmName = gmName.isEmpty ? 'Your name' : gmName;
    final previewTeam = Team(
      abbreviation: abbreviation.isEmpty ? '???' : abbreviation,
      location: homeState.isEmpty ? homeCity : '$homeCity, $homeState',
      name: clubName.isEmpty ? 'Your Team' : clubName,
      conference: conference,
      colors: colors,
      identityNote: '',
      emoji: emoji,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$displayGmName, General Manager',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          TeamRow(team: previewTeam),
        ],
      ),
    );
  }
}

/// The curated emoji pool in a scrollable grid -- way more options than
/// the old 20-team "wings" picker, so it needs real scrolling rather than
/// a `Wrap` that would otherwise blow out the onboarding page's height.
class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({
    required this.options,
    required this.selectedEmoji,
    required this.onSelected,
  });

  final List<String> options;
  final String selectedEmoji;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 56,
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
        ),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final emoji = options[index];
          return _EmojiOption(
            key: ValueKey(emoji),
            emoji: emoji,
            isSelected: emoji == selectedEmoji,
            onTap: () => onSelected(emoji),
          );
        },
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
