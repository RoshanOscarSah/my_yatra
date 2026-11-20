import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/repositories/district_repository.dart';
import '../../core/widgets/common.dart';

/// US-15.3: content coverage. Only aggregate visit totals, never per-user data.
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  late final Future<List<Place>> _places = DistrictRepository().allPlaces().catchError((_) => <Place>[]);

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final ds = dp.districts;
    final missing = ds.where((d) => d.missingFields.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Content analytics')),
      body: FutureBuilder<List<Place>>(
        future: _places,
        builder: (context, snap) {
          final places = snap.data ?? const <Place>[];
          final placesByDistrict = <String, int>{};
          for (final p in places) {
            placesByDistrict[p.districtId] = (placesByDistrict[p.districtId] ?? 0) + 1;
          }
          return ListView(padding: const EdgeInsets.all(20), children: [
            InfoCard(
              child: Row(children: [
                StatTile('${ds.length}', 'districts'),
                StatTile('${places.length}', 'places'),
                StatTile('${ds.where((d) => d.lessExplored).length}', 'less explored'),
                StatTile('${missing.length}', 'incomplete'),
              ]),
            ),
            const SectionTitle('By province'),
            Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                const TableRow(children: [
                  Text('Province', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Districts', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('Places', style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                for (final p in Province.all)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(p.name)),
                    Text('${dp.inProvince(p.number).length}/${p.districtCount}'),
                    Text('${dp.inProvince(p.number).fold<int>(0, (s, d) => s + (placesByDistrict[d.id] ?? 0))}'),
                  ]),
              ],
            ),
            const SectionTitle('By experience type'),
            for (final e in Experience.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.label),
                trailing: Text('${ds.where((d) => d.experienceTypes.contains(e)).length} districts · '
                    '${places.where((p) => p.experienceType == e).length} places'),
              ),
            const SectionTitle('Missing fields'),
            if (missing.isEmpty) const Text('All districts have the required fields.'),
            for (final d in missing)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(d.name),
                subtitle: Text(d.missingFields.join(', '), style: const TextStyle(color: AppColors.danger)),
              ),
            const SectionTitle('Districts marked visited (total users)'),
            StreamBuilder<Map<String, int>>(
              stream: CommunityRepository().districtVisitTotals(),
              builder: (context, s) {
                final totals = (s.data ?? {}).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                if (totals.isEmpty) return const Text('No visits recorded yet.');
                return Column(children: [
                  for (final t in totals.take(20))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(dp.byId(t.key)?.name ?? t.key),
                      trailing: Text('${t.value}'),
                    ),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }
}
