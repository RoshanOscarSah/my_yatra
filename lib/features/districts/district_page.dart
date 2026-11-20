import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/offline_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/repositories/district_repository.dart';
import '../../core/widgets/common.dart';
import '../feedback/report_info_sheet.dart';
import '../itinerary/itinerary_form.dart';
import '../journal/entry_form.dart';
import '../recommendations/less_explored_info.dart';
import '../reviews/reviews_section.dart';
import '../safety/safety_section.dart';
import 'record_visit_sheet.dart';

void openDistrict(BuildContext context, String id) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPage(districtId: id)));
}

/// One page per district (US-6.6, US-6.8, US-12.1, US-13.1, US-11.1, US-14.3).
class DistrictPage extends StatelessWidget {
  final String districtId;
  const DistrictPage({super.key, required this.districtId});

  /// Content stored for offline use (US-11.1).
  static Map<String, dynamic> offlineData(District d, List<Place> places) => {
        'id': d.id,
        'name': d.name,
        'province': d.provinceName,
        'description': d.description,
        'experienceTypes': d.experienceTypes.map((e) => e.label).toList(),
        'bestSeasons': d.bestSeasons.map((e) => e.label).toList(),
        'cost': '${CostLevel.label(d.costLevel)} · ${CostLevel.range(d.costLevel)}',
        'transport': d.transport,
        'safetyNotes': d.safetyNotes,
        'emergencyNumbers': {for (final e in SafetySection.emergencyNumbers) e.$1: e.$2},
        'festivals': d.festivals.map((f) => '${f.name} (${f.month})').toList(),
        'foods': d.foods,
        'places': places.map((p) => '${p.name}: ${p.description}').toList(),
      };

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final d = dp.byId(districtId);
    if (d == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('District not found')));
    }
    final visits = context.watch<VisitProvider>();
    final visit = visits.visitFor(d.id);
    final offline = context.watch<OfflineProvider>();
    final repo = context.read<DistrictRepository>();
    final offlineKey = 'district:${d.id}';

    return Scaffold(
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') openReportInfo(context, d.id);
              if (v == 'journal') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EntryForm(initialDistrictId: d.id)));
              }
              if (v == 'itinerary') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ItineraryForm(districtId: d.id)));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'journal', child: Text('Write a journal entry')),
              PopupMenuItem(value: 'itinerary', child: Text('Plan an itinerary')),
              PopupMenuItem(value: 'report', child: Text('Report wrong information')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Place>>(
        stream: repo.places(d.id),
        builder: (context, snap) {
          var places = snap.data ?? const <Place>[];
          if (places.isEmpty && !dp.fromFirestore) places = DistrictRepository.seedPlaces(d.id);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text('${d.provinceName} Province', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in d.experienceTypes) TagChip(e.label, icon: e.icon),
                if (d.lessExplored)
                  TagChip('Less explored',
                      icon: Icons.info_outline,
                      color: AppColors.goldSoft,
                      textColor: AppColors.warning,
                      onTap: () => showLessExploredInfo(context)),
              ]),
              const SizedBox(height: 14),
              Text(d.description, style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 16),

              // Visit status
              InfoCard(
                color: visit != null ? AppColors.primarySoft : AppColors.surface,
                child: visit == null
                    ? Row(children: [
                        const Expanded(child: Text('You have not visited yet.')),
                        FilledButton(
                          key: const Key('district-mark-visited'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: () => markVisitedFlow(context, d.id),
                          child: const Text('Mark visited'),
                        ),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.check_circle, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              visit.date == null
                                  ? 'Visited before MyYatra'
                                  : 'Visited on ${DateFormat.yMMMd().format(visit.date!)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Change date',
                            icon: const Icon(Icons.edit_calendar_outlined),
                            onPressed: () async {
                              final dt = await pickPastDate(context, initial: visit.date);
                              if (dt != null) await visits.addVisit(d.id, dt);
                            },
                          ),
                          IconButton(
                            tooltip: 'Unmark visited',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () async {
                              final ok = await confirmDialog(context,
                                  title: 'Unmark ${d.name}?',
                                  message: 'The visit and its places will be removed. Journal entries stay.',
                                  confirm: 'Unmark',
                                  destructive: true);
                              if (ok) await visits.removeVisit(d.id);
                            },
                          ),
                        ]),
                        if (visit.places.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          for (final p in visit.places)
                            Text('• ${p.name}${p.activities.isEmpty ? '' : ' — ${p.activities.map((e) => e.label).join(', ')}'}'),
                        ],
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: () => openRecordPlaces(context, d.id),
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(visit.places.isEmpty ? 'Add places & activities' : 'Edit places & activities'),
                        ),
                      ]),
              ),

              const SectionTitle('Plan your trip'),
              _Fact(Icons.wb_sunny_outlined, 'Best season',
                  d.bestSeasons.isEmpty ? 'Not set' : d.bestSeasons.map((s) => s.label).join(', ')),
              _Fact(Icons.payments_outlined, 'Estimated cost',
                  '${CostLevel.label(d.costLevel)} · ${CostLevel.range(d.costLevel)}'
                  '${d.updatedAt != null ? '\nLast updated ${DateFormat.yMMMd().format(d.updatedAt!)}' : '\nLast updated: MyYatra seed data, Nov 2026'}'),
              _Fact(Icons.directions_bus_outlined, 'How to get there', d.transport),

              // Festivals & food (US-6.8): hidden when no data.
              if (d.festivals.isNotEmpty || d.foods.isNotEmpty) ...[
                const SectionTitle('Festivals & food'),
                if (d.festivals.isNotEmpty)
                  _Fact(Icons.celebration_outlined, 'Festivals',
                      d.festivals.map((f) => '${f.name} (${f.month})').join('\n')),
                if (d.foods.isNotEmpty)
                  _Fact(Icons.restaurant_outlined, 'Local food', d.foods.join(', ')),
              ],

              if (places.isNotEmpty) ...[
                const SectionTitle('Places'),
                for (final p in places)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(p.experienceType.icon, color: AppColors.primary, size: 20),
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.description),
                  ),
              ],

              SafetySection(district: d),
              ReviewsSection(district: d),

              const SectionTitle('Offline'),
              if (offline.isSaved(offlineKey))
                InfoCard(
                  child: Row(children: [
                    const Icon(Icons.download_done, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Saved for offline · ${OfflineProvider.formatBytes(offline.get(offlineKey)!.bytes)}'),
                    ),
                    TextButton(
                      onPressed: () => offline.remove(offlineKey),
                      child: const Text('Remove'),
                    ),
                  ]),
                )
              else
                OutlinedButton.icon(
                  key: const Key('save-offline'),
                  onPressed: () async {
                    await offline.save(offlineKey, 'district', d.name, offlineData(d, places));
                    if (context.mounted) showSnack(context, '${d.name} saved for offline use.');
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save for offline'),
                ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ItineraryForm(districtId: d.id))),
                    icon: const Icon(Icons.event_note_outlined),
                    label: const Text('Itinerary'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openReportInfo(context, d.id),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report info'),
                  ),
                ),
              ]),
              if (!context.watch<ConnectivityProvider>().online)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Offline: showing the latest saved copy.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _Fact(this.icon, this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? 'Not available yet' : value,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}
