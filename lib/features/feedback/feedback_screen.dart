import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';

/// US-14.1 app feedback (layout idea from Hariyo's feedback_screen.dart,
/// but sent to Firestore) and the user's reports with their status (US-14.3).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _rating = 0;
  String _category = 'suggestion';
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_rating == 0) {
      setState(() => _error = 'Choose a rating from 1 to 5.');
      return;
    }
    if (_category == 'bug' && _text.text.trim().isEmpty) {
      setState(() => _error = 'Please describe the problem.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final uid = context.read<ProfileProvider>().profile!.uid;
    await CommunityRepository().sendFeedback(FeedbackItem(
      id: '',
      type: 'app',
      uid: uid,
      rating: _rating,
      category: _category,
      text: _text.text.trim(),
    ));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _rating = 0;
      _text.clear();
    });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thank you!'),
        content: const Text('Your feedback has reached the MyYatra team.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<ProfileProvider>().profile!.uid;
    final dp = context.watch<DistrictProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('How is MyYatra working for you?', style: AppTheme.serif(20)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              onPressed: () => setState(() => _rating = i),
              icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 36, color: AppColors.warning),
            ),
        ]),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'bug', label: Text('Bug')),
            ButtonSegment(value: 'suggestion', label: Text('Suggestion')),
            ButtonSegment(value: 'other', label: Text('Other')),
          ],
          selected: {_category},
          onSelectionChanged: (s) => setState(() => _category = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Your comment'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Send feedback', loading: _busy, onPressed: _send),
        const SectionTitle('My feedback & reports'),
        StreamBuilder<List<FeedbackItem>>(
          stream: CommunityRepository().myFeedback(uid),
          builder: (_, snap) {
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return const Text('Nothing sent yet.', style: TextStyle(color: AppColors.textSecondary));
            }
            return Column(children: [
              for (final f in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (f.type) {
                    'recommendation' => 'Recommendation report · ${dp.byId(f.districtId)?.name ?? ''}',
                    'district_info' => 'Wrong info · ${dp.byId(f.districtId)?.name ?? ''} (${f.category})',
                    _ => 'App feedback · ${f.category}',
                  }),
                  subtitle: Text('${f.text.isEmpty ? '—' : f.text}\n'
                      '${f.createdAt == null ? '' : DateFormat.yMMMd().format(f.createdAt!)}'),
                  isThreeLine: true,
                  trailing: StatusChip(f.status),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) => switch (status) {
        'resolved' => const TagChip('Resolved', color: Color(0xFFE3F1E4), textColor: AppColors.success),
        'reviewed' => const TagChip('Reviewed', color: AppColors.goldSoft, textColor: AppColors.warning),
        _ => const TagChip('New'),
      };
}
