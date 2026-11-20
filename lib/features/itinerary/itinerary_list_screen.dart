import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/itinerary_provider.dart';
import '../../core/widgets/common.dart';
import 'itinerary_form.dart';

class ItineraryListScreen extends StatelessWidget {
  const ItineraryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ItineraryProvider>().items;
    final dp = context.watch<DistrictProvider>();
    final fmt = DateFormat('d MMM y');
    return Scaffold(
      appBar: AppBar(title: const Text('My itineraries')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItineraryForm())),
        child: const Icon(Icons.add),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No itineraries yet',
              message: 'Plan a trip day by day with your dates, activities and budget.')
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final i in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(dp.byId(i.districtId)?.name ?? i.districtId,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${fmt.format(i.startDate)} – ${fmt.format(i.endDate)} · ${i.dayCount} days'
                        '${i.budget > 0 ? ' · NPR ${NumberFormat.decimalPattern().format(i.budget)}' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ItineraryForm(existing: i))),
                  ),
                ),
            ]),
    );
  }
}
