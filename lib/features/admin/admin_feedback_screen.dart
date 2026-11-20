import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../feedback/feedback_screen.dart';

/// US-15.5: one inbox for app feedback, recommendation reports and wrong info.
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});
  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  String? _type;
  String? _status;

  static const types = {'app': 'App feedback', 'recommendation': 'Recommendation reports', 'district_info': 'Wrong info'};
  static const statuses = ['new', 'reviewed', 'resolved'];

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final fmt = DateFormat('d MMM y');
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback inbox')),
      body: StreamBuilder<List<FeedbackItem>>(
        stream: CommunityRepository().inbox(),
        builder: (context, snap) {
          final all = snap.data ?? const [];
          final list = all
              .where((f) => _type == null || f.type == _type)
              .where((f) => _status == null || f.status == _status)
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in types.entries)
                FilterChip(
                  label: Text(t.value),
                  showCheckmark: false,
                  selected: _type == t.key,
                  onSelected: (s) => setState(() => _type = s ? t.key : null),
                ),
              for (final s in statuses)
                FilterChip(
                  label: Text('${_cap(s)} (${all.where((f) => f.status == s).length})'),
                  showCheckmark: false,
                  selected: _status == s,
                  onSelected: (v) => setState(() => _status = v ? s : null),
                ),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) const Text('No items match.'),
            for (final f in list)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${types[f.type] ?? f.type}${f.category.isEmpty ? '' : ' · ${_cap(f.category)}'}'
                          '${f.districtId == null ? '' : ' · ${dp.byId(f.districtId)?.name ?? f.districtId}'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      StatusChip(f.status),
                    ]),
                    if (f.rating != null) Text('Rating: ${'★' * f.rating!}${'☆' * (5 - f.rating!)} (${f.rating}/5)'),
                    if (f.dnaType != null) Text('Journey DNA: ${f.dnaType}'),
                    if (f.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(f.text)),
                    if (f.createdAt != null) Text(fmt.format(f.createdAt!), style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [for (final s in statuses) ButtonSegment(value: s, label: Text(_cap(s)))],
                      selected: {f.status},
                      onSelectionChanged: (s) => CommunityRepository().setFeedbackStatus(f.id, s.first),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
