import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/repositories/district_repository.dart';
import '../../core/widgets/common.dart';

/// Mark a district visited with a date (US-3.2). Future dates are not
/// selectable; "Before MyYatra" stores no date.
Future<bool> markVisitedFlow(BuildContext context, String districtId,
    {bool askPlaces = true}) async {
  final visits = context.read<VisitProvider>();
  final d = context.read<DistrictProvider>().byId(districtId);
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mark ${d?.name ?? 'district'} as visited', style: AppTheme.serif(20)),
          const SizedBox(height: 16),
          PrimaryButton(
              label: 'Choose the date',
              arrow: false,
              icon: Icons.calendar_month,
              onPressed: () => Navigator.pop(ctx, 'date')),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'unknown'),
              child: const Text('I don\'t remember (before MyYatra)')),
        ]),
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;
  DateTime? date;
  if (choice == 'date') {
    date = await pickPastDate(context);
    if (date == null) return false;
  }
  try {
    await visits.addVisit(districtId, date);
  } on ArgumentError catch (e) {
    if (context.mounted) showSnack(context, e.message.toString());
    return false;
  }
  if (!context.mounted) return true;
  showSnack(context, '${d?.name ?? 'District'} marked as visited. Your Journey DNA is updating.');
  if (askPlaces) {
    final add = await confirmDialog(context,
        title: 'Add places & activities?',
        message: 'Record the places you went and what you did. MyYatra learns from what you actually experienced.',
        confirm: 'Add now');
    if (add && context.mounted) await openRecordPlaces(context, districtId);
  }
  return true;
}

Future<void> openRecordPlaces(BuildContext context, String districtId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (_) => RecordPlacesSheet(districtId: districtId),
  );
}

/// US-3.4: choose places from the district's list or type your own,
/// tag activity types, edit or remove.
class RecordPlacesSheet extends StatefulWidget {
  final String districtId;
  const RecordPlacesSheet({super.key, required this.districtId});

  @override
  State<RecordPlacesSheet> createState() => _RecordPlacesSheetState();
}

class _RecordPlacesSheetState extends State<RecordPlacesSheet> {
  late List<VisitPlace> _places;
  late String _saved;
  final _custom = TextEditingController();
  bool _busy = false;

  static String _key(List<VisitPlace> l) =>
      l.map((p) => p.toMap().toString()).join('|');

  /// Unsaved edits, including a place name typed but not yet added.
  bool get _dirty => _key(_places) != _saved || _custom.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _places = [...?context.read<VisitProvider>().visitFor(widget.districtId)?.places];
    _saved = _key(_places);
    // Rebuild while typing so Back knows about a half-typed place name.
    _custom.addListener(() => setState(() {}));
  }

  /// Back, the close button and tapping outside all ask before throwing
  /// away changes.
  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('The places and activities you changed have not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _add(VisitPlace p) {
    if (_places.any((x) => x.name.toLowerCase() == p.name.toLowerCase())) return;
    setState(() => _places.add(p));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await context.read<VisitProvider>().savePlaces(widget.districtId, _places);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    final repo = context.read<DistrictRepository>();
    final d = dp.byId(widget.districtId);
    final visit = context.watch<VisitProvider>().visitFor(widget.districtId);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .85,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Places & activities', style: AppTheme.serif(20)),
                    Text(
                      '${d?.name ?? ''} · ${visit?.date == null ? 'Before MyYatra' : DateFormat.yMMMd().format(visit!.date!)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ]),
                ),
                IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                if (_places.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No places recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                for (var i = 0; i < _places.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoCard(
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                              child: Text(_places[i].name,
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                          IconButton(
                            tooltip: 'Rename',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _rename(i),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => setState(() => _places.removeAt(i)),
                          ),
                        ]),
                        const Text('What did you do here?',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final e in Experience.values)
                            FilterChip(
                              visualDensity: VisualDensity.compact,
                              showCheckmark: false,
                              avatar: Icon(e.icon, size: 14),
                              label: Text(e.label),
                              selected: _places[i].activities.contains(e),
                              onSelected: (s) => setState(() {
                                final a = {..._places[i].activities};
                                s ? a.add(e) : a.remove(e);
                                _places[i] = VisitPlace(
                                    name: _places[i].name,
                                    placeId: _places[i].placeId,
                                    activities: a.toList());
                              }),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text('Add from this district', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                StreamBuilder<List<Place>>(
                  stream: repo.places(widget.districtId),
                  builder: (_, snap) {
                    var places = snap.data ?? const <Place>[];
                    if (places.isEmpty && !dp.fromFirestore) {
                      places = DistrictRepository.seedPlaces(widget.districtId);
                    }
                    places = places
                        .where((p) => !_places.any((x) => x.name.toLowerCase() == p.name.toLowerCase()))
                        .toList();
                    if (places.isEmpty) {
                      return const Text('No more listed places. Type your own below.',
                          style: TextStyle(color: AppColors.textSecondary));
                    }
                    return Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in places)
                        ActionChip(
                          avatar: Icon(p.experienceType.icon, size: 16),
                          label: Text(p.name),
                          onPressed: () => _add(VisitPlace(
                              name: p.name, placeId: p.id, activities: [p.experienceType])),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _custom,
                      decoration: const InputDecoration(hintText: 'Or type a place name'),
                      onSubmitted: (_) => _addCustom(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _addCustom, icon: const Icon(Icons.add)),
                ]),
                const SizedBox(height: 20),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(label: 'Save', loading: _busy, onPressed: _save),
            ),
          ]),
        ),
      ),
      ),
    );
  }

  void _addCustom() {
    final t = _custom.text.trim();
    if (t.isEmpty) return;
    _add(VisitPlace(name: t));
    _custom.clear();
  }

  Future<void> _rename(int i) async {
    final c = TextEditingController(text: _places[i].name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit place'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _places[i] =
        VisitPlace(name: name, placeId: _places[i].placeId, activities: _places[i].activities));
  }
}
