import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'incident_contract.dart';
import 'local_store.dart';
import 'system_notifications.dart';

String mobileIncidentStatus(Record incident, {bool queued = false}) {
  if (incident['standDownPending'] == true) return 'Ending SOS…';
  if (queued) return 'SOS saved. Connecting to emergency support…';
  return switch (incident['status']) {
    'Acknowledged' => 'Your SOS has been acknowledged.',
    'Dispatched' => 'A response team has been dispatched.',
    'En Route' => 'Help is on the way.',
    'Resolved' => 'Your emergency has been resolved.',
    'False Alarm' => 'Your SOS has ended.',
    _ => 'SOS delivered. Waiting for a response.',
  };
}

/// Deduplicates real server transitions, not GPS refreshes or timer messages.
class AlertController extends ChangeNotifier {
  AlertController(this.store, {SystemNotifications? platform})
    : platform = platform ?? SystemNotifications();
  final LocalStore store;
  final SystemNotifications platform;
  String permission = 'unavailable';
  final Map<String, String> _seen = {};
  SharedPreferences? _prefs;
  String? _scope;
  bool _initialized = false;
  bool _disposed = false;
  Future<void> _delivery = Future.value();

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      /* Notifications still work without a dedupe cache. */
    }
    permission = await platform.permission();
    if (_disposed) return;
    _initialized = true;
    store.addListener(_changed);
    _changed();
    notifyListeners();
  }

  Future<void> enable() async {
    permission = await platform.permission(request: true);
    if (!_disposed) {
      notifyListeners();
      if (permission == 'granted') {
        await platform.show(
          id: 'enabled',
          title: 'SafeUG notifications enabled',
          body: 'Emergency alerts and response updates will appear here.',
          admin: store.adminApp,
        );
      }
    }
  }

  Future<void> refreshPermission() async {
    permission = await platform.permission();
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!_initialized || !store.ready || _disposed) return;
    final scope = 'alerts_v1_${store.adminApp}_${store.endpoint}';
    if (_scope != scope) {
      _scope = scope;
      _seen.clear();
      try {
        final saved = jsonDecode(_prefs?.getString(scope) ?? '{}') as Map;
        _seen.addAll(saved.map((key, value) => MapEntry('$key', '$value')));
      } catch (_) {
        /* A damaged dedupe cache cannot interrupt alert delivery. */
      }
    }
    if (store.adminApp && !store.authenticated) return;
    final incidents = store.adminApp
        ? store.records('incidents')
        : store.ownIncidents;
    for (final incident in incidents) {
      if (!isSosIncident(incident)) continue;
      final id = '${incident['id']}';
      final queued = store.isQueued(id);
      final signature =
          '${incident['status']}:$queued:${incident['standDownPending'] == true}';
      final previous = _seen[id];
      _seen[id] = signature;
      final open = isOpenIncident(incident);
      if (permission == 'granted' &&
          previous != signature &&
          (previous != null || open)) {
        if (store.adminApp) {
          if (open &&
              (previous == null ||
                  previous.startsWith('Resolved:') ||
                  previous.startsWith('False Alarm:'))) {
            _show(
              id,
              'New SOS emergency',
              'An SOS has reached SafeUG. Open the dashboard to review and respond.',
            );
          }
        } else {
          _show(
            id,
            open ? 'SOS update' : 'SOS ended',
            mobileIncidentStatus(incident, queued: queued),
          );
        }
      }
      final responses = incident['agencyResponses'];
      if (responses is Map && !store.adminApp) {
        for (final entry in responses.entries) {
          if (entry.value is! Map) continue;
          final response = entry.value as Map;
          final key = '$id:agency:${entry.key}';
          final stamp = '${response['at']}:${response['note']}';
          final old = _seen[key];
          _seen[key] = stamp;
          if (open && permission == 'granted' && old != stamp) {
            _show(
              key,
              '${entry.key} response',
              '${response['note'] ?? 'Administration recorded contact with this agency.'}',
            );
          }
        }
      }
    }
    // Bound device storage while preserving all currently visible records.
    if (_seen.length > 1000) {
      _seen.removeWhere(
        (key, _) => !incidents.any(
          (r) => key == '${r['id']}' || key.startsWith('${r['id']}:'),
        ),
      );
    }
    unawaited(_prefs?.setString(scope, jsonEncode(_seen)));
  }

  void _show(String id, String title, String body) {
    _delivery = _delivery
        .then((_) async {
          if (!_disposed) {
            await platform.show(
              id: id,
              title: title,
              body: body,
              admin: store.adminApp,
            );
          }
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_changed);
    super.dispose();
  }
}
