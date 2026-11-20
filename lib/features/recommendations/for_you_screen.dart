import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/offline_banner.dart';
import '../districts/district_page.dart';
import '../dna/dna_provider.dart';
import '../feedback/report_info_sheet.dart';
import '../onboarding/preference_widgets.dart';
import '../profile/preferences_screen.dart';
import 'engine/recommender.dart';
import 'less_explored_info.dart';
import 'recommendation_provider.dart';

/// "For you" tab (US-6.1 to US-6.4, US-6.7, US-6.8, US-14.2).
class ForYouScreen extends StatelessWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recs = context.watch<RecommendationProvider>();
    final dna = context.watch<DnaProvider>().result;
    return SafeArea(
      child: NeedsInternet(
        feature: 'AI recommendations',
        child: !recs.setupComplete
            ? EmptyState(
                icon: Icons.tune,
                title: 'Finish your setup first',
                message: 'Choose your interests and travel plans so MyYatra can rank districts for you.',
                action: OutlinedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PreferencesScreen())),
                  child: const Text('Open preferences'),
                ),
              )
            : CustomScrollView(slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  sliver: SliverList.list(children: [
                    Text('For you', style: AppTheme.serif(28)),
                    const SizedBox(height: 4),
                    Text(
                      'Ranked for a ${dna?.type ?? 'traveller'} from your Journey DNA, gaps and plans.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    const _FilterBar(),
                    const SizedBox(height: 8),
                  ]),
                ),
                if (recs.recommendations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Nothing matches these filters',
                      message: 'Try a higher budget, another season or a different distance.',
                      action: OutlinedButton(
                          onPressed: recs.resetFilters, child: const Text('Reset to my preferences')),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.builder(
                      itemCount: recs.recommendations.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RecommendationCard(rank: i + 1, rec: recs.recommendations[i]),
                      ),
                    ),
                  ),
              ]),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final recs = context.watch<RecommendationProvider>();
    final f = recs.filters;
    final hasStart = context.watch<ProfileProvider>().profile?.planning.startDistrictId != null;

    Future<void> pick<T>(String title, Map<T?, String> options, T? current, void Function(T?) set) async {
      final r = await showModalBottomSheet<(T?,)>(
        context: context,
        backgroundColor: AppColors.background,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: AppTheme.serif(18))),
            for (final o in options.entries)
              ListTile(
                title: Text(o.value),
                trailing: o.key == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, (o.key,)),
              ),
          ]),
        ),
      );
      if (r != null) set(r.$1);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip(
          'Budget: ${f.budget == null ? 'Any' : CostLevel.label(f.budget!)}',
          f.budget != null,
          () => pick<int>('Budget', {null: 'Any', 1: 'Budget', 2: 'Moderate', 3: 'Premium'}, f.budget,
              (v) => recs.setFilters(f.copyWith(budget: v, clearBudget: v == null))),
        ),
        _chip(
          'Distance: ${f.distance == null ? 'Any' : '${f.distance![0].toUpperCase()}${f.distance!.substring(1)}'}',
          f.distance != null,
          hasStart
              ? () => pick<String>('Distance from your start', {null: 'Any', ...PlanningForm.distances},
                  f.distance, (v) => recs.setFilters(f.copyWith(distance: v, clearDistance: v == null)))
              : null,
        ),
        _chip(
          'Season: ${f.season?.short ?? 'Any'}',
          f.season != null,
          () => pick<Season>('Season', {null: 'Any', for (final s in Season.values) s: s.label}, f.season,
              (v) => recs.setFilters(f.copyWith(season: v, clearSeason: v == null))),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: const Text('Less explored'),
            selected: f.lessExploredOnly,
            onSelected: (v) => recs.setFilters(f.copyWith(lessExploredOnly: v)),
          ),
        ),
        TextButton(onPressed: recs.resetFilters, child: const Text('Reset')),
      ]),
    );
  }

  Widget _chip(String label, bool active, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: active,
          onSelected: onTap == null ? null : (_) => onTap(),
          showCheckmark: false,
          avatar: const Icon(Icons.expand_more, size: 16),
        ),
      );
}

class RecommendationCard extends StatefulWidget {
  final int rank;
  final Recommendation rec;
  const RecommendationCard({super.key, required this.rank, required this.rec});

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final recs = context.read<RecommendationProvider>();
    final fb = context.watch<RecommendationProvider>().feedback[widget.rec.district.id];
    final d = context.watch<DistrictProvider>().byId(widget.rec.district.id);
    final dnaType = context.read<DnaProvider>().result?.type ?? '';
    if (d == null) return const SizedBox.shrink();
    final r = widget.rec;

    return InfoCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => openDistrict(context, d.id),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text('${widget.rank}', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: AppTheme.serif(19)),
                Text(
                  '${d.provinceName} · ${CostLevel.label(d.costLevel)}'
                  '${r.distanceKm == null ? '' : ' · ~${r.distanceKm!.round()} km'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('${(r.score * 100).round()}% match',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in d.experienceTypes) TagChip(e.label, icon: e.icon),
          if (d.lessExplored)
            TagChip('Less explored',
                icon: Icons.info_outline,
                color: AppColors.goldSoft,
                textColor: AppColors.warning,
                onTap: () => showLessExploredInfo(context)),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(r.reason, style: const TextStyle(height: 1.35))),
        ]),
        if (_expanded && (d.festivals.isNotEmpty || d.foods.isNotEmpty)) ...[
          const SizedBox(height: 10),
          if (d.festivals.isNotEmpty)
            Text('🎉 ${d.festivals.take(2).map((f) => '${f.name} (${f.month})').join(', ')}',
                style: const TextStyle(fontSize: 13)),
          if (d.foods.isNotEmpty)
            Text('🍲 ${d.foods.take(3).join(', ')}', style: const TextStyle(fontSize: 13)),
        ],
        Row(children: [
          if (d.festivals.isNotEmpty || d.foods.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Less' : 'Festivals & food'),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Helpful',
            isSelected: fb == 'helpful',
            selectedIcon: const Icon(Icons.thumb_up, color: AppColors.primary),
            icon: const Icon(Icons.thumb_up_outlined),
            onPressed: () {
              recs.markHelpful(d.id);
              showSnack(context, 'Thanks! We will show more like ${d.name}.');
            },
          ),
          IconButton(
            tooltip: 'Not interested',
            icon: const Icon(Icons.thumb_down_outlined),
            onPressed: () {
              recs.markNotInterested(d.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('${d.name} hidden from your recommendations.'),
                action: SnackBarAction(label: 'Undo', onPressed: () => recs.undo(d.id)),
                persist: false,
                duration: const Duration(seconds: 5),
              ));
            },
          ),
          IconButton(
            tooltip: 'Report',
            isSelected: fb == 'reported',
            selectedIcon: const Icon(Icons.flag, color: AppColors.primary),
            icon: const Icon(Icons.flag_outlined),
            onPressed: () async {
              if (!await openReportRecommendation(context, d.id, dnaType)) return;
              recs.markReported(d.id);
              if (!context.mounted) return;
              // Reporting does not hide the pick on its own; the user decides.
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text('Report sent. Hide ${d.name} from your picks too?'),
                  action: SnackBarAction(
                      label: 'Hide it', onPressed: () => recs.markNotInterested(d.id)),
                  persist: false,
                  duration: const Duration(seconds: 6),
                ));
            },
          ),
        ]),
      ]),
    );
  }
}
