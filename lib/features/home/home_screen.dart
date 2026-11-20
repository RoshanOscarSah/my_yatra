import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nepal_map.dart';
import '../districts/district_page.dart';
import '../districts/map_screen.dart';
import '../dna/dna_provider.dart';
import '../dna/dna_screen.dart';
import '../gamification/badges_screen.dart';
import '../recommendations/engine/recommender.dart';
import '../recommendations/recommendation_provider.dart';
import 'home_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final visits = context.watch<VisitProvider>();
    final districts = context.watch<DistrictProvider>();
    final dna = context.watch<DnaProvider>().result;
    final recs = context.watch<RecommendationProvider>();
    final picks = recs.weeklyPicks(DateTime.now());
    final firstName = (profile?.name ?? '').split(' ').first;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Namaste${firstName.isEmpty ? '' : ', $firstName'}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Where to next?', style: AppTheme.serif(28)),
          const SizedBox(height: 16),

          // Footprint
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const MapScreen())),
            child: InfoCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Your footprint', style: AppTheme.serif(17))),
                  TagChip('${(visits.progress * 100).toStringAsFixed(0)}%'),
                ]),
                const SizedBox(height: 4),
                Text('${visits.count} of 77 districts visited',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: IgnorePointer(
                    child: NepalMap(
                      labelToId: districts.labelToId,
                      visitedIds: visits.visitedIds,
                      recommendedIds: recs.recommendedIds,
                      interactive: false,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const MapLegend(),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Journey DNA
          if (dna != null)
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const DnaScreen())),
              child: InfoCard(
                color: AppColors.lavender,
                child: Row(children: [
                  const Icon(Icons.fingerprint, size: 40, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Your Journey DNA',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(dna.type, style: AppTheme.serif(20)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ),

          // Weekly picks (US-6.5)
          SectionTitle('This week\'s picks',
              trailing: TextButton(
                  onPressed: () => HomeShell.goToTab(context, 2),
                  child: const Text('See all'))),
          Text(
              'Fresh ideas every week from your latest Journey DNA. '
              'Week ${Recommender.isoWeek(DateTime.now())}.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          if (picks.isEmpty)
            const InfoCard(child: Text('No picks yet. Finish setup to get suggestions.'))
          else
            for (final r in picks) ...[
              _PickTile(rec: r),
              const SizedBox(height: 10),
            ],

          if (profile?.gamificationOn ?? true) ...[
            const SizedBox(height: 6),
            InfoCard(
              color: AppColors.goldSoft,
              child: Row(children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.warning),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Follow your curiosity: see your badges and challenges.')),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BadgesScreen())),
                  child: const Text('Open'),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  final Recommendation rec;
  const _PickTile({required this.rec});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DistrictProvider>().byId(rec.district.id);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () => openDistrict(context, rec.district.id),
      child: InfoCard(
        child: Row(children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Text(rec.district.name[0],
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                    child: Text(rec.district.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (rec.district.lessExplored) ...[
                  const SizedBox(width: 6),
                  const TagChip('Less explored', color: AppColors.goldSoft, textColor: AppColors.warning),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${d?.provinceName ?? ''} · ${rec.reason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}
