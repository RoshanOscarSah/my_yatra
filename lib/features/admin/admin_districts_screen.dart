import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/repositories/district_repository.dart';
import '../../core/widgets/common.dart';
import 'admin_home.dart';

/// US-15.1 / US-15.2: district list, edit form and places management.
class AdminDistrictsScreen extends StatefulWidget {
  const AdminDistrictsScreen({super.key});
  @override
  State<AdminDistrictsScreen> createState() => _AdminDistrictsScreenState();
}

class _AdminDistrictsScreenState extends State<AdminDistrictsScreen> {
  String _q = '';
  bool _missingOnly = false;

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final list = dp.districts
        .where((d) => d.name.toLowerCase().contains(_q.toLowerCase()))
        .where((d) => !_missingOnly || d.missingFields.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: const Text('Districts')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search districts'),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SwitchListTile(
          title: const Text('Only districts with missing fields'),
          value: _missingOnly,
          onChanged: (v) => setState(() => _missingOnly = v),
        ),
        if (!dp.fromFirestore)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Seed the data first so edits are saved to Firestore.',
                style: TextStyle(color: AppColors.warning)),
          ),
        Expanded(
          child: ListView(children: [
            for (final d in list)
              ListTile(
                title: Text(d.name),
                subtitle: Text('${d.provinceName}'
                    '${d.lessExplored ? ' · less explored' : ''}'
                    '${d.missingFields.isEmpty ? '' : ' · missing: ${d.missingFields.join(', ')}'}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AdminGate(child: DistrictEditScreen(district: d)))),
              ),
          ]),
        ),
      ]),
    );
  }
}

class DistrictEditScreen extends StatefulWidget {
  final District district;
  const DistrictEditScreen({super.key, required this.district});
  @override
  State<DistrictEditScreen> createState() => _DistrictEditScreenState();
}

class _DistrictEditScreenState extends State<DistrictEditScreen> {
  late final d = widget.district;
  late final _desc = TextEditingController(text: d.description);
  late final _transport = TextEditingController(text: d.transport);
  late final _safety = TextEditingController(text: d.safetyNotes);
  late final _foods = TextEditingController(text: d.foods.join(', '));
  late final _festivals =
      TextEditingController(text: d.festivals.map((f) => '${f.name} | ${f.month}').join('\n'));
  late final Set<Experience> _types = d.experienceTypes.toSet();
  late final Set<Season> _seasons = d.bestSeasons.toSet();
  late int _cost = d.costLevel;
  late bool _less = d.lessExplored;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_desc, _transport, _safety, _foods, _festivals]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_desc.text.trim().isEmpty || _types.isEmpty) {
      showSnack(context, 'Description and at least one experience type are required.');
      return;
    }
    setState(() => _busy = true);
    final updated = d.copyWith(
      description: _desc.text.trim(),
      transport: _transport.text.trim(),
      safetyNotes: _safety.text.trim(),
      foods: _foods.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      festivals: _festivals.text
          .split('\n')
          .map((l) => l.split('|'))
          .where((p) => p.first.trim().isNotEmpty)
          .map((p) => Festival(p.first.trim(), p.length > 1 ? p[1].trim() : ''))
          .toList(),
      experienceTypes: Experience.values.where(_types.contains).toList(),
      bestSeasons: Season.values.where(_seasons.contains).toList(),
      costLevel: _cost,
      lessExplored: _less,
    );
    final a = adminOf(context);
    await DistrictRepository().saveDistrict(updated, d, adminUid: a.uid, adminName: a.name);
    if (!mounted) return;
    showSnack(context, '${d.name} saved. Users see the update right away.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(d.name)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
        const SectionTitle('Experience types'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in Experience.values)
            FilterChip(
              avatar: Icon(e.icon, size: 16),
              label: Text(e.label),
              selected: _types.contains(e),
              onSelected: (s) => setState(() => s ? _types.add(e) : _types.remove(e)),
            ),
        ]),
        const SectionTitle('Best seasons'),
        Wrap(spacing: 8, children: [
          for (final s in Season.values)
            FilterChip(
              label: Text(s.short),
              selected: _seasons.contains(s),
              onSelected: (v) => setState(() => v ? _seasons.add(s) : _seasons.remove(s)),
            ),
        ]),
        const SectionTitle('Estimated cost'),
        SegmentedButton<int>(
          segments: [
            for (final c in CostLevel.labels.entries) ButtonSegment(value: c.key, label: Text(c.value)),
          ],
          selected: {_cost},
          onSelectionChanged: (s) => setState(() => _cost = s.first),
        ),
        const SizedBox(height: 16),
        TextField(controller: _transport, maxLines: 3, decoration: const InputDecoration(labelText: 'How to get there')),
        const SizedBox(height: 12),
        TextField(controller: _safety, maxLines: 3, decoration: const InputDecoration(labelText: 'Safety notes')),
        const SizedBox(height: 12),
        TextField(controller: _foods, decoration: const InputDecoration(labelText: 'Local foods (comma separated)')),
        const SizedBox(height: 12),
        TextField(
          controller: _festivals,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Festivals (one per line: name | month)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Less explored'),
          subtitle: const Text('Highlights the district and boosts it in recommendations'),
          value: _less,
          onChanged: (v) => setState(() => _less = v),
        ),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Save district', loading: _busy, onPressed: _save),
        const SectionTitle('Places'),
        _PlacesEditor(district: d),
      ]),
    );
  }
}

class _PlacesEditor extends StatelessWidget {
  final District district;
  const _PlacesEditor({required this.district});

  @override
  Widget build(BuildContext context) {
    final repo = DistrictRepository();
    return StreamBuilder<List<Place>>(
      stream: repo.places(district.id),
      builder: (context, snap) {
        final places = snap.data ?? const [];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final p in places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(p.experienceType.icon, color: AppColors.primary),
              title: Text(p.name),
              subtitle: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => _edit(context, p),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: 'Delete ${p.name}?', message: 'Users will no longer see this place.', confirm: 'Delete', destructive: true);
                  if (!ok || !context.mounted) return;
                  final a = adminOf(context);
                  await repo.deletePlace(p, adminUid: a.uid, adminName: a.name);
                },
              ),
            ),
          if (places.isEmpty) const Text('No places yet.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Add place'),
          ),
        ]);
      },
    );
  }

  Future<void> _edit(BuildContext context, Place? p) async {
    final name = TextEditingController(text: p?.name);
    final desc = TextEditingController(text: p?.description);
    var type = p?.experienceType ?? Experience.nature;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(p == null ? 'Add place' : 'Edit place'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            DropdownButtonFormField<Experience>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Experience type'),
              items: [for (final e in Experience.values) DropdownMenuItem(value: e, child: Text(e.label))],
              onChanged: (v) => setS(() => type = v ?? type),
            ),
            const SizedBox(height: 8),
            TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Short description')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !context.mounted) return;
    final repo = DistrictRepository();
    final a = adminOf(context);
    await repo.savePlace(
      Place(
        id: p?.id ?? repo.newPlaceId(district.id),
        districtId: district.id,
        name: name.text.trim(),
        experienceType: type,
        description: desc.text.trim(),
      ),
      p,
      adminUid: a.uid,
      adminName: a.name,
    );
  }
}
