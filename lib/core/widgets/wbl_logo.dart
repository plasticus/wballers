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
