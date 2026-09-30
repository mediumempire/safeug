import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safeug/local/device_location.dart';
import 'package:safeug/local/local_store.dart';
import 'package:safeug/local/mobile_tools.dart';

class ReportStore extends LocalStore {
  ReportStore({super.adminApp});
  Record? submitted;
  String? collection;

  @override
  Future<String> signal(Record fields) async {
    submitted = fields;
    return 'queued-report';
  }

  @override
  Future<Record> save(String collection, Record fields, {String? id}) async {
    this.collection = collection;
    submitted = fields;
    return {...fields, 'id': 'saved-report'};
  }
}

final devicePosition = Position(
  longitude: 32.5825,
  latitude: 0.3476,
  timestamp: DateTime.utc(2026, 9, 30, 8),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Future<void> openReport(
  WidgetTester tester,
  ReportStore store, {
  Future<Position> Function()? locate,
  Future<XFile?> Function(ImageSource, bool)? pick,
}) async {
  tester.view.physicalSize = const Size(500, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FieldReport(
                  store: store,
                  currentPosition: locate,
                  pickMedia: pick,
                ),
              ),
            ),
            child: const Text('Open report'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open report'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester, {bool admin = false}) => tapVisible(
  tester,
  find.text(admin ? 'Submit report' : 'Send report to admin'),
);

void main() {
  for (final admin in [false, true]) {
    testWidgets(
      '${admin ? 'admin' : 'mobile'} shares incident metadata and device location',
      (tester) async {
        final store = ReportStore(adminApp: admin);
        await openReport(tester, store, locate: () async => devicePosition);
        expect(find.widgetWithText(TextField, 'Latitude'), findsNothing);
        expect(find.widgetWithText(TextField, 'Longitude'), findsNothing);
        // Device location is attached automatically when the form opens.
        expect(find.text('Location attached'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'What happened?'),
          'A fallen tree blocks the trail; two visitors need help getting past.',
        );
        await tapVisible(tester, find.text('Suspicious Activity').first);
        await tester.tap(find.text('Safety Hazard').last);
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Medium').first);
        await tester.tap(find.text('High').last);
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Your contact details (optional)'));
        await tester.enterText(
          find.widgetWithText(TextField, 'Your name'),
          'Tourist Reporter',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Contact phone number'),
          '+256700123456',
        );
        await submit(tester, admin: admin);
        expect(store.submitted?['type'], 'Safety Hazard');
        expect(store.submitted?['severity'], 'High');
        expect(store.submitted?['reporter'], 'Tourist Reporter');
        expect(store.submitted?['phone'], '+256700123456');
        expect(store.submitted?['area'], '');
        expect(store.submitted?['latitude'], devicePosition.latitude);
        expect(store.submitted?['longitude'], devicePosition.longitude);
        expect(store.submitted?['accuracy'], 12);
        expect(store.submitted?['locationSource'], 'device');
        expect(
          store.submitted?['locationCapturedAt'],
          devicePosition.timestamp.toIso8601String(),
        );
        expect(
          DateTime.parse(store.submitted!['occurredAt'] as String).isUtc,
          isTrue,
        );
        expect(store.collection, admin ? 'incidents' : isNull);
        expect(find.textContaining('Activity'), findsNothing);
      },
    );
  }

  testWidgets('blocked location has a usable required landmark fallback', (
    tester,
  ) async {
    final store = ReportStore();
    await openReport(
      tester,
      store,
      locate: () async => throw const DeviceLocationException(
        'Location is blocked. Enter an area or landmark.',
      ),
    );
    await tapVisible(tester, find.text('Add current location'));
    expect(
      find.text('Location is blocked. Enter an area or landmark.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What happened?'),
      'Wildlife is approaching the campsite.',
    );
    await submit(tester);
    expect(store.submitted, isNull);
    expect(
      find.textContaining('so the team can find the incident'),
      findsOneWidget,
    );
    final landmark = find.widgetWithText(TextField, 'Area or landmark');
    await tester.ensureVisible(landmark);
    await tester.enterText(landmark, 'North campsite, water point');
    await submit(tester);
    expect(store.submitted?['area'], 'North campsite, water point');
    expect(store.submitted?['locationSource'], 'landmark');
    expect(store.submitted?['latitude'], isNull);
    expect(store.submitted!.containsKey('locationCapturedAt'), isFalse);
  });

  testWidgets(
    'gallery photo previews and removed video is excluded from report',
    (tester) async {
      final store = ReportStore();
      final picked = <(ImageSource, bool)>[];
      await openReport(
        tester,
        store,
        pick: (source, video) async {
          picked.add((source, video));
          final bytes = video
              ? Uint8List.fromList([
                  0,
                  0,
                  0,
                  12,
                  102,
                  116,
                  121,
                  112,
                  109,
                  112,
                  52,
                  50,
                ])
              : base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
                );
          return XFile.fromData(
            bytes,
            name: video ? 'clip.mp4' : 'photo.png',
            path: video ? 'clip.mp4' : 'photo.png',
            mimeType: video ? 'video/mp4' : 'image/png',
          );
        },
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Area or landmark'),
        'Trail entrance',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'What happened?'),
        'A damaged footbridge needs repair.',
      );
      await tapVisible(tester, find.byTooltip('Photo from gallery'));
      await tapVisible(tester, find.text('photo.png'));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Video from gallery'));
      expect(picked, [
        (ImageSource.gallery, false),
        (ImageSource.gallery, true),
      ]);
      final clip = find.widgetWithText(ListTile, 'clip.mp4');
      await tapVisible(
        tester,
        find.descendant(
          of: clip,
          matching: find.byTooltip('Remove attachment'),
        ),
      );
      expect(find.text('clip.mp4'), findsNothing);
      await submit(tester);
      final evidence = store.submitted!['evidence'] as List;
      expect(evidence, hasLength(1));
      expect(evidence.single['name'], 'photo.png');
      expect(evidence.single['mime'], 'image/png');
      expect(evidence.single.containsKey('localPath'), isFalse);
    },
  );

  testWidgets('camera permission failure preserves entered report details', (
    tester,
  ) async {
    final store = ReportStore();
    await openReport(
      tester,
      store,
      pick: (_, _) async =>
          throw PlatformException(code: 'camera_access_denied'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Area or landmark'),
      'Visitor centre',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What happened?'),
      'Suspicious activity near parked vehicles.',
    );
    await tapVisible(tester, find.byTooltip('Take photo'));
    expect(
      find.textContaining('Camera or gallery access is blocked.'),
      findsOneWidget,
    );
    await submit(tester);
    expect(store.submitted?['area'], 'Visitor centre');
    expect(store.submitted?['evidence'], isEmpty);
  });
}
