import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.user});
  final User user;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _ai = AiService();
  final _firestore = FirestoreService();
  String _type = 'suspicious-activity';
  bool _loading = false;
  CommunityAnalysis? _analysis;

  static const types = <String, String>{
    'suspicious-activity': 'Suspicious activity',
    'animal-sighting': 'Animal sighting',
    'safety-hazard': 'Safety hazard',
    'human-wildlife-conflict': 'Human-wildlife conflict',
    'illegal-encroachment': 'Illegal encroachment',
    'other': 'Other',
  };

  @override
  void dispose() {
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final analysis = await _ai.analyzeReport(
        reportType: _type,
        location: _location.text.trim(),
        description: _description.text.trim(),
      );
      await _firestore.createCommunityReport(
        uid: widget.user.uid,
        reportType: _type,
        location: _location.text.trim(),
        description: _description.text.trim(),
        analysis: analysis,
      );
      if (mounted) {
        setState(() {
          _analysis = analysis;
          _loading = false;
        });
        showSafeSnackBar(context, 'Report submitted and analyzed.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showSafeSnackBar(
          context,
          'Could not submit report: $error',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        const PageIntro(
          title: 'Community Report',
          subtitle:
              'Help protect wildlife and communities by reporting incidents.',
        ),
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SMART community report',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your input helps protect wildlife, habitats, and travellers.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Report type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: types.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location of incident',
                    hintText: 'e.g. near Murchison Falls entrance',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Provide as much detail as possible...',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => showSafeSnackBar(
                    context,
                    'Photo upload will be connected to Firebase Storage next.',
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Add optional photo'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(
                    _loading ? 'Submitting...' : 'Submit SMART report',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_analysis != null) ...[
          const SizedBox(height: 18),
          if (_analysis!.isFallback) const _FallbackNotice(),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SMART analysis result',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Urgency',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    _UrgencyChip(label: _analysis!.urgency),
                  ],
                ),
                const Divider(height: 22),
                Text(
                  'Category: ${_analysis!.category}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Analysis',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _analysis!.analysis,
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Recommended action',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _analysis!.recommendedAction,
                    style: const TextStyle(color: AppColors.ink, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.primary),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Showing built-in analysis. Connect the AI gateway for live SMART analysis.',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color:
          (label == 'High' || label == 'Critical'
                  ? AppColors.danger
                  : AppColors.primary)
              .withValues(alpha: .12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: label == 'High' || label == 'Critical'
            ? AppColors.danger
            : AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}
