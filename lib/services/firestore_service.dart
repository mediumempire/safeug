import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import 'offline_signal_queue.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _contacts(String uid) =>
      _firestore.collection('users').doc(uid).collection('emergencyContacts');

  Stream<List<EmergencyContact>> contactsStream(String uid) => _contacts(uid)
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(EmergencyContact.fromDocument).toList(),
      );

  Future<void> createProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(user.uid);
    final touristRef = _firestore.collection('tourists').doc(user.uid);
    batch.set(userRef, {
      'id': user.uid,
      'email': user.email,
      'phoneNumber': phone,
      'firstName': firstName,
      'lastName': lastName,
      'dateJoined': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(touristRef, {
      'id': user.uid,
      'userProfileId': user.uid,
      'homeCountry': 'In Transit',
      'dateOfArrival': FieldValue.serverTimestamp(),
      'currentLatitude': 0,
      'currentLongitude': 0,
      'locationSharingEnabled': false,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> addContact(String uid, EmergencyContact contact) async {
    await _contacts(uid).add(contact.toMap());
  }

  Future<void> deleteContact(String uid, String contactId) async {
    await _contacts(uid).doc(contactId).delete();
  }

  Future<void> setLocationSharing(
    String uid,
    String contactId,
    bool enabled,
  ) async {
    await _contacts(uid).doc(contactId).set({
      'locationSharingEnabled': enabled,
    }, SetOptions(merge: true));
  }

  Stream<List<IncidentReport>> touristIncidentsStream(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('incidentReports')
      .snapshots()
      .map((snapshot) {
        final reports = snapshot.docs.map(IncidentReport.fromDocument).where((
          report,
        ) {
          return const [
            'Reported',
            'Active',
            'Dispatched',
            'En Route',
          ].contains(report.status);
        }).toList();
        reports.sort(
          (a, b) => (b.reportedAt ?? DateTime.now()).compareTo(
            a.reportedAt ?? DateTime.now(),
          ),
        );
        return reports;
      });

  Stream<bool> roleStream(String collection, String uid) => _firestore
      .collection(collection)
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.exists);

  Future<String> createIncident({
    required String uid,
    required Position? position,
    required List<EmergencyContact> contacts,
  }) async {
    return _createIncident(
      uid: uid,
      latitude: position?.latitude,
      longitude: position?.longitude,
      contactIds: contacts.map((contact) => contact.id).toList(),
    );
  }

  Future<String> createQueuedIncident(QueuedSosSignal signal) {
    return _createIncident(
      uid: signal.uid,
      latitude: signal.latitude,
      longitude: signal.longitude,
      contactIds: signal.contactIds,
      id: signal.id,
      createdAt: signal.createdAt,
    );
  }

  Future<String> _createIncident({
    required String uid,
    required double? latitude,
    required double? longitude,
    required List<String> contactIds,
    String? id,
    DateTime? createdAt,
  }) async {
    final incidentRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('incidentReports')
        .doc(id);
    await _firestore.runTransaction(
      (transaction) async {
        final existing = await transaction.get(incidentRef);
        if (existing.exists) return;
        transaction.set(incidentRef, {
          'reporterTouristId': uid,
          'incidentType': 'SOS Activation',
          'description':
              'Emergency SOS submitted through SafeUG. Awaiting operator review.',
          'initialLatitude': latitude,
          'initialLongitude': longitude,
          'reportedAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
          'status': 'Reported',
          'emergencyContactIds': contactIds,
          'notifiedAuthorities': <String>[],
          'authorizedReaders': {uid: true},
        });
      },
      timeout: const Duration(seconds: 10),
      maxAttempts: 1,
    );
    return incidentRef.id;
  }

  Future<void> appendLocation({
    required String uid,
    required String incidentId,
    required Position position,
  }) async {
    final reportRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('incidentReports')
        .doc(incidentId);
    await reportRef.collection('locationHistory').add({
      'touristId': uid,
      'incidentReportId': incidentId,
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracyMeters': position.accuracy,
    });
    await reportRef.set({
      'initialLatitude': position.latitude,
      'initialLongitude': position.longitude,
    }, SetOptions(merge: true));
  }

  Future<void> setIncidentStatus({
    required String uid,
    required String incidentId,
    required String status,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('incidentReports')
        .doc(incidentId)
        .set({'status': status}, SetOptions(merge: true));
  }

  Future<void> createCommunityReport({
    required String uid,
    required String reportType,
    required String location,
    required String description,
    required CommunityAnalysis analysis,
  }) async {
    await _firestore.collection('communityReports').add({
      'reporterUserProfileId': uid,
      'reportType': reportType,
      'location': location,
      'description': description,
      'urgency': analysis.urgency,
      'category': analysis.category,
      'analysis': analysis.analysis,
      'recommendedAction': analysis.recommendedAction,
      'reportedAt': FieldValue.serverTimestamp(),
    });
  }
}
