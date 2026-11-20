import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nepal_map.dart';
import '../recommendations/recommendation_provider.dart';
import 'district_page.dart';
import 'map_screen.dart';
import 'record_visit_sheet.dart';

/// Figma 05 Explore: search, province chips, footprint map, district list
/// (US-3.1, US-3.2, US-3.3).
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _q = '';
  int? _province;
  Experience? _type;
  bool _lessOnly = false;
  String _visitedFilter = 'all'; // all / visited / not

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final visits = context.watch<VisitProvider>();
    final recs = context.watch<RecommendationProvider>();
    final list = dp.districts.where((d) {
      if (_q.isNotEmpty && !d.name.toLowerCase().contains(_q.toLowerCase())) return false;
      if (_province != null && d.province != _province) return false;
      if (_type != null && !d.experienceTypes.contains(_type)) return false;
      if (_lessOnly && !d.lessExplored) return false;
      final v = visits.isVisited(d.id);
      if (_visitedFilter == 'visited' && !v) return false;
      if (_visitedFilter == 'not' && v) return false;
      return true;
    }).toList();

    return SafeArea(
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverList.list(children: [
            Text('Explore Nepal', style: AppTheme.serif(28)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('explore-search'),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search), hintText: 'Search districts'),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filters',
                onPressed: _openFilters,
                icon: Badge(
                  isLabelVisible: _type != null || _lessOnly || _visitedFilter != 'all',
                  child: const Icon(Icons.tune),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _province == null,
                    onSelected: (_) => setState(() => _province = null),
                  ),
                ),
                for (final p in Province.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.name),
                      selected: _province == p.number,
                      onSelected: (_) => setState(() => _province = p.number),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MapScreen())),
              child: InfoCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text('Footprint map', style: AppTheme.serif(16))),
                    TagChip('${visits.count}/77 · ${(visits.progress * 100).toStringAsFixed(0)}%'),
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_full, size: 18),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: IgnorePointer(
                      child: NepalMap(
                        labelToId: dp.labelToId,
                        visitedIds: visits.visitedIds,
                        recommendedIds: recs.recommendedIds,
                        interactive: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const MapLegend(),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('${list.length} districts',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
          ]),
        ),
        if (list.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
                icon: Icons.search_off,
                title: 'No districts match',
                message: 'Try a different name or clear the filters.'),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => DistrictListTile(district: list[i]),
            ),
          ),
      ]),
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        void upd(VoidCallback f) {
          set(f);
          setState(() {});
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Filters', style: AppTheme.serif(20)),
              const SizedBox(height: 12),
              const Text('Experience type', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in Experience.values)
                  FilterChip(
                    avatar: Icon(e.icon, size: 16),
                    label: Text(e.label),
                    selected: _type == e,
                    onSelected: (s) => upd(() => _type = s ? e : null),
                  ),
              ]),
              const SizedBox(height: 12),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'visited', label: Text('Visited')),
                  ButtonSegment(value: 'not', label: Text('Not yet')),
                ],
                selected: {_visitedFilter},
                onSelectionChanged: (s) => upd(() => _visitedFilter = s.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Less-explored only'),
                value: _lessOnly,
                onChanged: (v) => upd(() => _lessOnly = v),
              ),
              TextButton(
                onPressed: () => upd(() {
                  _type = null;
                  _lessOnly = false;
                  _visitedFilter = 'all';
                }),
                child: const Text('Clear filters'),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class DistrictListTile extends StatelessWidget {
  final District district;
  const DistrictListTile({super.key, required this.district});

  @override
  Widget build(BuildContext context) {
    final visits = context.watch<VisitProvider>();
    final visited = visits.isVisited(district.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        onTap: () => openDistrict(context, district.id),
        leading: CircleAvatar(
          backgroundColor: visited ? AppColors.primary : AppColors.primarySoft,
          child: visited
              ? const Icon(Icons.check, color: Colors.white)
              : Text(district.name[0],
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
        title: Row(children: [
          Flexible(child: Text(district.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (district.lessExplored) ...[
            const SizedBox(width: 6),
            const Icon(Icons.explore_off_outlined, size: 14, color: AppColors.warning),
          ],
        ]),
        subtitle: Text(
          '${district.provinceName} · ${district.experienceTypes.map((e) => e.label).take(3).join(', ')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: visited
            ? const TagChip('Visited', icon: Icons.check)
            : TextButton(
                onPressed: () => markVisitedFlow(context, district.id),
                child: const Text('Mark visited'),
              ),
      ),
    );
  }
}
