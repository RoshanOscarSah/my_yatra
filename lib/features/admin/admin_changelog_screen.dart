import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';

/// US-15.4: recent changes with old/new value, admin and time; date filter.
class AdminChangeLogScreen extends StatefulWidget {
  const AdminChangeLogScreen({super.key});
  @override
  State<AdminChangeLogScreen> createState() => _AdminChangeLogScreenState();
}

class _AdminChangeLogScreenState extends State<AdminChangeLogScreen> {
  DateTimeRange? _range;

  /// "district · achham · bestSeasons" -> "District · Achham · Best seasons".
  /// Alert and review ids start with the district id, so show its name.
  String _title(ChangeLogEntry c, DistrictProvider dp) {
    String cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
    final field = cap(c.field.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}'));
    final districtId = switch (c.entity) {
      'alert' => c.entityId.split('/').first,
      'review' => c.entityId.split('_').first,
      'place' => c.entityId.split('/').first,
      _ => c.entityId,
    };
    final where = c.entityId == '*' ? 'All districts' : (dp.byId(districtId)?.name ?? c.entityId);
    return '${cap(c.entity)} · $where · $field';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM y, h:mm a');
    final dp = context.watch<DistrictProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent changes'),
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final r = await showDateRangePicker(
                  context: context, firstDate: DateTime(2024), lastDate: DateTime.now(), initialDateRange: _range);
              setState(() => _range = r);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ChangeLogEntry>>(
        stream: CommunityRepository().changeLog(),
        builder: (context, snap) {
          final list = (snap.data ?? const <ChangeLogEntry>[])
              .where((c) =>
                  _range == null ||
                  (c.at != null &&
                      !c.at!.isBefore(_range!.start) &&
                      c.at!.isBefore(_range!.end.add(const Duration(days: 1)))))
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (_range != null)
              InputChip(
                label: Text('${DateFormat.yMMMd().format(_range!.start)} – ${DateFormat.yMMMd().format(_range!.end)}'),
                onDeleted: () => setState(() => _range = null),
              ),
            if (list.isEmpty)
              const EmptyState(icon: Icons.history, title: 'No changes', message: 'Edits by admins are listed here.'),
            for (final c in list)
              Card(
                child: ListTile(
                  title: Text(_title(c, dp)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (c.oldValue.isNotEmpty)
                      Text('Before: ${c.oldValue}', maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.danger)),
                    if (c.newValue.isNotEmpty)
                      Text('After: ${c.newValue}', maxLines: 3, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.success)),
                    Text('${c.adminName}${c.at == null ? '' : ' · ${fmt.format(c.at!)}'}',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
