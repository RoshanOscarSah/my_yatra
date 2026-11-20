import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nepal_map.dart';
import '../../core/widgets/offline_banner.dart';
import '../recommendations/recommendation_provider.dart';
import 'district_page.dart';
import 'record_visit_sheet.dart';

/// Full-screen footprint map (US-3.3): pinch to zoom, drag to pan, tap a
/// district to see a summary card.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final visits = context.watch<VisitProvider>();
    final recs = context.watch<RecommendationProvider>();
    final d = dp.byId(_selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Footprint map'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
                child: TagChip(
                    '${visits.count}/77 · ${(visits.progress * 100).round()}%')),
          ),
        ],
      ),
      body: NeedsInternet(
        feature: 'The map',
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MapLegend(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: NepalMap(
                labelToId: dp.labelToId,
                visitedIds: visits.visitedIds,
                recommendedIds: recs.recommendedIds,
                selectedId: _selected,
                fillHeight: true,
                onTap: (id) => setState(() => _selected = id),
              ),
            ),
          ),
          if (d != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InfoCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(d.name, style: AppTheme.serif(20))),
                      if (visits.isVisited(d.id))
                        const TagChip('Visited', icon: Icons.check)
                      else if (recs.recommendedIds.contains(d.id))
                        const TagChip('Recommended',
                            color: AppColors.goldSoft, textColor: AppColors.warning),
                      IconButton(
                          onPressed: () => setState(() => _selected = null),
                          icon: const Icon(Icons.close)),
                    ]),
                    Text('${d.provinceName} Province',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(d.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => openDistrict(context, d.id),
                          child: const Text('Open page'),
                        ),
                      ),
                      if (!visits.isVisited(d.id)) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            onPressed: () => markVisitedFlow(context, d.id),
                            child: const Text('Mark visited'),
                          ),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
