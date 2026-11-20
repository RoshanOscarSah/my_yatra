import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/itinerary_provider.dart';
import '../../core/providers/offline_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/district_picker.dart';
import '../onboarding/preference_widgets.dart';
import '../safety/safety_section.dart';

/// US-10.1: a simple day-by-day itinerary with a budget.
class ItineraryForm extends StatefulWidget {
  final String? districtId;
  final Itinerary? existing;
  const ItineraryForm({super.key, this.districtId, this.existing});

  @override
  State<ItineraryForm> createState() => _ItineraryFormState();
}

class _ItineraryFormState extends State<ItineraryForm> {
  late String? _district = widget.existing?.districtId ?? widget.districtId;
  late DateTimeRange? _range = widget.existing == null
      ? null
      : DateTimeRange(start: widget.existing!.startDate, end: widget.existing!.endDate);
  late final Set<String> _companions = {...?widget.existing?.companions};
  late final _budget = TextEditingController(
      text: widget.existing == null || widget.existing!.budget == 0 ? '' : '${widget.existing!.budget}');
  late List<List<String>> _days = [
    for (final d in widget.existing?.days ?? const <ItineraryDay>[]) [...d.activities]
  ];
  bool _tried = false;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _setRange(DateTimeRange r) {
    final n = r.end.difference(r.start).inDays + 1;
    setState(() {
      _range = r;
      if (_days.length < n) {
        _days = [..._days, for (var i = _days.length; i < n; i++) <String>[]];
      } else {
        _days = _days.sublist(0, n);
      }
    });
  }

  Future<void> _addActivity(int day, {int? index}) async {
    final c = TextEditingController(text: index == null ? '' : _days[day][index]);
    final t = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Day ${day + 1} activity'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Sunrise at Sarangkot')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (t == null || t.isEmpty) return;
    setState(() => index == null ? _days[day].add(t) : _days[day][index] = t);
  }

  Itinerary _build() => Itinerary(
        id: widget.existing?.id ?? context.read<ItineraryProvider>().newId(),
        districtId: _district!,
        startDate: _range!.start,
        endDate: _range!.end,
        companions: _companions.toList(),
        budget: int.tryParse(_budget.text.replaceAll(',', '')) ?? 0,
        days: [for (final d in _days) ItineraryDay(d)],
      );

  Future<void> _save() async {
    setState(() => _tried = true);
    if (_district == null || _range == null) return;
    final it = _build();
    final offline = context.read<OfflineProvider>();
    await context.read<ItineraryProvider>().save(it);
    if (offline.isSaved('itinerary:${it.id}') && mounted) {
      await _saveOffline(it);
    }
    if (mounted) {
      showSnack(context, 'Itinerary saved.');
      Navigator.pop(context);
    }
  }

  Future<void> _saveOffline(Itinerary it) async {
    final d = context.read<DistrictProvider>().byId(it.districtId);
    await context.read<OfflineProvider>().save('itinerary:${it.id}', 'itinerary',
        'Itinerary · ${d?.name ?? ''}', {
      ...it.toJson(),
      'districtName': d?.name,
      'cost': d == null ? '' : CostLevel.range(d.costLevel),
      'safetyNotes': d?.safetyNotes,
      'emergencyNumbers': {for (final e in SafetySection.emergencyNumbers) e.$1: e.$2},
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<DistrictProvider>().byId(_district);
    final fmt = DateFormat('EEE d MMM');
    final budget = int.tryParse(_budget.text.replaceAll(',', '')) ?? 0;
    final perDay = _range == null || budget == 0 ? null : budget / (_range!.end.difference(_range!.start).inDays + 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New itinerary' : 'Edit itinerary'),
        actions: [
          if (widget.existing != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDialog(context,
                    title: 'Delete itinerary?', message: 'This cannot be undone.', confirm: 'Delete', destructive: true)) {
                  if (!context.mounted) return;
                  await context.read<ItineraryProvider>().delete(widget.existing!.id);
                  if (context.mounted) await context.read<OfflineProvider>().remove('itinerary:${widget.existing!.id}');
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        DistrictPickerField(
          value: _district,
          onChanged: (v) => setState(() => _district = v),
          errorText: _tried && _district == null ? 'Choose a district.' : null,
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final now = DateTime.now();
            final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 3),
              initialDateRange: _range,
            );
            if (r != null) _setRange(r);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Dates',
              suffixIcon: const Icon(Icons.date_range),
              errorText: _tried && _range == null ? 'Choose your travel dates.' : null,
            ),
            isEmpty: _range == null,
            child: Text(_range == null ? '' : '${fmt.format(_range!.start)} – ${fmt.format(_range!.end)}'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _budget,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Total budget (NPR)', prefixText: 'NPR '),
        ),
        if (d != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InfoCard(
              color: AppColors.goldSoft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Estimated cost in ${d.name}: ${CostLevel.label(d.costLevel)} · ${CostLevel.range(d.costLevel)}'
                  '${perDay == null ? '' : '\nYour budget: about NPR ${NumberFormat.decimalPattern().format(perDay.round())} per day'}',
                ),
                if (perDay != null && perDay < (CostLevel.minPerDay[d.costLevel] ?? 0)) ...[
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This is below the usual NPR ${NumberFormat.decimalPattern().format(CostLevel.minPerDay[d.costLevel])} '
                        'per day for ${d.name}. Consider a bigger budget or fewer days.',
                        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
        const SizedBox(height: 12),
        const Text('Companions', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final c in HabitsForm.companions.entries)
            FilterChip(
              label: Text(c.value),
              selected: _companions.contains(c.key),
              onSelected: (s) => setState(() => s ? _companions.add(c.key) : _companions.remove(c.key)),
            ),
        ]),
        if (d != null)
          StreamBuilder<List<SafetyAlert>>(
            stream: CommunityRepository().activeAlerts(d.id),
            builder: (_, s) => Column(children: [
              for (final a in s.data ?? const <SafetyAlert>[])
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: InfoCard(
                    color: const Color(0xFFFDECEA),
                    child: Text('⚠ ${a.message} (until ${DateFormat.yMMMd().format(a.expiresAt)})'),
                  ),
                ),
            ]),
          ),
        if (_range != null) ...[
          const SectionTitle('Day by day'),
          for (var day = 0; day < _days.length; day++)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('Day ${day + 1} · ${fmt.format(_range!.start.add(Duration(days: day)))}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(onPressed: () => _addActivity(day), icon: const Icon(Icons.add)),
                  ]),
                  if (_days[day].isEmpty)
                    const Text('No activities yet', style: TextStyle(color: AppColors.textSecondary)),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorder: (a, b) => setState(() {
                      if (b > a) b--;
                      _days[day].insert(b, _days[day].removeAt(a));
                    }),
                    children: [
                      for (var i = 0; i < _days[day].length; i++)
                        ListTile(
                          key: ValueKey('$day-$i-${_days[day][i]}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
                          title: Text(_days[day][i]),
                          onTap: () => _addActivity(day, index: i),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _days[day].removeAt(i)),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Save itinerary', onPressed: _save),
        if (widget.existing != null) ...[
          const SizedBox(height: 10),
          Consumer<OfflineProvider>(
            builder: (_, off, _) => off.isSaved('itinerary:${widget.existing!.id}')
                ? OutlinedButton.icon(
                    onPressed: () => off.remove('itinerary:${widget.existing!.id}'),
                    icon: const Icon(Icons.download_done),
                    label: const Text('Saved offline · remove'),
                  )
                : OutlinedButton.icon(
                    onPressed: _district == null || _range == null
                        ? null
                        : () async {
                            await _saveOffline(_build());
                            if (context.mounted) showSnack(context, 'Itinerary saved for offline use.');
                          },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save for offline'),
                  ),
          ),
        ],
      ]),
    );
  }
}
