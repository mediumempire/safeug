import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeug/local/local_app.dart';
import 'package:safeug/local/local_store.dart';
import 'package:safeug/local/mobile_tools.dart';
import 'package:safeug/app_theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class RecordingStore extends LocalStore {
  RecordingStore({super.adminApp});
  List<String>? credentials;
  Record? submitted;
  bool queued = false;
  @override
  Future<void> registerTourist(Record fields) async {
    submitted = fields;
  }

  @override
  Future<void> login(String username, String password) async {
    credentials = [username, password];
  }

  @override
  Future<String> signal(Record fields) async {
    submitted = fields;
    queued = true;
    return 'test-report';
  }

  @override
  Future<Record> save(String collection, Record fields, {String? id}) async {
    submitted = fields;
    return {...fields, 'id': 'test-report'};
  }
}

void main() {
  testWidgets('tourist registration requires details and consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RecordingStore();
    await tester.pumpWidget(
      MaterialApp(home: TouristRegistration(store: store)),
    );
    await tester.tap(find.text('Save registration'));
    await tester.pump();
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(store.submitted, isNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'Test Tourist');
    await tester.enterText(find.byType(TextFormField).at(1), '+256700123456');
    await tester.tap(find.text('Save registration'));
    await tester.pump();
    expect(store.submitted, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Save registration'));
    await tester.pumpAndSettle();
    expect(store.submitted?['name'], 'Test Tourist');
    expect(store.submitted?['consent'], true);
    store.dispose();
  });
  testWidgets('mobile stays mobile even at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = LocalStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LocalShell(
          store: store,
          currentPosition: () async =>
              throw Exception('Location unavailable in test'),
        ),
      ),
    );
    expect(find.text('Admin view'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Emergency'),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.sos), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.image(const AssetImage(safeUgLogoAsset)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('published directory has calling but no edit controls', (
    tester,
  ) async {
    final store = LocalStore();
    store.data['guides'] = [
      {'name': 'Approved guide', 'phone': '000', 'description': 'Test record'},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublishedDirectory(store: store, collection: 'guides'),
        ),
      ),
    );
    expect(find.text('Approved guide'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    store.dispose();
  });
  testWidgets('admin login hides operational data', (tester) async {
    final store = LocalStore(adminApp: true);
    await tester.pumpWidget(MaterialApp(home: AdminLogin(store: store)));
    expect(find.text('SafeUG Administration'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.image(const AssetImage(safeUgLogoAsset)), findsOneWidget);
    expect(find.text('Incidents'), findsNothing);
    store.dispose();
  });
  testWidgets('login validates and passes the entered username and password', (
    tester,
  ) async {
    final store = RecordingStore(adminApp: true);
    await tester.pumpWidget(MaterialApp(home: AdminLogin(store: store)));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your username and password.'), findsOneWidget);
    expect(store.credentials, isNull);
    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), 'test-password');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(store.credentials, ['admin', 'test-password']);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  for (final admin in [false, true]) {
    testWidgets(
      '${admin ? 'admin' : 'mobile'} report sends captured photo and video evidence',
      (tester) async {
        tester.view.physicalSize = const Size(500, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = RecordingStore(adminApp: admin);
        final sources = <ImageSource>[];
        final kinds = <bool>[];
        Future<XFile?> pick(ImageSource source, bool video) async {
          sources.add(source);
          kinds.add(video);
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
            name: video ? 'test.mp4' : 'test.png',
            mimeType: video ? 'video/mp4' : 'image/png',
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FieldReport(store: store, pickMedia: pick),
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
        await tester.enterText(
          find.widgetWithText(TextField, 'What happened?'),
          'Test report with evidence',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Area or landmark'),
          'Test park entrance',
        );
        await tester.ensureVisible(find.byTooltip('Take photo'));
        await tester.tap(find.byTooltip('Take photo'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Record video'));
        await tester.tap(find.byTooltip('Record video'));
        await tester.pumpAndSettle();
        expect(sources, [ImageSource.camera, ImageSource.camera]);
        expect(kinds, [false, true]);
        final button = find.text(
          admin ? 'Submit report' : 'Send report to admin',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(store.submitted?['description'], 'Test report with evidence');
        final evidence = store.submitted?['evidence'] as List;
        expect(evidence.map((r) => r['mime']), ['image/png', 'video/mp4']);
        expect(evidence.every((r) => r['base64'].isNotEmpty), isTrue);
        expect(store.queued, !admin);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
}
