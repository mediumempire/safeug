// Run with: flutter test tool/render_sos_preview.dart
// A local rendering harness for reviewing the actual Flutter widget.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeug/app_theme.dart';
import 'package:safeug/local/sos_button.dart';

void main() {
  testWidgets('render light and dark SOS states', (tester) async {
    final fontPath = Platform.environment['SAFEUG_PREVIEW_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Inter')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(680, 720);
    tester.view.devicePixelRatio = 1;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: Column(
            children: [
              for (final active in [false, true])
                Expanded(
                  child: Row(
                    children: [
                      for (final brightness in [
                        Brightness.light,
                        Brightness.dark,
                      ])
                        Expanded(
                          child: Theme(
                            data: buildSafeUgTheme(brightness: brightness),
                            child: Builder(
                              builder: (context) => ColoredBox(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        active ? 'SOS ACTIVE' : 'READY TO HELP',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          letterSpacing: 2,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SosButton(
                                        active: active,
                                        busy: false,
                                        onPressed: () {},
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
    await tester.pump(const Duration(milliseconds: 850));
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('output/benchmark-review/sos-button-design.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
