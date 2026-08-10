import '../../player/domain/player.dart';

/// A draft-eligible player paired with the fictional college they came
/// from. [college] is flavor/display only -- per `colleges.md`'s own
/// draft-pool guidelines, prestige affects which college a prospect gets
/// assigned to, never [player]'s ratings.
///
/// Deliberately independent of [player]'s own [Player.college] (which
/// `generatePlayer` now assigns to every domestic player, not just draft
/// prospects) rather than reusing it -- every prospect gets a real
/// [college] here regardless of what [player.college] rolled to (`null`,
/// if [player]'s own randomly-rolled hometown happened to land
/// international). No behavior depends on that gap today (draft prospects
/// never route through `PlayerDetailScreen`, the only place
/// [Player.college] is read), but a future reader comparing the two
/// shouldn't be surprised to find them disagree.
class DraftProspect {
  const DraftProspect({required this.player, required this.college});

  final Player player;
  final College college;
}
