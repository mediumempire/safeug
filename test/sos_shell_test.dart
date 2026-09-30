import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeug/app_theme.dart';
import 'package:safeug/local/device_location.dart';
import 'package:safeug/local/alert_controller.dart';
import 'package:safeug/local/local_app.dart';
import 'package:safeug/local/local_store.dart';

class SosRecordingStore extends LocalStore {
  SosRecordingStore({super.adminApp});

  final submitted = <Record>[];
  final locationUpdates = <Record>[];
  final standDownIds = <String>[];
  Record? savedRecord;

  @override
  Future<Record> save(String collection, Record fields, {String? id}) async {
    savedRecord = {...fields, 'id': id ?? 'record-1'};
    return savedRecord!;
  }

  @override
  Future<String> signal(Record fields) async {
    final record = {
      ...fields,
      'id': 'sos-${submitted.length + 1}',
      'status': 'Reported',
      'reportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    submitted.add(record);
    queue.add(record);
    notifyListeners();
    return record['id'] as String;
  }

  @override
  Future<void> updateIncidentLocation(String id, Record fields) async {
    locationUpdates.add({'id': id, ...fields});
    final incident = queue.firstWhere((incident) => incident['id'] == id);
    incident.addAll(fields);
    notifyListeners();
  }

  @override
  Future<void> closeSos(
    String id, {
    String reason = 'I am safe / accidental activation',
  }) async {
    standDownIds.add(id);
    pendingIncidentActions.add({
      'incidentId': id,
      'action': 'stand-down',
      'fields': <String, dynamic>{},
    });
    notifyListeners();
  }

  @override
  Future<void> sync() async {}

  void receiveResponse(Record changes) {
    final current = queue.isEmpty ? records('incidents').single : queue.single;
    final incident = {...current, ...changes};
    queue.clear();
    data['incidents'] = [incident];
    connected = true;
    notifyListeners();
  }
}

Position currentFix() => Position(
  longitude: 32.581,
  latitude: 0.313,
  timestamp: DateTime.now(),
  accuracy: 8,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Future<void> mountShell(
  WidgetTester tester,
  SosRecordingStore store, {
  Future<Position> Function()? currentPosition,
  Size size = const Size(430, 1250),
}) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildSafeUgTheme(brightness: Brightness.light),
      home: LocalShell(
        store: store,
        currentPosition: currentPosition ?? () async => currentFix(),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}

void main() {
  testWidgets('mobile home omits technical response and GPS panels', (
    tester,
  ) async {
    final store = SosRecordingStore();
    await mountShell(tester, store);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sos));
    await tester.pumpAndSettle();
    expect(find.text('Emergency response'), findsNothing);
    expect(find.text('Refresh response'), findsNothing);
    expect(find.textContaining('External dispatch'), findsNothing);
    expect(find.textContaining('Current location ready'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('ACTIVE'), findsOneWidget);
    store.receiveResponse({
      'status': 'False Alarm',
      'standDownAt': DateTime.now().toIso8601String(),
    });
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.textContaining('Awaiting contact'), findsNothing);
  });
  testWidgets('new SOS displays an urgent admin alert on any dashboard page', (
    tester,
  ) async {
    final store = SosRecordingStore(adminApp: true);
    await mountShell(tester, store, size: const Size(1440, 1200));
    await tester.pumpAndSettle();
    store.data['incidents'] = [
      {
        'id': 'urgent',
        'type': 'SOS',
        'status': 'Reported',
        'reporter': 'Test visitor',
        'area': 'Test gate',
        'reportedAt': DateTime.now().toIso8601String(),
      },
    ];
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Review SOS'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Rangers'));
    await tester.pumpAndSettle();
    expect(find.text('Review SOS'), findsOneWidget);
    store.data['incidents']!.first['status'] = 'Acknowledged';
    store.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Review SOS'), findsNothing);
  });
  testWidgets('mobile navigation never exposes the admin activity feed', (
    tester,
  ) async {
    final store = SosRecordingStore();
    await mountShell(tester, store, size: const Size(1400, 1000));
    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(destinations.map((destination) => destination.label), [
      'Home',
      'Map',
      'Report',
    ]);
    expect(find.textContaining('Activity'), findsNothing);
    await tester.ensureVisible(find.text('Emergency'));
    await tester.tap(find.text('Emergency'));
    await tester.pumpAndSettle();
    expect(find.text('Local Services'), findsOneWidget);
    expect(find.text('My Contacts'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.textContaining('Activity'), findsNothing);
    expect(find.text('Overview'), findsNothing);
  });

  testWidgets(
    'SOS activates before GPS completes and receives response updates',
    (tester) async {
      final store = SosRecordingStore();
      final location = Completer<Position>();
      await mountShell(tester, store, currentPosition: () => location.future);
      await tester.tap(find.byIcon(Icons.sos));
      await tester.pump();
      await tester.pump();
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(store.submitted.single['severity'], 'Critical');
      expect(store.locationUpdates, isEmpty);

      location.complete(currentFix());
      await tester.pumpAndSettle();
      expect(store.locationUpdates.single['latitude'], 0.313);
      expect(store.locationUpdates.single['longitude'], 32.581);
      expect(store.locationUpdates.single['accuracy'], 8);

      store.receiveResponse({
        'status': 'Acknowledged',
        'responseAgency': 'Park response team',
        'responseNote': 'Stay near the main gate.',
      });
      await tester.pump();
      await tester.pumpAndSettle();
      final response = mobileIncidentStatus(store.latestSos!);
      expect(find.text(response), findsWidgets);
      expect(find.text('ACTIVE'), findsOneWidget);

      store.receiveResponse({'status': 'Dispatched'});
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text(mobileIncidentStatus(store.latestSos!)), findsWidgets);
      expect(find.text('ACTIVE'), findsOneWidget);

      store.receiveResponse({'status': 'Resolved'});
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('ACTIVE'), findsNothing);
      expect(find.byIcon(Icons.sos), findsOneWidget);
      expect(find.text(mobileIncidentStatus(store.latestSos!)), findsNothing);
    },
  );

  testWidgets(
    'pressing ACTIVE requests confirmation and never sends a second SOS',
    (tester) async {
      final store = SosRecordingStore();
      await mountShell(tester, store);
      await tester.tap(find.byIcon(Icons.sos));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACTIVE'));
      await tester.pumpAndSettle();
      expect(find.text('End this SOS?'), findsOneWidget);
      expect(store.submitted, hasLength(1));
      await tester.tap(find.text('Keep SOS active'));
      await tester.pumpAndSettle();
      expect(store.standDownIds, isEmpty);
      expect(find.text('ACTIVE'), findsOneWidget);

      await tester.tap(find.text('ACTIVE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I am safe — end SOS'));
      await tester.pumpAndSettle();
      expect(store.standDownIds, ['sos-1']);
      expect(store.submitted, hasLength(1));
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Ending SOS…'), findsWidgets);
    },
  );

  testWidgets('denied location still saves and activates SOS', (tester) async {
    final store = SosRecordingStore();
    await mountShell(
      tester,
      store,
      currentPosition: () async => throw const DeviceLocationException(
        'Location permission was denied.',
      ),
    );
    await tester.tap(find.byIcon(Icons.sos));
    await tester.pumpAndSettle();
    expect(store.submitted, hasLength(1));
    expect(store.locationUpdates, isEmpty);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(
      find.textContaining('Location permission was denied.'),
      findsNothing,
    );
  });

  testWidgets('SOS waits for a location lookup already in progress', (
    tester,
  ) async {
    final store = SosRecordingStore();
    final location = Completer<Position>();
    await mountShell(tester, store, currentPosition: () => location.future);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.sos));
    await tester.pump();
    location.complete(currentFix());
    await tester.pumpAndSettle();
    expect(store.locationUpdates, hasLength(1));
    expect(store.locationUpdates.single['id'], 'sos-1');
  });

  testWidgets('admin location form captures GPS without coordinate inputs', (
    tester,
  ) async {
    final store = SosRecordingStore(adminApp: true);
    await mountShell(tester, store, size: const Size(1440, 1200));
    await tester.tap(find.widgetWithText(ListTile, 'Rangers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    expect(find.text('Use device current location'), findsOneWidget);
    final inputs = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      inputs.any(
        (input) =>
            ['Latitude', 'Longitude'].contains(input.decoration?.labelText),
      ),
      isFalse,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Test ranger',
    );
    await tester.tap(find.text('Use device current location'));
    await tester.pumpAndSettle();
    expect(
      find.text('Current location attached (accuracy 8 m).'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();
    expect(store.savedRecord?['latitude'], 0.313);
    expect(store.savedRecord?['longitude'], 32.581);
    expect(store.savedRecord?['accuracy'], 8);
  });
}
