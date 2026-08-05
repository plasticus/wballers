import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
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
  late final int _simulationSeed;
  late final List<Team> _leagueTeams;
  late String _replacedTeamAbbreviation;
  late TeamColors _selectedColors;
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
    for (final controller in [
      _gmNameController,
      _clubNameController,
      _homeCityController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
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

  String _randomTeamAbbreviation(Conference conference) {
    final teams = _leagueTeams
        .where((team) => team.conference == conference)
        .toList();
    return teams[Random().nextInt(teams.length)].abbreviation;
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
              const SizedBox(height: AppSpacing.xl),
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
