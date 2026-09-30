import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    this.locationSharingEnabled = false,
  });

  final String id;
  final String name;
  final String relationship;
  final String phone;
  final bool locationSharingEnabled;

  factory EmergencyContact.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return EmergencyContact(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Unnamed contact',
      relationship: (data['relationship'] as String?) ?? 'Emergency contact',
      phone:
          (data['phone'] as String?) ?? (data['phoneNumber'] as String?) ?? '',
      locationSharingEnabled: data['locationSharingEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'phoneNumber': phone,
    'locationSharingEnabled': locationSharingEnabled,
  };
}

class IncidentReport {
  const IncidentReport({
    required this.id,
    required this.type,
    required this.status,
    required this.reporterId,
    this.reportedAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String type;
  final String status;
  final String reporterId;
  final DateTime? reportedAt;
  final double? latitude;
  final double? longitude;

  factory IncidentReport.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['reportedAt'];
    return IncidentReport(
      id: doc.id,
      type: (data['incidentType'] as String?) ?? 'SOS Activation',
      status: (data['status'] as String?) ?? 'Reported',
      reporterId: (data['reporterTouristId'] as String?) ?? '',
      reportedAt: timestamp is Timestamp ? timestamp.toDate() : null,
      latitude: (data['initialLatitude'] as num?)?.toDouble(),
      longitude: (data['initialLongitude'] as num?)?.toDouble(),
    );
  }
}

class GuideProfile {
  const GuideProfile({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
  });

  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final int reviews;
}

class SafetyAdvice {
  const SafetyAdvice({
    required this.alerts,
    required this.tips,
    this.isFallback = false,
  });

  final List<String> alerts;
  final List<String> tips;
  final bool isFallback;
}

class CommunityAnalysis {
  const CommunityAnalysis({
    required this.urgency,
    required this.category,
    required this.analysis,
    required this.recommendedAction,
    this.isFallback = false,
  });

  final String urgency;
  final String category;
  final String analysis;
  final String recommendedAction;
  final bool isFallback;
}
