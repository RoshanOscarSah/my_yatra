import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';
import '../districts/district_page.dart';
import 'entry_detail_screen.dart';
import 'journal_screen.dart';

/// US-8.2: a past journey with places, activities, journal, photos and review.
/// Parts without data are left out.
class JourneyDetailScreen extends StatelessWidget {
  final TimelineItem item;
  const JourneyDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DistrictProvider>().byId(item.districtId);
    final uid = context.watch<ProfileProvider>().profile?.uid;
    final fmt = DateFormat.yMMMd();
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.name ?? ''),
        actions: [
          TextButton(onPressed: () => openDistrict(context, item.districtId), child: const Text('District page')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(
          item.date == null
              ? 'Before MyYatra'
              : item.endDate == null || item.endDate == item.date
                  ? fmt.format(item.date!)
                  : '${fmt.format(item.date!)} – ${fmt.format(item.endDate!)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (item.activities.isNotEmpty) ...[
          const SectionTitle('Activities'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in item.activities) TagChip(a.label, icon: a.icon),
          ]),
        ],
        if (item.visit != null && item.visit!.places.isNotEmpty) ...[
          const SectionTitle('Places'),
          for (final p in item.visit!.places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined, color: AppColors.primary),
              title: Text(p.name),
              subtitle: p.activities.isEmpty ? null : Text(p.activities.map((e) => e.label).join(', ')),
            ),
        ],
        for (final e in item.entries) ...[
          if (e.story.isNotEmpty) ...[
            const SectionTitle('Journal'),
            InkWell(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: e.id))),
              child: InfoCard(child: Text(e.story, style: const TextStyle(height: 1.45))),
            ),
          ],
          if (e.photoUrls.isNotEmpty) ...[
            const SectionTitle('Photos'),
            PhotoGrid(urls: e.photoUrls),
          ],
        ],
        if (uid != null)
          StreamBuilder<List<Review>>(
            stream: CommunityRepository().reviewsFor(item.districtId),
            builder: (_, snap) {
              final mine = (snap.data ?? const []).where((r) => r.uid == uid).firstOrNull;
              if (mine == null) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Your review'),
                InfoCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(i <= mine.rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: AppColors.warning, size: 18),
                    ]),
                    const SizedBox(height: 6),
                    Text(mine.text),
                  ]),
                ),
              ]);
            },
          ),
      ]),
    );
  }
}
