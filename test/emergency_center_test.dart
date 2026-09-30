import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeug/local/emergency_center.dart';
import 'package:safeug/local/local_store.dart';

class ContactStore extends LocalStore {
  bool fail = false;
  @override
  Future<Record> save(String collection, Record fields, {String? id}) async {
    if (fail) throw StateError('Offline');
    final rows = data.putIfAbsent(collection, () => []);
    final existing = rows.where((r) => r['id'] == id).firstOrNull;
    final record = {
      ...?existing,
      ...fields,
      'id': id ?? 'contact-${rows.length}',
    };
    rows.removeWhere((r) => r['id'] == record['id']);
    rows.add(record);
    notifyListeners();
    return record;
  }

  @override
  Future<Position> locate({Future<Position> Function()? provider}) async =>
      throw StateError('Test permission denied');
  @override
  Future<void> publishLocation() async {}
}

void main() {
  testWidgets(
    'added personal contacts appear in sharing and switches persist individually',
    (tester) async {
      final store = ContactStore();
      addTearDown(store.dispose);
      tester.view.physicalSize = const Size(500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmergencyCenter(store: store)),
        ),
      );
      expect(find.text('Local Services'), findsOneWidget);
      await tester.tap(find.text('My Contacts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No personal contacts yet'), findsOneWidget);
      await tester.tap(find.text('Add Contact'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Trusted Friend',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Relationship'),
        'Friend',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        '+256700123456',
      );
      await tester.tap(find.text('Save Contact'));
      await tester.pumpAndSettle();
      expect(find.text('Trusted Friend'), findsOneWidget);
      expect(store.personalContacts.single['shareLocation'], false);
      await store.save('contacts', {
        'name': 'Family Contact',
        'relationship': 'Family',
        'phone': '+256700654321',
        'shareLocation': false,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocationSharing(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trusted Friend'), findsOneWidget);
      expect(find.text('Family Contact'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(
        store.personalContacts.firstWhere(
          (r) => r['name'] == 'Trusted Friend',
        )['shareLocation'],
        true,
      );
      expect(
        store.personalContacts.firstWhere(
          (r) => r['name'] == 'Family Contact',
        )['shareLocation'],
        false,
      );
      store.fail = true;
      await tester.tap(find.widgetWithText(SwitchListTile, 'Trusted Friend'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sharing setting was not saved'),
        findsOneWidget,
      );
      expect(
        store.personalContacts.firstWhere(
          (r) => r['name'] == 'Trusted Friend',
        )['shareLocation'],
        true,
      );
      store.fail = false;
      await tester.tap(find.widgetWithText(SwitchListTile, 'Trusted Friend'));
      await tester.pumpAndSettle();
      expect(
        store.personalContacts.every((r) => r['shareLocation'] == false),
        true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmergencyCenter(store: store, initialTab: 1)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove Trusted Friend'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(store.personalContacts, hasLength(1));
      expect(find.text('Trusted Friend'), findsNothing);
    },
  );
}
