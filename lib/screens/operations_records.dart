import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Administrator-maintained operational records, shared through Firestore.
class OperationsRecords extends StatefulWidget {
  const OperationsRecords({
    super.key,
    required this.collection,
    required this.title,
  });
  final String collection;
  final String title;
  @override
  State<OperationsRecords> createState() => _OperationsRecordsState();
}

class _OperationsRecordsState extends State<OperationsRecords> {
  String _query = '';
  CollectionReference<Map<String, dynamic>> get _records =>
      FirebaseFirestore.instance.collection(widget.collection);
  Future<void> _edit([QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final data = doc?.data() ?? {};
    final name = TextEditingController(text: '${data['name'] ?? ''}');
    final area = TextEditingController(text: '${data['area'] ?? ''}');
    final notes = TextEditingController(text: '${data['notes'] ?? ''}');
    String status = '${data['status'] ?? 'Active'}';
    bool busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(doc == null ? 'Add record' : 'Edit record'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: area,
                    decoration: const InputDecoration(
                      labelText: 'Park / assigned area',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items:
                        [
                              'Active',
                              'On patrol',
                              'Off duty',
                              'Needs attention',
                              'Inactive',
                            ]
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: busy ? null : (value) => status = value!,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        refresh(() => error = 'Enter a name.');
                        return;
                      }
                      refresh(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await (doc?.reference ?? _records.doc())
                            .set({
                              'name': name.text.trim(),
                              'area': area.text.trim(),
                              'notes': notes.text.trim(),
                              'status': status,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true))
                            .timeout(const Duration(seconds: 12));
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted) {
                          refresh(() {
                            busy = false;
                            error =
                                'Save not confirmed. Check your connection and permissions.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving...' : 'Save record'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    area.dispose();
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search name, area or status',
        ),
        onChanged: (q) => setState(() => _query = q.toLowerCase()),
      ),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _records.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load records. Check Firestore access permissions.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs
                .where(
                  (d) =>
                      '${d.data()['name']} ${d.data()['area']} ${d.data()['status']}'
                          .toLowerCase()
                          .contains(_query),
                )
                .toList();
            if (docs.isEmpty) {
              return const Center(child: Text('No matching records.'));
            }
            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  leading: const CircleAvatar(
                    child: Icon(Icons.badge_outlined),
                  ),
                  title: Text('${data['name']}'),
                  subtitle: Text('${data['area']}\n${data['status']}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Edit record',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(doc),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}
