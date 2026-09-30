import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Calls the optional SafeUG AI gateway without placing a Gemini key in the
/// mobile binary. Configure it with --dart-define=SAFEUG_AI_ENDPOINT=...
class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const endpoint = String.fromEnvironment('SAFEUG_AI_ENDPOINT');

  Future<SafetyAdvice> generateSafetyAdvice({
    required String location,
    required String context,
    required String timeOfDay,
  }) async {
    final response = await _request('/safety-alerts', {
      'currentLocation': location,
      'travelContext': context,
      'timeOfDay': timeOfDay,
    });
    if (response != null) {
      return SafetyAdvice(
        alerts: _stringList(response['alerts']),
        tips: _stringList(response['tips']),
      );
    }

    final alerts = <String>[];
    if (timeOfDay == 'night') {
      alerts.add(
        'Avoid isolated routes after dark and use a trusted local guide.',
      );
    }
    if (location.toLowerCase().contains('park') ||
        context.toLowerCase().contains('safari')) {
      alerts.add(
        'Stay with your ranger or guide and keep a safe distance from wildlife.',
      );
    }
    if (alerts.isEmpty) {
      alerts.add(
        'Keep your phone charged and share your itinerary with a trusted contact.',
      );
    }
    return SafetyAdvice(
      alerts: alerts,
      tips: [
        'Keep emergency numbers accessible: Police 999, medical services 112.',
        'Check local conditions before travelling and keep location sharing available when needed.',
        'Your context: $context in $location during the $timeOfDay.',
      ],
      isFallback: true,
    );
  }

  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final response = await _request('/translate', {
      'text': text,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    });
    final translated = response?['translatedText'];
    if (translated is String && translated.isNotEmpty) return translated;

    final common = <String, String>{
      'hello|Luganda': 'Oli otya?',
      'thank you|Luganda': 'Weebale',
      'where is the nearest hospital?|Luganda':
          'Eddwaliro erisinga okumpi liri ludda wa?',
      'hello|Swahili': 'Jambo',
      'thank you|Swahili': 'Asante',
    };
    final fallback = common['${text.trim().toLowerCase()}|$targetLanguage'];
    return fallback ??
        'AI translation is not connected yet. Configure SAFEUG_AI_ENDPOINT to enable live $targetLanguage translations.';
  }

  Future<CommunityAnalysis> analyzeReport({
    required String reportType,
    required String location,
    required String description,
  }) async {
    final response = await _request('/community-report', {
      'reportType': reportType,
      'location': location,
      'description': description,
    });
    if (response != null) {
      return CommunityAnalysis(
        urgency: (response['urgency'] as String?) ?? 'Medium',
        category: (response['category'] as String?) ?? reportType,
        analysis:
            (response['analysis'] as String?) ?? 'Report received for review.',
        recommendedAction:
            (response['recommendedAction'] as String?) ??
            'Stay safe and follow local authority guidance.',
      );
    }

    final highPriority =
        reportType == 'suspicious-activity' ||
        reportType == 'human-wildlife-conflict' ||
        reportType == 'illegal-encroachment';
    return CommunityAnalysis(
      urgency: highPriority ? 'High' : 'Medium',
      category: reportType.replaceAll('-', ' '),
      analysis:
          'A $reportType report was submitted for $location. The details will help local responders assess the situation.',
      recommendedAction: highPriority
          ? 'Keep a safe distance, do not intervene, and notify the nearest ranger or police unit.'
          : 'If safe, preserve useful details and follow up with local authorities if the situation changes.',
      isFallback: true,
    );
  }

  Future<Map<String, dynamic>?> _request(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (endpoint.isEmpty) return null;
    try {
      final uri = Uri.parse(endpoint)
          .resolve(path.startsWith('/') ? path.substring(1) : path);
      final response = await _client
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return const [];
  }
}
