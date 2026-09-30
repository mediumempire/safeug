import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeug/local/guide_card.dart';
import 'package:safeug/local/local_store.dart';
import 'package:safeug/local/local_app.dart';

class RatingStore extends LocalStore {
  RatingStore({super.adminApp});
  String? guideId;
  int? score;
  bool fail = false;
  @override
  Future<void> rateGuide(String id, int value) async {
    if (fail) throw StateError('Offline');
    guideId = id;
    score = value;
  }
}

void main() {
  final guide = <String, dynamic>{
    'id': 'guide',
    'name': 'Test guide',
    'phone': '0700123456',
    'rating': 4.5,
    'ratingCount': 2,
  };
  test('WhatsApp links normalize Uganda and international numbers safely', () {
    for (final phone in [
      '0700123456',
      '+256 700-123-456',
      '00256700123456',
      '256700123456',
    ]) {
      expect(guideWhatsAppUri(phone).toString(), 'https://wa.me/256700123456');
    }
    expect(
      guideWhatsAppUri('+44 7700 900123').toString(),
      'https://wa.me/447700900123',
    );
    for (final invalid in [
      '',
      '000',
      '0704635489x',
      '070463549',
      '0786235489;999',
      '+25670012345',
    ]) {
      expect(guideWhatsAppUri(invalid), isNull);
    }
  });
  testWidgets('guide shows real rating and Contact now opens WhatsApp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RatingStore();
    Uri? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideCard(
            store: store,
            guide: guide,
            openChat: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('4.5 / 5 (2 ratings)'), findsOneWidget);
    await tester.tap(find.text('Contact now'));
    await tester.pump();
    expect(launched.toString(), 'https://wa.me/256700123456');
    store.dispose();
  });
  testWidgets('visitor selects 1 to 5 and retries a failed submission', (
    tester,
  ) async {
    final store = RatingStore()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideCard(store: store, guide: guide),
        ),
      ),
    );
    await tester.tap(find.text('Rate guide'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save rating'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('4 stars'));
    await tester.pump();
    expect(find.text('4 out of 5'), findsOneWidget);
    await tester.tap(find.text('Save rating'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rating could not be saved'), findsOneWidget);
    expect(store.score, isNull);
    store.fail = false;
    await tester.tap(find.text('Save rating'));
    await tester.pumpAndSettle();
    expect(store.guideId, 'guide');
    expect(store.score, 4);
    expect(find.byType(AlertDialog), findsNothing);
    store.dispose();
  });
  testWidgets(
    'unrated guides do not invent ratings and invalid phones disable chat',
    (tester) async {
      final store = RatingStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuideCard(
              store: store,
              guide: {'id': 'g', 'name': 'Unrated', 'phone': '078623549'},
            ),
          ),
        ),
      );
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Contact now'),
            )
            .onPressed,
        isNull,
      );
      store.dispose();
    },
  );
  testWidgets(
    'admin directory displays the shared rating without voting controls',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = RatingStore(adminApp: true)..authenticated = true;
      store.data['guides'] = [guide];
      await tester.pumpWidget(
        MaterialApp(
          home: LocalShell(
            store: store,
            currentPosition: () async =>
                throw StateError('Test location unavailable'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tour guides'));
      await tester.tap(find.text('Tour guides'));
      await tester.pumpAndSettle();
      expect(find.text('Visitor rating'), findsOneWidget);
      expect(find.text('4.5 / 5 (2 ratings)'), findsOneWidget);
      expect(find.text('Rate guide'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
