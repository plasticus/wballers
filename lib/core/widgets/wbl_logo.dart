import 'package:flutter/material.dart';

/// The Women's Basketball League's official crest
/// (`branding/wbl_logo_alpha.png`) -- a background-removed copy of the
/// GM-supplied `branding/wbl_logo.png` (flood-filled from the corners,
/// see the note left there), so it renders directly against any surface,
/// light or dark theme alike, without a backing card.
class WblLogo extends StatelessWidget {
  const WblLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      'branding/wbl_logo_alpha.png',
      width: size,
      height: size,
      semanticLabel: "Women's Basketball League logo",
      // The source file is 1254x1254 -- decoding it at full resolution for
      // a badge this small would waste memory for no visible gain.
      cacheWidth: (size * devicePixelRatio).round(),
    );
  }
}

/// The WBL Continental Cup's own crest
/// (`branding/wbl_continental_cup_logo_alpha.png`) -- same background
/// removal treatment as [WblLogo] (flood-filled from the corners, fuzz
/// 12%), from the GM-supplied `branding/wbl_continental_cup_logo.png`.
/// Replaces [WblLogo] at the top of the League screen while its Cup tab
/// is selected (2026-08-07, a direct GM ask), instead of the plain WBL
/// crest showing regardless of which tab is active.
class ContinentalCupLogo extends StatelessWidget {
  const ContinentalCupLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      'branding/wbl_continental_cup_logo_alpha.png',
      width: size,
      height: size,
      semanticLabel: 'WBL Continental Cup logo',
      cacheWidth: (size * devicePixelRatio).round(),
    );
  }
}
