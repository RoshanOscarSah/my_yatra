import 'package:flutter/material.dart';

import '../../app/env.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/journal_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import '../gamification/stats_provider.dart';
import 'entry_detail_screen.dart';
import 'entry_form.dart';
import 'journey_detail_screen.dart';

/// Journal tab: entries, history timeline (US-8.1) and statistics (US-8.3).
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('new-entry'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EntryForm())),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('New entry'),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Journal', style: AppTheme.serif(28))),
            ),
            const TabBar(
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
              tabs: [Tab(text: 'Entries'), Tab(text: 'History'), Tab(text: 'Statistics')],
            ),
            const Expanded(
              child: TabBarView(children: [_EntriesTab(), HistoryTimeline(), StatsTab()]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EntriesTab extends StatelessWidget {
  const _EntriesTab();

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final dp = context.watch<DistrictProvider>();
    if (journal.entries.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No journal entries yet',
        message: 'Write about a trip: the district, dates, what you did and a few photos.',
      );
    }
    final fmt = DateFormat.yMMMd();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
      if (journal.queuedPhotos > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InfoCard(
            color: AppColors.goldSoft,
            child: Text('${journal.queuedPhotos} photo(s) waiting to upload when you are online.'),
          ),
        ),
      for (final e in journal.entries)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: e.id))),
            child: Row(children: [
              SizedBox(
                width: 96,
                height: 96,
                child: e.photoUrls.isEmpty
                    ? Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.landscape_outlined, color: AppColors.primary))
                    : Image.network(Env.photoUrl(e.photoUrls.first), fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(dp.byId(e.districtId)?.name ?? e.districtId,
                            style: AppTheme.serif(17)),
                      ),
                      if (e.draft) ...[
                        const SizedBox(width: 6),
                        const TagChip('Draft', color: AppColors.goldSoft, textColor: AppColors.warning),
                      ],
                    ]),
                    Text(
                      e.endDate == null || e.endDate == e.startDate
                          ? fmt.format(e.startDate)
                          : '${fmt.format(e.startDate)} – ${fmt.format(e.endDate!)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    if (e.story.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(e.story, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// One item of the merged history (visits + journal entries).
class TimelineItem {
  final String districtId;
  final DateTime? date;
  final DateTime? endDate;
  final Visit? visit;
  final List<JournalEntry> entries;
  const TimelineItem(this.districtId, this.date, this.endDate, this.visit, this.entries);
  List<Experience> get activities =>
      {...?visit?.activities, ...entries.expand((e) => e.activities)}.toList();
}

List<TimelineItem> buildTimeline(List<Visit> visits, List<JournalEntry> journal) {
  final items = <TimelineItem>[];
  final visitById = {for (final v in visits) v.districtId: v};
  final journalDistricts = <String>{};
  for (final e in journal) {
    journalDistricts.add(e.districtId);
    items.add(TimelineItem(e.districtId, e.startDate, e.endDate, visitById[e.districtId], [e]));
  }
  for (final v in visits) {
    if (journalDistricts.contains(v.districtId)) continue;
    items.add(TimelineItem(v.districtId, v.date, null, v, const []));
  }
  items.sort((a, b) {
    if (a.date == null && b.date == null) return 0;
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    return b.date!.compareTo(a.date!);
  });
  return items;
}

class HistoryTimeline extends StatefulWidget {
  const HistoryTimeline({super.key});
  @override
  State<HistoryTimeline> createState() => _HistoryTimelineState();
}

class _HistoryTimelineState extends State<HistoryTimeline> {
  String? _district;
  String? _year;

  @override
  Widget build(BuildContext context) {
    final visits = context.watch<VisitProvider>().visits;
    final journal = context.watch<JournalProvider>().entries;
    final dp = context.watch<DistrictProvider>();
    final all = buildTimeline(visits, journal);
    if (all.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline,
        title: 'No journeys yet',
        message: 'Record your first journey: mark a district visited or write a journal entry.',
      );
    }
    String yearOf(TimelineItem i) => i.date?.year.toString() ?? 'Before MyYatra';
    final years = all.map(yearOf).toSet().toList()..sort((a, b) => b.compareTo(a));
    final districtIds = all.map((i) => i.districtId).toSet().toList()
      ..sort((a, b) => (dp.byId(a)?.name ?? a).compareTo(dp.byId(b)?.name ?? b));
    final list = all
        .where((i) => _district == null || i.districtId == _district)
        .where((i) => _year == null || yearOf(i) == _year)
        .toList();
    final fmt = DateFormat.yMMMd();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _district,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'District', isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All districts')),
              for (final id in districtIds)
                DropdownMenuItem(value: id, child: Text(dp.byId(id)?.name ?? id)),
            ],
            onChanged: (v) => setState(() => _district = v),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _year,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Year', isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All years')),
              for (final y in years) DropdownMenuItem(value: y, child: Text(y)),
            ],
            onChanged: (v) => setState(() => _year = v),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      for (final i in list)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 18),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                Expanded(child: Container(width: 2, color: AppColors.border)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6),
                child: Card(
                  child: ListTile(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => JourneyDetailScreen(item: i))),
                    title: Text(dp.byId(i.districtId)?.name ?? i.districtId,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.date == null
                          ? 'Before MyYatra'
                          : i.endDate == null || i.endDate == i.date
                              ? fmt.format(i.date!)
                              : '${fmt.format(i.date!)} – ${fmt.format(i.endDate!)}'),
                      if (i.activities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(spacing: 4, children: [
                            for (final a in i.activities) Icon(a.icon, size: 16, color: AppColors.primary),
                          ]),
                        ),
                    ]),
                    trailing: Icon(i.entries.isEmpty ? Icons.place_outlined : Icons.menu_book_outlined,
                        color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ]),
        ),
      if (list.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No journeys match these filters.', textAlign: TextAlign.center),
        ),
    ]);
  }
}

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StatsProvider>().stats;
    final years = s.journeysPerYear.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
      InfoCard(
        child: Row(children: [
          StatTile('${s.visitedCount}/77', 'districts'),
          StatTile('${s.percent.round()}%', 'of Nepal'),
          StatTile('${s.provincesCovered}/7', 'provinces'),
        ]),
      ),
      const SizedBox(height: 12),
      InfoCard(
        child: Row(children: [
          StatTile('${s.journeys}', s.journeys == 1 ? 'journey' : 'journeys'),
          StatTile(s.topCategory?.label ?? '—', 'most explored'),
        ]),
      ),
      const SectionTitle('Journeys per year'),
      if (years.isEmpty) const Text('No journeys yet.'),
      for (final y in years)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(y.key),
          trailing: Text('${y.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      const SectionTitle('Districts by province'),
      for (final p in Province.all)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 110, child: Text(p.name)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (s.perProvince[p.number] ?? 0) / p.districtCount,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
                ),
              ),
            ),
            SizedBox(
                width: 48,
                child: Text('${s.perProvince[p.number] ?? 0}/${p.districtCount}',
                    textAlign: TextAlign.right)),
          ]),
        ),
    ]);
  }
}
