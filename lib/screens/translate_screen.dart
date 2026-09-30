import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../services/ai_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _text = TextEditingController();
  final _ai = AiService();
  String _source = 'English';
  String _target = 'Luganda';
  String? _translated;
  bool _loading = false;

  static const languages = [
    'English',
    'Luganda',
    'Swahili',
    'Runyakitara',
    'Acholi',
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    if (_text.text.trim().isEmpty) {
      showSafeSnackBar(context, 'Enter a phrase to translate.', error: true);
      return;
    }
    setState(() => _loading = true);
    final result = await _ai.translate(
      text: _text.text,
      sourceLanguage: _source,
      targetLanguage: _target,
    );
    if (mounted) {
      setState(() {
        _translated = result;
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
          title: 'Language Translator',
          subtitle: 'Bridge the communication gap with local communities.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'AI-powered translator',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'Translate common phrases into a local Ugandan language.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _text,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Text to translate',
                  hintText: 'e.g. Where is the nearest hospital?',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _languageDropdown(
                      'From',
                      _source,
                      (value) => setState(() => _source = value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _languageDropdown(
                      'To',
                      _target,
                      (value) => setState(() => _target = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loading ? null : _translate,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.translate_rounded, size: 17),
                label: Text(_loading ? 'Translating...' : 'Translate'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              if (_translated != null) ...[
                const SizedBox(height: 22),
                const Text(
                  'Translation',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _translated!,
                          style: const TextStyle(fontSize: 16, height: 1.35),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _translated!));
                          showSafeSnackBar(
                            context,
                            'Translation copied to clipboard.',
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _languageDropdown(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: languages
          .map(
            (language) => DropdownMenuItem(
              value: language,
              child: Text(language, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
