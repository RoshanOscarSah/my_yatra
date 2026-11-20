import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/experience_ui.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/district_picker.dart';

// Reusable preference widgets: used by onboarding (S2) and Preferences (S3,
// US-2.5). Each takes an initial value and an onChanged.

class InterestsPicker extends StatelessWidget {
  final Set<Experience> value;
  final ValueChanged<Set<Experience>> onChanged;
  const InterestsPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 520 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          for (final e in Experience.values)
            SelectableCard(
              key: Key('interest-${e.name}'),
              title: e.label,
              subtitle: e.blurb,
              icon: e.icon,
              selected: value.contains(e),
              onTap: () {
                final next = {...value};
                next.contains(e) ? next.remove(e) : next.add(e);
                onChanged(next);
              },
            ),
        ],
      );
    });
  }
}

class _ChoiceGroup extends StatelessWidget {
  final String title;
  final Map<String, String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final bool missing;
  const _ChoiceGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onTap,
    this.missing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      if (missing)
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('Please answer this question.',
              style: TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options.entries)
          FilterChip(
            label: Text(o.value),
            selected: selected.contains(o.key),
            onSelected: (_) => onTap(o.key),
          ),
      ]),
    ]);
  }
}

class HabitsForm extends StatelessWidget {
  final TravelHabits value;
  final ValueChanged<TravelHabits> onChanged;
  final bool showErrors;
  const HabitsForm({super.key, required this.value, required this.onChanged, this.showErrors = false});

  static const frequencies = {
    'rarely': 'Rarely (once a year or less)',
    'sometimes': 'Sometimes (2–3 trips a year)',
    'frequently': 'Frequently (4+ trips a year)',
  };
  static const styles = {
    'relaxing': 'Relaxing in nature',
    'sightseeing': 'Sightseeing & culture',
    'adventure': 'Adventure & trekking',
    'food': 'Food & local life',
    'heritage': 'Heritage & history',
    'pilgrimage': 'Pilgrimage',
  };
  static const companions = {
    'family': 'Family',
    'friends': 'Friends',
    'solo': 'Solo',
    'others': 'Others',
  };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ChoiceGroup(
        title: 'How often do you travel?',
        options: frequencies,
        selected: {if (value.frequency != null) value.frequency!},
        missing: showErrors && value.frequency == null,
        onTap: (k) => onChanged(value.copyWith(frequency: k)),
      ),
      _ChoiceGroup(
        title: 'What is your main travel style?',
        options: styles,
        selected: {if (value.style != null) value.style!},
        missing: showErrors && value.style == null,
        onTap: (k) => onChanged(value.copyWith(style: k)),
      ),
      _ChoiceGroup(
        title: 'Who do you usually travel with?',
        options: companions,
        selected: value.companions.toSet(),
        missing: showErrors && value.companions.isEmpty,
        onTap: (k) {
          final s = value.companions.toSet();
          s.contains(k) ? s.remove(k) : s.add(k);
          onChanged(value.copyWith(companions: s.toList()));
        },
      ),
    ]);
  }
}

class PlanningForm extends StatelessWidget {
  final PlanningPrefs value;
  final ValueChanged<PlanningPrefs> onChanged;
  final bool showErrors;
  const PlanningForm({super.key, required this.value, required this.onChanged, this.showErrors = false});

  static const distances = {
    'near': 'Near (under 150 km)',
    'medium': 'Medium (150–350 km)',
    'far': 'Far (over 350 km)',
  };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ChoiceGroup(
        title: 'Budget range',
        options: {
          for (final e in CostLevel.labels.entries)
            e.key.toString(): '${e.value} · ${CostLevel.range(e.key)}'
        },
        selected: {if (value.budget != null) value.budget.toString()},
        missing: showErrors && value.budget == null,
        onTap: (k) => onChanged(value.copyWith(budget: int.parse(k))),
      ),
      _ChoiceGroup(
        title: 'How far are you happy to travel?',
        options: distances,
        selected: {if (value.distance != null) value.distance!},
        missing: showErrors && value.distance == null,
        onTap: (k) => onChanged(value.copyWith(distance: k)),
      ),
      _ChoiceGroup(
        title: 'Preferred season',
        options: {for (final s in Season.values) s.name: s.label},
        selected: {if (value.season != null) value.season!.name},
        missing: showErrors && value.season == null,
        onTap: (k) => onChanged(value.copyWith(season: Season.fromName(k))),
      ),
      const SizedBox(height: 16),
      const Text('Starting district', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      const SizedBox(height: 8),
      DistrictPickerField(
        label: 'Where do you usually start from?',
        value: value.startDistrictId,
        errorText: showErrors && value.startDistrictId == null ? 'Choose a district.' : null,
        onChanged: (id) => onChanged(value.copyWith(startDistrictId: id)),
      ),
    ]);
  }
}

/// All 77 districts with checkboxes, grouped by province, with search (US-2.4).
class VisitedDistrictPicker extends StatefulWidget {
  final Set<String> value;
  final ValueChanged<Set<String>> onChanged;
  const VisitedDistrictPicker({super.key, required this.value, required this.onChanged});

  @override
  State<VisitedDistrictPicker> createState() => _VisitedDistrictPickerState();
}

class _VisitedDistrictPickerState extends State<VisitedDistrictPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search), hintText: 'Search 77 districts'),
        onChanged: (v) => setState(() => _q = v.toLowerCase()),
      ),
      const SizedBox(height: 8),
      Text('${widget.value.length} selected',
          style: const TextStyle(color: AppColors.textSecondary)),
      for (final p in Province.all) ...[
        Builder(builder: (_) {
          final list = dp
              .inProvince(p.number)
              .where((d) => d.name.toLowerCase().contains(_q))
              .toList();
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text('${p.name} Province',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            for (final d in list)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(d.name),
                value: widget.value.contains(d.id),
                onChanged: (v) {
                  final s = {...widget.value};
                  v == true ? s.add(d.id) : s.remove(d.id);
                  widget.onChanged(s);
                },
              ),
          ]);
        }),
      ],
    ]);
  }
}
