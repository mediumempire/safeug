import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_store.dart';
import 'guide_card.dart';
import 'incident_contract.dart';

class DiscoveryHeader extends StatelessWidget {
  const DiscoveryHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });
  final String eyebrow, title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xff064e3b), Color(0xff167657)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xffd9eeac), size: 30),
        const SizedBox(height: 18),
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: Color(0xffc9ddb8),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(color: Color(0xffd7e8df), height: 1.6),
        ),
      ],
    ),
  );
}

class GuideDirectory extends StatelessWidget {
  const GuideDirectory({super.key, required this.store});
  final LocalStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const DiscoveryHeader(
          eyebrow: 'People who know the way',
          title: 'Find your local guide.',
          description:
              'Explore visitor ratings, choose a guide and start a conversation on WhatsApp.',
          icon: Icons.hiking,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you a tour guide?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Apply to be listed. SafeUG administration reviews applications before publication.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => GuideApplicationForm(store: store),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Sign up as a guide'),
                ),
                for (final r in store.records('guideApplications'))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Your application: ${r['status']}${r['reviewNote'] == null ? '' : '\n${r['reviewNote']}'}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (store.records('guides').isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Guides will appear here after their listings are approved.',
            ),
          ),
        for (final guide in store.records('guides'))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GuideCard(store: store, guide: guide),
          ),
      ],
    ),
  );
}

class GuideApplicationForm extends StatefulWidget {
  const GuideApplicationForm({super.key, required this.store});
  final LocalStore store;
  @override
  State<GuideApplicationForm> createState() => _GuideApplicationFormState();
}

class _GuideApplicationFormState extends State<GuideApplicationForm> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in [
      'name',
      'phone',
      'email',
      'area',
      'description',
      'languages',
      'license',
    ])
      key: TextEditingController(),
  };
  bool consent = false, busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!consent) {
      setState(
        () => error =
            'Please agree to share your application with administration.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.save('guideApplications', {
        for (final e in fields.entries) e.key: e.value.text.trim(),
        'consent': true,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application received. Administration will review your listing.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guide signup')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Text(
                'Share your local expertise.',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your contact details and introduction will be published only after approval. Email and licence details remain private to administration.',
              ),
              const SizedBox(height: 24),
              for (final e in {
                'name': 'Guide or business name',
                'phone': 'WhatsApp number (+256…)',
                'email': 'Email (optional)',
                'area': 'Where do you guide?',
                'languages': 'Languages spoken (optional)',
                'license': 'Licence / registration reference (optional)',
                'description': 'Introduce your services',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: fields[e.key],
                    enabled: !busy,
                    decoration: InputDecoration(labelText: e.value),
                    maxLength: e.key == 'description' ? 2000 : 200,
                    maxLines: e.key == 'description' ? 4 : 1,
                    keyboardType: e.key == 'phone'
                        ? TextInputType.phone
                        : e.key == 'email'
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (['name', 'area', 'description'].contains(e.key) &&
                          v.isEmpty) {
                        return 'Please complete this field';
                      }
                      if (e.key == 'phone' &&
                          !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(v)) {
                        return 'Use country code, for example +256712345678';
                      }
                      if (e.key == 'email' &&
                          v.isNotEmpty &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                        return 'Enter a valid email';
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
                    : (v) => setState(() => consent = v ?? false),
                title: const Text(
                  'I agree to administrative review and publication of my approved guide profile.',
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Submitting…' : 'Submit application'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class GuideApplicationReview extends StatelessWidget {
  const GuideApplicationReview({super.key, required this.store});
  final LocalStore store;
  Future<void> review(
    BuildContext context,
    Record record,
    String status,
  ) async {
    final note = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          status == 'Approved'
              ? 'Approve and publish guide?'
              : 'Reject application?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${record['name']}'),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Review note (visible to applicant)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    final text = note.text;
    note.dispose();
    if (yes != true) return;
    try {
      await store.reviewGuide('${record['id']}', status, text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'Approved'
                  ? 'Guide published to the mobile directory.'
                  : 'Application updated.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final rows = [...store.records('guideApplications')]
        ..sort((a, b) => '${b['updatedAt']}'.compareTo('${a['updatedAt']}'));
      return ListView(
        children: [
          const Text(
            'Guide applications',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Review contact details before making a profile public.'),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const Text('New guide applications will arrive here in real time.'),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['name']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Chip(label: Text('${r['status']}')),
                      for (final key in [
                        'phone',
                        'email',
                        'area',
                        'languages',
                        'license',
                        'description',
                        'reviewNote',
                      ])
                        if ('${r[key] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText('$key: ${r[key]}'),
                          ),
                      Wrap(
                        spacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: r['status'] == 'Approved'
                                ? null
                                : () => review(context, r, 'Approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve & publish'),
                          ),
                          OutlinedButton(
                            onPressed: r['status'] == 'Rejected'
                                ? null
                                : () => review(context, r, 'Rejected'),
                            child: const Text('Reject / unpublish'),
                          ),
                        ],
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

List<Record> recommendedSafetyTips(
  List<Record> tips,
  String location,
  String activity,
  String time,
) {
  final context = '$location $activity $time'.toLowerCase();
  int score(Record tip) {
    final tags = '${tip['tags'] ?? ''}'.toLowerCase().split(' ');
    return tags.fold(
      0,
      (n, t) =>
          n +
          (t == 'general'
              ? 1
              : t.isNotEmpty && context.contains(t)
              ? 3
              : 0),
    );
  }

  return [...tips.where((tip) => score(tip) > 0)]
    ..sort((a, b) => score(b).compareTo(score(a)));
}

class SafetyExplorer extends StatefulWidget {
  const SafetyExplorer({super.key, required this.store});
  final LocalStore store;
  @override
  State<SafetyExplorer> createState() => _SafetyExplorerState();
}

class _SafetyExplorerState extends State<SafetyExplorer> {
  final location = TextEditingController(), activity = TextEditingController();
  String time = 'Day';
  bool generated = false;
  String? locationNote;
  bool locating = false;
  @override
  void initState() {
    super.initState();
    final hour = DateTime.now().hour;
    time = hour < 6 || hour >= 19
        ? 'Night'
        : hour >= 17
        ? 'Evening'
        : 'Day';
    unawaited(useLocation());
  }

  Future<void> useLocation() async {
    setState(() => locating = true);
    try {
      final position = await widget.store.locate();
      Record? nearest;
      double distance = 50000;
      for (final park in widget.store.records('parks')) {
        if (park['latitude'] is! num || park['longitude'] is! num) continue;
        final metres = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          (park['latitude'] as num).toDouble(),
          (park['longitude'] as num).toDouble(),
        );
        if (metres < distance) {
          distance = metres;
          nearest = park;
        }
      }
      if (!mounted) return;
      setState(() {
        if (location.text.isEmpty) {
          location.text = nearest == null
              ? 'Current location'
              : '${nearest['name']}';
        }
        locationNote = nearest == null
            ? 'Device location received. Add a destination name for more specific tips.'
            : 'Nearest listed area, approximately ${(distance / 1000).toStringAsFixed(0)} km away. Confirm your actual destination.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => locationNote =
              'Location unavailable. You can enter a destination instead.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  void dispose() {
    location.dispose();
    activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final tips = widget.store.records('tips');
      final results = recommendedSafetyTips(
        tips,
        location.text,
        activity.text,
        time,
      );
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const DiscoveryHeader(
            eyebrow: 'A little preparation goes a long way',
            title: 'Travel with context.',
            description:
                'Recommendations for your destination, activity and time of day.',
            icon: Icons.health_and_safety_outlined,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Plan your next stop',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'Kampala, Bwindi, Jinja…',
                    ),
                    onChanged: (_) => setState(() => generated = false),
                  ),
                  TextButton.icon(
                    onPressed: locating ? null : useLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      locating
                          ? 'Finding your location…'
                          : 'Use device location',
                    ),
                  ),
                  if (locationNote != null)
                    Text(locationNote!, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: activity,
                    decoration: const InputDecoration(
                      labelText: 'Travel activity',
                      hintText: 'Gorilla trekking, safari, city tour…',
                    ),
                    onChanged: (_) => setState(() => generated = false),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: time,
                    decoration: const InputDecoration(labelText: 'Time of day'),
                    items: ['Day', 'Evening', 'Night']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      time = v!;
                      generated = false;
                    }),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => setState(() => generated = true),
                    icon: const Icon(Icons.tips_and_updates_outlined),
                    label: const Text('Get safety tips'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (generated) ...[
            Text(
              'For ${location.text.trim().isEmpty ? 'your trip' : location.text.trim()}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Context-based guidance, not a live threat warning. Check with your guide for current local conditions.',
            ),
            const SizedBox(height: 14),
            for (final tip in results) _tip(context, tip),
            if (results.isEmpty)
              const Text(
                'Keep your emergency contacts handy, share your plans, and confirm local guidance before setting out.',
              ),
            const Divider(height: 32),
          ],
          const Text(
            'Your safety library',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (tips.isEmpty)
            const Text(
              'Connect to SafeUG to download the safety library. Keep a charged phone, share your route and follow your guide’s instructions.',
            ),
          for (final tip in tips) _tip(context, tip),
        ],
      );
    },
  );
  Widget _tip(BuildContext context, Record tip) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tip['category'] ?? 'Travel advice'}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${tip['name']}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('${tip['description']}', style: const TextStyle(height: 1.6)),
            if ('${tip['sourceUrl'] ?? ''}'.startsWith('https://'))
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse('${tip['sourceUrl']}'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Source guidance'),
              ),
          ],
        ),
      ),
    ),
  );
}

class ProtectedAreaExplorer extends StatefulWidget {
  const ProtectedAreaExplorer({super.key, required this.store});
  final LocalStore store;
  @override
  State<ProtectedAreaExplorer> createState() => _ProtectedAreaExplorerState();
}

class _ProtectedAreaExplorerState extends State<ProtectedAreaExplorer> {
  String query = '', category = 'All';
  static const groups = [
    'National parks',
    'Wildlife reserves',
    'Community areas',
    'Sanctuaries',
  ];
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final records = widget.store.records('parks');
      final entries = records
          .where(
            (r) => r['referenceOnly'] != true && r['sourceWorkbook'] != null,
          )
          .toList();
      final filtered = records
          .where(
            (r) =>
                (category == 'All' || r['categoryGroup'] == category) &&
                '${r['name']} ${r['region']} ${r['districts']} ${r['mammals']}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      final counts = {
        for (final g in groups)
          g: entries.where((r) => r['categoryGroup'] == g).length,
      };
      final largest = [...entries.where((r) => r['areaKm2'] is num)]
        ..sort((a, b) => (b['areaKm2'] as num).compareTo(a['areaKm2'] as num));
      final maxCount = counts.values.fold<int>(1, (a, b) => a > b ? a : b);
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const DiscoveryHeader(
            eyebrow: 'The conservation estate',
            title: 'Find your next wild place.',
            description:
                'Habitats, wildlife and visitor experiences from the supplied Uganda conservation factbook.',
            icon: Icons.forest_outlined,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entries.length} named listings',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Catalogue entries by category'),
                  const SizedBox(height: 18),
                  for (final g in groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(g)),
                              Text(
                                '${counts[g]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            label: '$g: ${counts[g]} entries',
                            child: LinearProgressIndicator(
                              value: counts[g]! / maxCount,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Sanctuary listings include historic sites, overlaps and an education centre. One additional reference entry groups other sanctuary names.',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (largest.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Largest listed areas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Working figures in km². Areas may overlap; they are not added into a national total.',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    for (final r in largest.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['name']} · ${r['areaKm2']} km²',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value:
                                  (r['areaKm2'] as num) /
                                  (largest.first['areaKm2'] as num),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 22),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search places, districts or wildlife',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final g in ['All', ...groups])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: category == g,
                      onSelected: (_) => setState(() => category = g),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No matching places. Try a different category or search.',
              ),
            ),
          for (final r in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ProtectedAreaDetail(record: r),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              r['categoryGroup'] == 'National parks'
                                  ? Icons.forest
                                  : Icons.landscape_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${r['categoryGroup'] ?? r['category'] ?? 'Protected area'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_outward, size: 18),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${r['name']}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${r['region'] ?? r['area'] ?? ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${r['habitat'] ?? r['description'] ?? ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          r['areaKm2'] is num
                              ? '${r['areaKm2']} km² · indicative area'
                              : 'Area not supplied',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class ProtectedAreaDetail extends StatelessWidget {
  const ProtectedAreaDetail({super.key, required this.record});
  final Record record;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore a protected area')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DiscoveryHeader(
              eyebrow: '${record['categoryGroup'] ?? 'Protected area'}',
              title: '${record['name']}',
              description: '${record['region'] ?? record['area'] ?? ''}',
              icon: Icons.park_outlined,
            ),
            const SizedBox(height: 20),
            for (final section in {
              'activities': 'Experiences & activities',
              'habitat': 'Landscape & habitat',
              'mammals': 'Notable mammals',
              'birds': 'Birdlife',
              'floraFauna': 'Other wildlife & plants',
              'districts': 'Districts',
              'aliases': 'Also known as',
              'category': 'Workbook classification',
              'legalClass': 'Legal classification in the workbook',
              'iucn': 'IUCN category in the workbook',
              'gazetted': 'Gazettement / status year',
              'areaKm2': 'Working area (km²)',
              'areaHectares': 'Working area (hectares)',
              'areaNotes': 'Area qualifications',
              'coordinates': 'Approximate reference coordinates',
              'designations': 'Designations',
              'governance': 'Governance & partners',
              'tourism': 'Tourism context',
              'rangerNotes': 'Ranger context (not staffing counts)',
              'threats': 'Conservation pressures',
              'notes': 'Important notes',
            }.entries)
              if (record[section.key] != null &&
                  '${record[section.key]}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.value,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            '${record[section.key]}',
                            style: const TextStyle(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (record['sourceWorkbook'] != null)
              Text(
                'Source: ${record['sourceWorkbook']}\n${record['sourceSheet']}, row ${record['sourceRow']}. Approximate planning information; confirm current access and conditions with UWA or your guide.',
                style: const TextStyle(fontSize: 11, height: 1.6),
              ),
          ],
        ),
      ),
    ),
  );
}

class RangerCheckIn extends StatefulWidget {
  const RangerCheckIn({
    super.key,
    required this.store,
    required this.onCheckIn,
  });
  final LocalStore store;
  final VoidCallback onCheckIn;
  @override
  State<RangerCheckIn> createState() => _RangerCheckInState();
}

class _RangerCheckInState extends State<RangerCheckIn> {
  bool busy = false;
  String? error;
  Future<void> rangerDown() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Send a ranger-down emergency?'),
        content: const Text(
          'Use this when a ranger is injured or in immediate danger. The alert goes to SafeUG administration with your available device location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Send emergency'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final p = widget.store.devicePosition;
      final recent =
          p != null && DateTime.now().difference(p.timestamp).inSeconds < 90;
      final id = await widget.store.signal({
        'type': 'Ranger down',
        'name': 'Ranger-down emergency',
        'description': 'A ranger has requested urgent assistance.',
        'reporter': '${widget.store.touristProfile?['name'] ?? 'Ranger'}',
        'locationSource': recent ? 'device' : 'unavailable',
        if (recent) ...{
          'latitude': p.latitude,
          'longitude': p.longitude,
          'accuracy': p.accuracy,
          'locationCapturedAt': p.timestamp.toUtc().toIso8601String(),
        },
      });
      if (!recent) unawaited(attachLocation(id));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> attachLocation(String id) async {
    try {
      final p = await widget.store.locate();
      await widget.store.updateIncidentLocation(id, {
        'latitude': p.latitude,
        'longitude': p.longitude,
        'accuracy': p.accuracy,
        'locationCapturedAt': p.timestamp.toUtc().toIso8601String(),
      });
    } catch (_) {
      // The emergency remains queued or sent when GPS is unavailable.
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.store.locate().then<void>((_) {}, onError: (Object _) {}));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final alerts = widget.store.ownIncidents
          .where(
            (r) =>
                normalizeIncidentType(r['type']) == 'Ranger down' &&
                isOpenIncident(r),
          )
          .toList();
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const DiscoveryHeader(
            eyebrow: 'For the people protecting wildlife',
            title: 'Check in. Stay connected.',
            description:
                'Share your welfare update or request urgent help for a ranger.',
            icon: Icons.monitor_heart_outlined,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: widget.onCheckIn,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Record a welfare check-in'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.emergency,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ranger down',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'For an injured ranger or an immediate threat. Your emergency is prioritised in the admin dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: busy || alerts.isNotEmpty ? null : rangerDown,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  icon: const Icon(Icons.sos),
                  label: Text(
                    busy
                        ? 'Saving alert…'
                        : alerts.isNotEmpty
                        ? 'Emergency active'
                        : 'Ranger-down emergency',
                  ),
                ),
              ],
            ),
          ),
          for (final r in alerts)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                widget.store.isQueued('${r['id']}')
                    ? 'Saved on this device. Waiting for a connection to send.'
                    : 'Admin status: ${r['status']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 14),
          const Text(
            'For immediate help, also use your established radio channel or call emergency services.',
          ),
        ],
      );
    },
  );
}
