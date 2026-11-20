import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/offline_provider.dart';
import '../../core/widgets/common.dart';

/// US-11.1 / US-11.2: saved items, their size, total storage, remove.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final off = context.watch<OfflineProvider>();
    final fmt = DateFormat('d MMM y, h:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: off.items.isEmpty
          ? const EmptyState(
              icon: Icons.download_outlined,
              title: 'Nothing saved yet',
              message: 'Use "Save for offline" on a district page or itinerary to keep it on this device.')
          : ListView(padding: const EdgeInsets.all(20), children: [
              InfoCard(
                color: AppColors.lavender,
                child: Text('${off.items.length} item(s) · ${OfflineProvider.formatBytes(off.totalBytes)} used on this device',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              for (final i in off.items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(i.kind == 'district' ? Icons.place_outlined : Icons.event_note_outlined,
                        color: AppColors.primary),
                    title: Text(i.title),
                    subtitle: Text('${OfflineProvider.formatBytes(i.bytes)} · saved ${fmt.format(i.savedAt)}'),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => OfflineItemScreen(item: i))),
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => off.remove(i.key),
                    ),
                  ),
                ),
            ]),
    );
  }
}

/// Renders a saved item from local storage only, so it works offline.
class OfflineItemScreen extends StatelessWidget {
  final OfflineItem item;
  const OfflineItemScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final d = item.data;
    String show(dynamic v) {
      if (v is List) return v.join('\n');
      if (v is Map) return v.entries.map((e) => '${e.key}: ${e.value is Map ? (e.value as Map).values.join(', ') : e.value}').join('\n');
      return v?.toString() ?? '';
    }

    final rows = item.kind == 'district'
        ? {
            'Province': d['province'],
            'About': d['description'],
            'Experience types': d['experienceTypes'],
            'Best season': d['bestSeasons'],
            'Estimated cost': d['cost'],
            'How to get there': d['transport'],
            'Safety tips': d['safetyNotes'],
            'Emergency numbers': d['emergencyNumbers'],
            'Festivals': d['festivals'],
            'Local food': d['foods'],
            'Places': d['places'],
          }
        : {
            'District': d['districtName'],
            'Dates': '${d['startDate']?.toString().substring(0, 10)} – ${d['endDate']?.toString().substring(0, 10)}',
            'Budget': 'NPR ${d['budget']} (estimate ${d['cost']})',
            'Companions': d['companions'],
            'Days': [
              for (var i = 0; i < (d['days'] as List? ?? []).length; i++)
                'Day ${i + 1}: ${((d['days'] as List)[i]['activities'] as List).join(', ')}'
            ],
            'Safety tips': d['safetyNotes'],
            'Emergency numbers': d['emergencyNumbers'],
          };
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Offline copy saved ${DateFormat.yMMMd().format(item.savedAt)}',
            style: const TextStyle(color: AppColors.textSecondary)),
        for (final r in rows.entries)
          if (show(r.value).trim().isNotEmpty) ...[
            SectionTitle(r.key),
            Text(show(r.value), style: const TextStyle(height: 1.45)),
          ],
      ]),
    );
  }
}
