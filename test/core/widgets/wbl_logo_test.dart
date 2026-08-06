import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womensbballmgr/core/widgets/wbl_logo.dart';

void main() {
  testWidgets('renders the crest asset at the requested size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WblLogo(size: 48))),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(WblLogo)), const Size(48, 48));

    final image = tester.widget<Image>(find.byType(Image));
    // cacheWidth wraps the underlying AssetImage in a ResizeImage.
    final resized = image.image as ResizeImage;
    expect(
      (resized.imageProvider as AssetImage).assetName,
      'branding/wbl_logo.png',
    );
    expect(image.semanticLabel, "Women's Basketball League logo");
  });
}
