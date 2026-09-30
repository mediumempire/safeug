import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_store.dart';

/// Uganda national numbers are accepted; other countries need their country code.
Uri? guideWhatsAppUri(String phone) {
  if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone.trim())) return null;
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    if (digits.length != 10) return null;
    digits = '256${digits.substring(1)}';
  }
  if (!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(digits)) return null;
  if (digits.startsWith('256') && digits.length != 12) return null;
  return Uri.https('wa.me', '/$digits');
}

class GuideRatingSummary extends StatelessWidget {
  const GuideRatingSummary({super.key, required this.guide});
  final Record guide;
  @override
  Widget build(BuildContext context) {
    final count = (guide['ratingCount'] as num?)?.toInt() ?? 0;
    final rating = (guide['rating'] as num?)?.toDouble() ?? 0;
    final label = count == 0
        ? 'No ratings yet'
        : '${rating.toStringAsFixed(1)} / 5 ($count ${count == 1 ? 'rating' : 'ratings'})';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    rating >= i
                        ? Icons.star_rounded
                        : rating >= i - .5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.amber.shade300
                        : Colors.amber.shade800,
                    size: 20,
                  ),
              ],
            ),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.store,
    required this.guide,
    this.openChat,
  });
  final LocalStore store;
  final Record guide;
  final Future<bool> Function(Uri)? openChat;

  @override
  Widget build(BuildContext context) {
    final phone = '${guide['phone'] ?? ''}';
    final chat = guideWhatsAppUri(phone);
    final mine = guide['myRating'] as num?;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${guide['name']}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if ('${guide['area'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${guide['area']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            GuideRatingSummary(guide: guide),
            if ('${guide['description'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${guide['description']}'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF087C46),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  label: const Text('Contact now'),
                  onPressed: chat == null
                      ? null
                      : () async {
                          try {
                            final ok =
                                await (openChat?.call(chat) ??
                                    launchUrl(
                                      chat,
                                      mode: LaunchMode.externalApplication,
                                    ));
                            if (!ok) {
                              throw StateError('Could not open WhatsApp');
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open WhatsApp. Try calling the guide.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
                if (!store.adminApp && guide['id'] != null)
                  TextButton.icon(
                    icon: const Icon(Icons.star_outline_rounded),
                    label: Text(
                      mine == null
                          ? 'Rate guide'
                          : 'Your rating: ${mine.toInt()}/5',
                    ),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          _RateGuideDialog(store: store, guide: guide),
                    ),
                  ),
              ],
            ),
            if (chat == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'WhatsApp contact unavailable',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Chat on WhatsApp', style: TextStyle(fontSize: 12)),
              ),
            if (phone.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.call, size: 18),
                label: Text(phone),
                onPressed: () async {
                  try {
                    if (!await launchUrl(Uri(scheme: 'tel', path: phone))) {
                      throw StateError('Unavailable');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Calling is unavailable on this device.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RateGuideDialog extends StatefulWidget {
  const _RateGuideDialog({required this.store, required this.guide});
  final LocalStore store;
  final Record guide;
  @override
  State<_RateGuideDialog> createState() => _RateGuideDialogState();
}

class _RateGuideDialogState extends State<_RateGuideDialog> {
  late int score = (widget.guide['myRating'] as num?)?.toInt() ?? 0;
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text('Rate ${widget.guide['name']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was your experience?'),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i ${i == 1 ? 'star' : 'stars'}',
                  isSelected: score == i,
                  onPressed: busy ? null : () => setState(() => score = i),
                  icon: Icon(
                    i <= score
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber.shade700,
                    size: 30,
                  ),
                ),
            ],
          ),
          Text(score == 0 ? 'Choose 1 to 5 stars' : '$score out of 5'),
          const SizedBox(height: 12),
          const Text(
            'You can update your rating at any time.',
            textAlign: TextAlign.center,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || score == 0
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.store.rateGuide(
                      '${widget.guide['id']}',
                      score,
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error =
                            'Rating could not be saved. Check your connection and try again.';
                      });
                    }
                  }
                },
          child: Text(busy ? 'Saving...' : 'Save rating'),
        ),
      ],
    ),
  );
}
