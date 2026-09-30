import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/models.dart';
import '../services/ai_service.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  final _contextController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _ai = AiService();
  String _location = 'Kampala, Uganda';
  String _timeOfDay = 'day';
  SafetyAdvice? _advice;
  bool _loading = false;

  static const locations = [
    'Kampala, Uganda',
    'Bwindi Impenetrable National Park, Uganda',
    'Murchison Falls National Park, Uganda',
    'Jinja, Uganda',
    'Entebbe, Uganda',
    'Nairobi, Kenya',
    'Cairo, Egypt',
    'Cape Town, South Africa',
    'London, UK',
    'Paris, France',
    'Dubai, UAE',
    'Mumbai, India',
  ];

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final advice = await _ai.generateSafetyAdvice(
      location: _location,
      context: _contextController.text.trim(),
      timeOfDay: _timeOfDay,
    );
    if (mounted) {
      setState(() {
        _advice = advice;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        const PageIntro(
          title: 'Safety Alerts',
          subtitle: 'Get personalized safety tips for your trip.',
        ),
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Generate safety guidance',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your current context to receive advice from the SafeUG safety advisor.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _location,
                  decoration: const InputDecoration(
                    labelText: 'Current location',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  items: locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location,
                          child: Text(
                            location,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _location = value ?? _location),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contextController,
                  decoration: const InputDecoration(
                    labelText: 'Travel context / activity',
                    hintText: 'e.g. city tour, wildlife safari',
                    prefixIcon: Icon(Icons.explore_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _timeOfDay,
                  decoration: const InputDecoration(
                    labelText: 'Time of day',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'morning', child: Text('Morning')),
                    DropdownMenuItem(value: 'day', child: Text('Day')),
                    DropdownMenuItem(value: 'evening', child: Text('Evening')),
                    DropdownMenuItem(value: 'night', child: Text('Night')),
                  ],
                  onChanged: (value) =>
                      setState(() => _timeOfDay = value ?? _timeOfDay),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(_loading ? 'Generating...' : 'Get alerts'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_advice != null) ...[
          const SizedBox(height: 18),
          if (_advice!.isFallback) const _FallbackNotice(),
          const SizedBox(height: 10),
          _AdviceSection(
            title: 'Real-time alerts',
            icon: Icons.warning_amber_rounded,
            color: AppColors.danger,
            items: _advice!.alerts,
            filled: true,
          ),
          const SizedBox(height: 14),
          _AdviceSection(
            title: 'Personalized tips',
            icon: Icons.info_outline_rounded,
            color: AppColors.primary,
            items: _advice!.tips,
          ),
        ],
      ],
    );
  }
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
            'Showing built-in guidance. Connect the AI gateway for live personalized alerts.',
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

class _AdviceSection extends StatelessWidget {
  const _AdviceSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.filled = false,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: filled
                  ? color.withValues(alpha: .1)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .14)),
            ),
            child: Text(
              item,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}
