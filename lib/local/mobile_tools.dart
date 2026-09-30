import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'local_store.dart';
import 'guide_card.dart';
import 'camera_capture.dart';
import 'device_location.dart';
import 'evidence_video.dart';
import 'incident_contract.dart';
import 'theme_controller.dart';
import '../app_theme.dart';

class TouristRegistration extends StatefulWidget {
  const TouristRegistration({super.key, required this.store});
  final LocalStore store;
  @override
  State<TouristRegistration> createState() => _TouristRegistrationState();
}

class _TouristRegistrationState extends State<TouristRegistration> {
  final form = GlobalKey<FormState>();
  static const labels = {
    'name': 'Full name',
    'phone': 'Phone number',
    'email': 'Email (optional)',
    'country': 'Country (optional)',
    'area': 'Park / area (optional)',
    'emergencyContactName': 'Emergency contact name (optional)',
    'emergencyContactPhone': 'Emergency contact phone (optional)',
  };
  late final fields = {
    for (final key in labels.keys)
      key: TextEditingController(
        text: '${widget.store.touristProfile?[key] ?? ''}',
      ),
  };
  bool consent = false;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!consent) {
      setState(
        () => error =
            'Please agree to share your profile with SafeUG administrators.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.registerTourist({
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
        'consent': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tourist registration')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final entry in labels.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: fields[entry.key],
                    maxLength: entry.key == 'phone' ? 40 : 200,
                    decoration: InputDecoration(
                      labelText: entry.value,
                      counterText: '',
                    ),
                    keyboardType: entry.key.toLowerCase().contains('phone')
                        ? TextInputType.phone
                        : entry.key == 'email'
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (entry.key == 'name' && text.isEmpty) {
                        return 'Enter your full name';
                      }
                      if (entry.key == 'phone' &&
                          !RegExp(r'^[+\d ()-]{5,40}$').hasMatch(text)) {
                        return 'Enter a valid phone number';
                      }
                      if (entry.key == 'email' &&
                          text.isNotEmpty &&
                          !RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(text)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: busy
                    ? null
                    : (value) => setState(() => consent = value!),
                title: const Text(
                  'I agree to share these details with SafeUG administrators for tourist safety.',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : submit,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(busy ? 'Saving...' : 'Save registration'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key, required this.store});
  final LocalStore store;
  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your username and password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.login(username.text, password.text);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff003a2d),
    body: Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: ThemeToggleButton(),
              ),
              Image.asset(
                safeUgLogoAsset,
                height: 128,
                fit: BoxFit.contain,
                semanticLabel: 'SafeUG logo',
              ),
              const SizedBox(height: 20),
              const Text(
                'SafeUG Administration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: username,
                enabled: !busy,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                enabled: !busy,
                autofillHints: const [AutofillHints.password],
                obscureText: true,
                onSubmitted: (_) => busy ? null : submit(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Signing in...' : 'Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PublishedDirectory extends StatelessWidget {
  const PublishedDirectory({
    super.key,
    required this.store,
    required this.collection,
  });
  final LocalStore store;
  final String collection;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final records = store.records(collection);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No entries published yet.'),
            ),
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: collection == 'guides'
                  ? GuideCard(store: store, guide: r)
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['name']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (r['area'] != null) Text('${r['area']}'),
                            const SizedBox(height: 8),
                            Text('${r['description'] ?? ''}'),
                            if ('${r['phone'] ?? ''}'.isNotEmpty)
                              TextButton.icon(
                                icon: const Icon(Icons.call),
                                label: Text('${r['phone']}'),
                                onPressed: () async {
                                  final ok = await launchUrl(
                                    Uri(scheme: 'tel', path: '${r['phone']}'),
                                  );
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Calling is unavailable on this device.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
        ],
      );
    },
  );
}

class FieldReport extends StatefulWidget {
  const FieldReport({
    super.key,
    required this.store,
    this.pickMedia,
    this.currentPosition,
  });
  final LocalStore store;
  final Future<XFile?> Function(ImageSource source, bool video)? pickMedia;
  final Future<Position> Function()? currentPosition;
  @override
  State<FieldReport> createState() => _FieldReportState();
}

class _FieldReportState extends State<FieldReport> {
  final description = TextEditingController();
  final area = TextEditingController();
  late final reporter = TextEditingController(
    text: '${widget.store.touristProfile?['name'] ?? ''}',
  );
  late final phone = TextEditingController(
    text: '${widget.store.touristProfile?['phone'] ?? ''}',
  );
  final files = <Record>[];
  String type = 'Suspicious Activity';
  String severity = 'Medium';
  DateTime occurredAt = DateTime.now();
  bool busy = false;
  bool picking = false;
  bool locating = false;
  String? error;
  String? locationError;
  Position? position;
  bool get working => busy || picking || locating;

  @override
  void initState() {
    super.initState();
    final cached = widget.store.devicePosition;
    position =
        cached != null &&
            DateTime.now().difference(cached.timestamp).inSeconds < 90
        ? cached
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(locate());
    });
  }

  @override
  void dispose() {
    description.dispose();
    area.dispose();
    reporter.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source, bool video) async {
    if (working) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      if (files.length >= 4) throw StateError('Maximum four attachments.');
      final picker = ImagePicker();
      final file = widget.pickMedia != null
          ? await widget.pickMedia!(source, video)
          : kIsWeb && source == ImageSource.camera
          ? await captureBrowserMedia(context, video)
          : video
          ? await picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 15),
            )
          : await picker.pickImage(
              source: source,
              imageQuality: 70,
              maxWidth: 1600,
            );
      if (file == null) return;
      final limit = (kIsWeb ? 2 : 8) * 1024 * 1024;
      if (await file.length() > limit) {
        throw StateError(
          'File is too large. Choose a smaller photo or shorter video.',
        );
      }
      final bytes = await file.readAsBytes();
      final size =
          files.fold<int>(0, (sum, r) => sum + (r['size'] as int)) +
          bytes.length;
      if (size > limit) {
        throw StateError(
          'Attachments must total less than ${kIsWeb ? 2 : 8} MB. Choose a shorter video.',
        );
      }
      final mime = lookupMimeType(file.name, headerBytes: bytes);
      if (![
        'image/jpeg',
        'image/png',
        'image/webp',
        'video/mp4',
        'video/webm',
        'video/quicktime',
      ].contains(mime)) {
        throw StateError('Use JPEG, PNG, WebP, MP4, WebM or MOV.');
      }
      if (mounted) {
        setState(
          () => files.add({
            'name': file.name,
            'mime': mime,
            'base64': base64Encode(bytes),
            'size': bytes.length,
            // Kept only for local video playback; never sent to the server.
            'localPath': file.path,
          }),
        );
      }
    } on PlatformException catch (failure) {
      if (mounted) {
        setState(
          () => error =
              failure.code.toLowerCase().contains('denied') ||
                  failure.code.toLowerCase().contains('restricted')
              ? 'Camera or gallery access is blocked. Allow access in device or browser settings and retry.'
              : 'The camera or gallery could not open. Try another capture option or upload a file from your gallery.',
        );
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> locate() async {
    if (working) return;
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final captured = await widget.store.locate(
        provider: widget.currentPosition,
      );
      if (mounted) setState(() => position = captured);
    } catch (failure) {
      if (mounted) {
        setState(
          () => locationError = failure is DeviceLocationException
              ? failure.message
              : 'Current location is unavailable. Retry or enter an area or landmark.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> chooseOccurrence() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(occurredAt),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      setState(() => error = 'The incident time cannot be in the future.');
      return;
    }
    setState(() {
      occurredAt = selected;
      error = null;
    });
  }

  Future<void> submit() async {
    if (working) return;
    if (description.text.trim().isEmpty) {
      setState(() => error = 'Describe what happened.');
      return;
    }
    if (position == null && area.text.trim().isEmpty) {
      setState(
        () => error =
            'Add current location or enter an area or landmark so the team can find the incident.',
      );
      return;
    }
    if (phone.text.trim().isNotEmpty &&
        !RegExp(r'^[+\d ()-]{5,40}$').hasMatch(phone.text.trim())) {
      setState(
        () => error = 'Enter a valid contact phone number, or leave it blank.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final report = <String, dynamic>{
        'type': type,
        'severity': severity,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'description': description.text.trim(),
        'area': area.text.trim(),
        'reporter': reporter.text.trim(),
        'phone': phone.text.trim(),
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'accuracy': position?.accuracy,
        'locationSource': position == null ? 'landmark' : 'device',
        if (position != null)
          'locationCapturedAt': position!.timestamp.toUtc().toIso8601String(),
        'evidence': files
            .map(
              (file) => {
                for (final entry in file.entries)
                  if (entry.key != 'localPath') entry.key: entry.value,
              },
            )
            .toList(),
      };
      if (widget.store.adminApp) {
        await widget.store.save('incidents', report);
      } else {
        await widget.store.signal(report);
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.store.adminApp
                  ? 'Incident report and evidence saved.'
                  : 'Report saved on this device. It will send to SafeUG administrators when connected.',
            ),
          ),
        );
      }
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget mediaButton(
    String label,
    IconData icon,
    ImageSource source,
    bool video,
  ) => Tooltip(
    message: label,
    child: OutlinedButton.icon(
      onPressed: working ? null : () => pick(source, video),
      icon: Icon(icon),
      label: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final occurrenceLabel =
        '${localizations.formatMediumDate(occurredAt)} at ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt))}';
    return Scaffold(
      appBar: AppBar(title: const Text('Report incident')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SMART incident report',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Describe the situation, where it happened, and any people or wildlife involved. Reports are shared with SafeUG administrators.',
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Incident type'),
                  items: incidentTypes
                      .where((value) => value != 'SOS')
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: working
                      ? null
                      : (value) => setState(() => type = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: area,
                  enabled: !busy,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Area or landmark',
                    hintText: 'Park, trail, village or nearby landmark',
                    counterText: '',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: working ? null : locate,
                      icon: Icon(
                        position == null
                            ? Icons.my_location
                            : Icons.location_on,
                      ),
                      label: Text(
                        locating
                            ? 'Finding current location...'
                            : position == null
                            ? 'Add current location'
                            : 'Location attached',
                      ),
                    ),
                    if (position != null)
                      TextButton(
                        onPressed: working
                            ? null
                            : () => setState(() => position = null),
                        child: const Text('Remove location'),
                      ),
                  ],
                ),
                if (locating) const LinearProgressIndicator(),
                if (position != null)
                  Text(
                    'Device location attached (accuracy about ${position!.accuracy.round()} m). Add a landmark for extra context.',
                  ),
                if (locationError != null)
                  Text(
                    locationError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: description,
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText:
                        'Include what you saw, immediate risks, injuries and help needed.',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: incidentSeverities
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: working
                      ? null
                      : (value) => setState(() => severity = value!),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Low: information only · Medium: attention needed · High: urgent risk · Critical: immediate danger',
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('When did it happen?'),
                  subtitle: Text(occurrenceLabel),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: working ? null : chooseOccurrence,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Photos and videos (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Up to 4 attachments, ${kIsWeb ? 2 : 8} MB total. Record short videos of up to 15 seconds. Tap an attachment to preview.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    mediaButton(
                      'Take photo',
                      Icons.camera_alt_outlined,
                      ImageSource.camera,
                      false,
                    ),
                    mediaButton(
                      'Photo from gallery',
                      Icons.photo_library_outlined,
                      ImageSource.gallery,
                      false,
                    ),
                    mediaButton(
                      'Record video',
                      Icons.videocam_outlined,
                      ImageSource.camera,
                      true,
                    ),
                    mediaButton(
                      'Video from gallery',
                      Icons.video_library_outlined,
                      ImageSource.gallery,
                      true,
                    ),
                  ],
                ),
                if (picking) const LinearProgressIndicator(),
                for (final file in files)
                  ListTile(
                    leading: '${file['mime']}'.startsWith('image/')
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              base64Decode('${file['base64']}'),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.image_outlined),
                            ),
                          )
                        : const Icon(Icons.play_circle_outline),
                    contentPadding: EdgeInsets.zero,
                    title: Text('${file['name']}'),
                    subtitle: Text(
                      '${((file['size'] as int) / 1024).round()} KB · Tap to preview',
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          EvidenceViewer(store: widget.store, file: file),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove attachment',
                      onPressed: working
                          ? null
                          : () => setState(() => files.remove(file)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Your contact details (optional)'),
                  subtitle: const Text(
                    'Help administrators follow up on your report.',
                  ),
                  children: [
                    TextField(
                      controller: reporter,
                      enabled: !busy,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      enabled: !busy,
                      maxLength: 40,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact phone number',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: working ? null : submit,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(
                    busy
                        ? 'Saving...'
                        : widget.store.adminApp
                        ? 'Submit report'
                        : 'Send report to admin',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceTranslator extends StatefulWidget {
  const VoiceTranslator({super.key, required this.store});
  final LocalStore store;
  @override
  State<VoiceTranslator> createState() => _VoiceTranslatorState();
}

class _VoiceTranslatorState extends State<VoiceTranslator> {
  final text = TextEditingController();
  final speech = SpeechToText();
  final voice = FlutterTts();
  String source = 'en', target = 'sw', result = '', status = '';
  bool busy = false;
  static const languages = {
    'en': 'English',
    'sw': 'Swahili',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
  };
  static const phrases = [
    {
      'en': 'I need help',
      'sw': 'Nahitaji msaada',
      'fr': "J\u0027ai besoin d\u0027aide",
      'es': 'Necesito ayuda',
      'de': 'Ich brauche Hilfe',
    },
    {
      'en': 'I am lost',
      'sw': 'Nimepotea',
      'fr': 'Je suis perdu',
      'es': 'Estoy perdido',
      'de': 'Ich habe mich verirrt',
    },
    {
      'en': 'Thank you',
      'sw': 'Asante',
      'fr': 'Merci',
      'es': 'Gracias',
      'de': 'Danke',
    },
  ];
  @override
  void dispose() {
    speech.cancel();
    voice.stop();
    text.dispose();
    super.dispose();
  }

  Future<void> listen() async {
    try {
      if (speech.isListening) {
        await speech.stop();
        return;
      }
      if (!await speech.initialize()) {
        throw StateError('Speech recognition is unavailable on this device.');
      }
      final locales = await speech.locales();
      final locale = locales
          .where((l) => l.localeId.startsWith(source))
          .firstOrNull;
      if (locale == null) {
        throw StateError(
          'Selected language is not installed for speech recognition.',
        );
      }
      await speech.listen(
        listenOptions: SpeechListenOptions(localeId: locale.localeId),
        onResult: (r) {
          if (mounted) setState(() => text.text = r.recognizedWords);
        },
      );
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    }
  }

  Future<void> translate() async {
    setState(() {
      busy = true;
      status = '';
      result = '';
    });
    try {
      final phrase = phrases
          .where(
            (p) => p[source]!.toLowerCase() == text.text.trim().toLowerCase(),
          )
          .firstOrNull;
      if (phrase != null) {
        setState(() {
          result = phrase[target]!;
          status = 'Offline phrase';
        });
        return;
      }
      final r = await http
          .post(
            Uri.parse('${widget.store.endpoint}/api/translate'),
            headers: widget.store.headers,
            body: jsonEncode({
              'q': text.text,
              'source': source,
              'target': target,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final body = jsonDecode(r.body) as Map;
      if (r.statusCode != 200) throw StateError('${body['error']}');
      if (mounted) setState(() => result = '${body['translatedText']}');
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      DropdownButtonFormField<int>(
        decoration: const InputDecoration(labelText: 'Offline phrases'),
        items: List.generate(
          phrases.length,
          (i) => DropdownMenuItem(value: i, child: Text(phrases[i][source]!)),
        ),
        onChanged: (i) {
          if (i != null) setState(() => text.text = phrases[i][source]!);
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: source,
        decoration: const InputDecoration(labelText: 'From'),
        items: languages.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() => source = v!),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: target,
        decoration: const InputDecoration(labelText: 'To'),
        items: languages.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() => target = v!),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: text,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: 'Message',
          suffixIcon: IconButton(
            tooltip: 'Dictate message',
            onPressed: listen,
            icon: const Icon(Icons.mic),
          ),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: busy ? null : translate,
        child: Text(busy ? 'Translating...' : 'Translate'),
      ),
      if (status.isNotEmpty)
        Text(status, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 20),
      SelectableText(result, style: const TextStyle(fontSize: 20)),
      if (result.isNotEmpty)
        IconButton(
          tooltip: 'Read translation aloud',
          onPressed: () async {
            await voice.setLanguage(target);
            await voice.speak(result);
          },
          icon: const Icon(Icons.volume_up_outlined),
        ),
    ],
  );
}

class EvidenceViewer extends StatefulWidget {
  const EvidenceViewer({super.key, required this.store, required this.file});
  final LocalStore store;
  final Record file;
  @override
  State<EvidenceViewer> createState() => _EvidenceViewerState();
}

class _EvidenceViewerState extends State<EvidenceViewer> {
  VideoPlayerController? video;
  Uint8List? bytes;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final local = widget.file['base64'] is String;
      final uri = Uri.parse(
        '${widget.store.endpoint}/api/evidence/${widget.file['id']}',
      );
      if (local) {
        bytes = base64Decode(widget.file['base64'] as String);
      } else if ('${widget.file['mime']}'.startsWith('image/') || kIsWeb) {
        final r = await http
            .get(uri, headers: widget.store.headers)
            .timeout(const Duration(seconds: 20));
        if (r.statusCode != 200) {
          throw StateError('Evidence could not be loaded');
        }
        bytes = r.bodyBytes;
      }
      if (!mounted) return;
      if ('${widget.file['mime']}'.startsWith('video/')) {
        final controller = local
            ? attachmentVideoController(
                '${widget.file['localPath'] ?? ''}',
                bytes!,
                '${widget.file['mime']}',
              )
            : VideoPlayerController.networkUrl(
                kIsWeb
                    ? Uri.dataFromBytes(
                        bytes!,
                        mimeType: '${widget.file['mime']}',
                      )
                    : uri,
                httpHeaders: widget.store.headers,
              );
        video = controller;
        await controller.initialize().timeout(const Duration(seconds: 20));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.file['name']}'),
    content: SizedBox(
      width: 560,
      child: error != null
          ? Text(error!)
          : video?.value.isInitialized == true
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: video!.value.aspectRatio,
                  child: VideoPlayer(video!),
                ),
                IconButton(
                  tooltip: video!.value.isPlaying ? 'Pause' : 'Play',
                  onPressed: () {
                    setState(() {
                      video!.value.isPlaying ? video!.pause() : video!.play();
                    });
                  },
                  icon: Icon(
                    video!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
              ],
            )
          : bytes != null && '${widget.file['mime']}'.startsWith('image/')
          ? Image.memory(
              bytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'This image could not be previewed. Remove it and choose another photo if needed.',
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
