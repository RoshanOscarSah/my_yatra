import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import '../districts/district_page.dart';
import '../home/home_shell.dart';
import 'dna_provider.dart';
import 'engine/dna_calculator.dart';

/// Figma 07 Journey DNA (US-4.1–4.4) + Gap analysis (US-5.1–5.3).
class DnaScreen extends StatelessWidget {
  const DnaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dna = context.watch<DnaProvider>().result;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journey DNA'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'My DNA'), Tab(text: 'Gap analysis')],
          ),
        ),
        body: dna == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_DnaTab(dna: dna), _GapTab(dna: dna)]),
      ),
    );
  }
}

class _DnaTab extends StatelessWidget {
  final DnaResult dna;
  const _DnaTab({required this.dna});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      InfoCard(
        color: AppColors.lavender,
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('You are a', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(dna.type, key: const Key('dna-type'), style: AppTheme.serif(30)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in dna.ranked.take(3))
              TagChip('${c.label} ${dna.scores[c]!.round()}', icon: c.icon, color: Colors.white),
          ]),
          const SizedBox(height: 10),
          Text('Last refreshed ${DateFormat('d MMM y, h:mm a').format(dna.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
      const SectionTitle('Your six categories'),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AspectRatio(aspectRatio: 1.1, child: DnaRadarChart(scores: dna.scores)),
        ),
      ),
      const SizedBox(height: 8),
      for (final c in Experience.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(c.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: Text(c.label)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: dna.scores[c]! / 100,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
                ),
              ),
            ),
            SizedBox(
                width: 44,
                child: Text('${dna.scores[c]!.round()}%', textAlign: TextAlign.right)),
          ]),
        ),
      const SectionTitle('Why this type?'),
      InfoCard(child: Text(dna.explanation, style: const TextStyle(height: 1.45))),
      const SizedBox(height: 8),
      const Text(
        'Score = 40% your chosen interests + 40% the districts you visited + 20% the activities you recorded. '
        'If the top two categories are within 10 points you are a Mixed Traveller.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      InfoCard(
        color: AppColors.goldSoft,
        child: Row(children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.warning),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Follow your curiosity: districts that fill your gaps are waiting in For you.')),
        ]),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'See recommendations',
        onPressed: () {
          Navigator.popUntil(context, (r) => r.isFirst);
          HomeShell.goToTab(context, 2);
        },
      ),
    ]);
  }
}

class DnaRadarChart extends StatelessWidget {
  final Map<Experience, double> scores;
  const DnaRadarChart({super.key, required this.scores});

  @override
  Widget build(BuildContext context) {
    final cats = Experience.values;
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
        radarBorderData: const BorderSide(color: AppColors.border),
        gridBorderData: const BorderSide(color: AppColors.border),
        tickBorderData: const BorderSide(color: AppColors.border),
        titlePositionPercentageOffset: 0.18,
        titleTextStyle: const TextStyle(
            color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
        getTitle: (i, angle) => RadarChartTitle(
          text: '${cats[i].label}\n${scores[cats[i]]!.round()}%',
        ),
        dataSets: [
          RadarDataSet(
            fillColor: AppColors.primary.withValues(alpha: .25),
            borderColor: AppColors.primary,
            borderWidth: 2,
            entryRadius: 3,
            dataEntries: [for (final c in cats) RadarEntry(value: scores[c]!)],
          ),
          // Invisible 0–100 bounds so the scale is fixed.
          RadarDataSet(
            fillColor: Colors.transparent,
            borderColor: Colors.transparent,
            entryRadius: 0,
            dataEntries: [for (final _ in cats) const RadarEntry(value: 100)],
          ),
          RadarDataSet(
            fillColor: Colors.transparent,
            borderColor: Colors.transparent,
            entryRadius: 0,
            dataEntries: [for (final _ in cats) const RadarEntry(value: 0)],
          ),
        ],
      ),
    );
  }
}

class _GapTab extends StatelessWidget {
  final DnaResult dna;
  const _GapTab({required this.dna});

  @override
  Widget build(BuildContext context) {
    final visits = context.watch<VisitProvider>();
    final dp = context.watch<DistrictProvider>();
    if (visits.count == 0) {
      return EmptyState(
        icon: Icons.map_outlined,
        title: 'Add your visits first',
        message: 'Gap analysis compares what you have explored with what you have not. '
            'Mark the districts you have visited to see it.',
        action: OutlinedButton(
          onPressed: () {
            Navigator.popUntil(context, (r) => r.isFirst);
            HomeShell.goToTab(context, 1);
          },
          child: const Text('Go to Explore'),
        ),
      );
    }

    // Least-explored provinces (US-5.2)
    final provinces = Province.all.map((p) {
      final visited = dp.inProvince(p.number).where((d) => visits.isVisited(d.id)).length;
      return (p, visited, visited / p.districtCount);
    }).toList()
      ..sort((a, b) => a.$3.compareTo(b.$3));

    return ListView(padding: const EdgeInsets.all(20), children: [
      const SectionTitle('Explored vs not yet tried'),
      for (final c in dna.ranked)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(c.icon, size: 18, color: dna.gaps.contains(c) ? AppColors.textSecondary : AppColors.primary),
            const SizedBox(width: 8),
            SizedBox(width: 80, child: Text(c.label)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: dna.visitShare[c]!,
                  minHeight: 10,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: dna.notTried.contains(c)
                  ? const TagChip('Not tried', color: AppColors.goldSoft, textColor: AppColors.warning)
                  : dna.gaps.contains(c)
                      ? const TagChip('Gap', color: AppColors.goldSoft, textColor: AppColors.warning)
                      : Text('${(dna.visitShare[c]! * 100).round()}% of trips',
                          style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ),
      const SizedBox(height: 4),
      Text('Tried: ${dna.tried.map((e) => e.label).join(', ').ifEmpty('none yet')}',
          style: const TextStyle(fontSize: 13)),
      Text('Not tried: ${dna.notTried.map((e) => e.label).join(', ').ifEmpty('none — well done!')}',
          style: const TextStyle(fontSize: 13)),
      const SectionTitle('In plain words'),
      InfoCard(child: Text(dna.gapSummary, style: const TextStyle(height: 1.45))),
      const SectionTitle('Least-explored provinces'),
      for (final p in provinces)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: p.$2 == 0 ? AppColors.goldSoft : null,
          child: ExpansionTile(
            shape: const Border(),
            title: Text('${p.$1.name} Province',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${p.$2} of ${p.$1.districtCount} districts visited'
                '${p.$2 == 0 ? ' · not explored yet' : ''}'),
            trailing: SizedBox(
              width: 44,
              child: Text('${(p.$3 * 100).round()}%', textAlign: TextAlign.right),
            ),
            children: [
              for (final d in dp.inProvince(p.$1.number).where((d) => !visits.isVisited(d.id)))
                ListTile(
                  dense: true,
                  title: Text(d.name),
                  subtitle: Text(d.experienceTypes.map((e) => e.label).join(', ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openDistrict(context, d.id),
                ),
            ],
          ),
        ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
