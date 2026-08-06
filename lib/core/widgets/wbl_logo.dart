import 'package:flutter/material.dart';

/// The Women's Basketball League's official crest (`branding/wbl_logo.png`).
/// The source art is a flat 1254x1254 PNG with no alpha channel -- a solid
/// white background baked in, not transparent -- so this always renders it
/// on its own small white rounded card rather than directly against
/// whatever surface it's placed on. Without that, it shows as a plain
/// white square in dark mode instead of reading as a badge.
class WblLogo extends StatelessWidget {
  const WblLogo({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.12),
      ),
      child: Image.asset(
        'branding/wbl_logo.png',
        semanticLabel: "Women's Basketball League logo",
        // The source file is 1254x1254 -- decoding it at full resolution
        // for a badge this small would waste memory for no visible gain.
        cacheWidth: (size * devicePixelRatio).round(),
      ),
    );
  }
}
