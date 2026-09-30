import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QueuedSosSignal {
  const QueuedSosSignal({
    required this.id,
    required this.uid,
    required this.createdAt,
    required this.contactIds,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  final String id;
  final String uid;
  final DateTime createdAt;
  final List<String> contactIds;
  final double? latitude;
  final double? longitude;
  final double? accuracy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'createdAt': createdAt.toIso8601String(),
    'contactIds': contactIds,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
  };

  factory QueuedSosSignal.fromJson(Map<String, dynamic> json) {
    return QueuedSosSignal(
      id: json['id'] as String,
      uid: json['uid'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      contactIds: List<String>.from(json['contactIds'] as List? ?? const []),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
    );
  }
}

class OfflineSignalQueue {
  OfflineSignalQueue._();

  static final instance = OfflineSignalQueue._();
  static const _key = 'safeug_pending_sos_signals_v1';

  Future<List<QueuedSosSignal>> pending() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (entry) => QueuedSosSignal.fromJson(entry as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> enqueue(QueuedSosSignal signal) async {
    await _mutate(() async {
      final signals = await pending();
      await _save([...signals.where((s) => s.id != signal.id), signal]);
    });
  }

  Future<void> remove(String id) async {
    await _mutate(() async {
      await _save((await pending()).where((s) => s.id != id).toList());
    });
  }

  Future<void> _writes = Future.value();

  Future<void> _mutate(Future<void> Function() action) {
    final operation = _writes.then((_) => action());
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  bool _retrying = false;

  Future<int> retry(
    Future<String> Function(QueuedSosSignal signal) send, {
    required String uid,
  }) async {
    if (_retrying) return 0;
    _retrying = true;
    try {
      final signals = await pending();
      var delivered = 0;
      for (final signal in signals.where((s) => s.uid == uid)) {
        try {
          await send(signal).timeout(const Duration(seconds: 12));
          await remove(signal.id);
          delivered++;
        } catch (_) {}
      }
      return delivered;
    } finally {
      _retrying = false;
    }
  }

  Future<void> _save(List<QueuedSosSignal> signals) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode(signals.map((signal) => signal.toJson()).toList()),
    );
    if (!saved) throw StateError('Unable to persist SOS on this device.');
  }
}
