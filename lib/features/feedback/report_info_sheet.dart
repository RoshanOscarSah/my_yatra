import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';

/// US-14.3: report wrong district information.
Future<void> openReportInfo(BuildContext context, String districtId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (_) => _ReportSheet(
      title: 'Report wrong information',
      type: 'district_info',
      districtId: districtId,
      reasons: const {
        'cost': 'Cost',
        'transport': 'Transport',
        'season': 'Season',
        'safety': 'Safety',
        'other': 'Other',
      },
    ),
  );
}

/// US-14.2: report a recommendation. Returns true when sent.
Future<bool> openReportRecommendation(BuildContext context, String districtId, String dnaType) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (_) => _ReportSheet(
      title: 'Report this recommendation',
      type: 'recommendation',
      districtId: districtId,
      dnaType: dnaType,
      reasons: const {
        'not_my_interests': 'Does not match my interests',
        'inaccurate': 'Inaccurate',
        'other': 'Other',
      },
    ),
  );
  return r == true;
}

class _ReportSheet extends StatefulWidget {
  final String title;
  final String type;
  final String districtId;
  final String? dnaType;
  final Map<String, String> reasons;
  const _ReportSheet({
    required this.title,
    required this.type,
    required this.districtId,
    required this.reasons,
    this.dnaType,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    if (_reason == null) {
      setState(() => _error = 'Choose what is wrong.');
      return;
    }
    if (widget.type == 'district_info' && _text.text.trim().isEmpty) {
      setState(() => _error = 'Describe what is wrong.');
      return;
    }
    setState(() => _busy = true);
    final uid = context.read<ProfileProvider>().profile!.uid;
    await CommunityRepository().sendFeedback(FeedbackItem(
      id: '',
      type: widget.type,
      uid: uid,
      category: _reason!,
      text: _text.text.trim(),
      districtId: widget.districtId,
      dnaType: widget.dnaType,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
    showSnack(context, 'Thank you. Your report was sent to the MyYatra team.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: AppTheme.serif(20)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in widget.reasons.entries)
              ChoiceChip(
                label: Text(r.value),
                selected: _reason == r.key,
                onSelected: (_) => setState(() => _reason = r.key),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Add a note (what is wrong, what is correct)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(label: 'Send report', loading: _busy, onPressed: _send),
        ]),
      ),
    );
  }
}
