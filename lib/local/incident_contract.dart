/// Incident fields shared by the mobile report form and administration portal.
const incidentTypes = [
  'Suspicious Activity',
  'Animal Sighting',
  'Safety Hazard',
  'Human-Wildlife Conflict',
  'Illegal Encroachment',
  'Other',
  'SOS',
  'Poaching',
  'Medical',
  'Lost tourist',
  'Fire',
  'Ranger down',
  'Backup needed',
  'Wildlife',
];

const incidentSeverities = ['Low', 'Medium', 'High', 'Critical'];
const incidentStatuses = [
  'Reported',
  'Acknowledged',
  'Dispatched',
  'En Route',
  'Resolved',
  'False Alarm',
];

String normalizeIncidentType(Object? value) {
  final text = '$value'.trim();
  final key = text.toLowerCase();
  if (key == 'sos activation') return 'SOS';
  if (key == 'safety concern') return 'Safety Hazard';
  if (key == 'poaching activity') return 'Poaching';
  for (final type in incidentTypes) {
    if (type.toLowerCase() == key) return type;
  }
  return text;
}

bool isSosIncident(Map<String, dynamic> incident) =>
    normalizeIncidentType(incident['type']) == 'SOS';

bool isEmergencyIncident(Map<String, dynamic> incident) =>
    ['SOS', 'Ranger down'].contains(normalizeIncidentType(incident['type']));

bool isOpenIncident(Map<String, dynamic> incident) =>
    !['Resolved', 'False Alarm'].contains(incident['status']);

String defaultIncidentSeverity(Object? type) =>
    ['SOS', 'Ranger down'].contains(normalizeIncidentType(type))
    ? 'Critical'
    : 'Medium';

/// Describes only delivery/response information actually recorded by the API.
String incidentResponseMessage(
  Map<String, dynamic> incident, {
  bool queued = false,
}) {
  if (incident['standDownPending'] == true) {
    return 'Stand-down request saved on this device. Waiting for SafeUG administration to receive it.';
  }
  if (queued) {
    return 'Saved on this device. Waiting to reach SafeUG administration.';
  }
  var response = switch (incident['status']) {
    'Acknowledged' => 'SafeUG administration has acknowledged your emergency.',
    'Dispatched' => 'An administrator has marked the response as dispatched.',
    'En Route' => 'An administrator reports that help is on the way.',
    'Resolved' => 'SafeUG administration has marked this incident resolved.',
    'False Alarm' =>
      incident['standDownAt'] != null
          ? 'SOS stand-down received. This alert is closed.'
          : 'This alert has been closed as a false alarm.',
    _ => 'Received by SafeUG administration. Awaiting acknowledgement.',
  };
  final agency = '${incident['responseAgency'] ?? ''}'.trim();
  final note = '${incident['responseNote'] ?? ''}'.trim();
  if (agency.isNotEmpty) {
    response += ' Security contacted: $agency (recorded by admin).';
  }
  if (note.isNotEmpty) response += ' $note';
  if (incident['externalDelivery'] == 'Submitted') {
    return '$response Submitted to the emergency gateway; responder acceptance is not yet confirmed.';
  }
  if (incident['externalDelivery'] == 'Failed') {
    return '$response The emergency gateway did not confirm delivery.';
  }
  return response;
}

const sosAgencies = ['UPF', 'Tourist Police', 'UPDF'];

String sosAgencyMessage(
  Map<String, dynamic> incident,
  String agency, {
  bool queued = false,
}) {
  if (queued) {
    return '$agency: SOS saved on this device; awaiting connection. Contact is not confirmed.';
  }
  final response = '${incident['responseAgency'] ?? ''}'.toLowerCase();
  final receipt = (incident['agencyResponses'] as Map?)?[agency];
  if (receipt is Map) {
    return '$agency: contact recorded by administration. ${receipt['note'] ?? ''}'
        .trim();
  }
  if (response == agency.toLowerCase()) {
    return '$agency: contact recorded by administration. ${incident['responseNote'] ?? ''}'
        .trim();
  }
  return '$agency: emergency assistance requested. Awaiting contact confirmation from administration.';
}
