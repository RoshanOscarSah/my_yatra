import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../auth/privacy_policy_screen.dart';

/// US-1.5: "Your data is private" + data used by the AI.
class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  static const aiInputs = [
    (Icons.favorite_border, 'Interests', 'The kinds of places you chose', 'DNA · Recommendations'),
    (Icons.directions_walk, 'Travel habits', 'How often, your style, who you travel with', 'DNA · Recommendations'),
    (Icons.payments_outlined, 'Planning', 'Budget, distance, season, starting district', 'Recommendations'),
    (Icons.place_outlined, 'Visited districts', 'Which districts you marked visited', 'DNA · Gaps · Recommendations'),
    (Icons.local_activity_outlined, 'Activities', 'Places and activity types you recorded', 'DNA · Gaps'),
    (Icons.thumbs_up_down_outlined, 'Feedback', 'Helpful / not interested / reports on suggestions', 'Recommendations'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & security')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        InfoCard(
          color: AppColors.lavender,
          child: Row(children: [
            const Icon(Icons.verified_user_outlined, size: 36, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your data is private', style: AppTheme.serif(18)),
                const SizedBox(height: 4),
                const Text(
                    'Your visits, journal, photos and itineraries can only be opened by you. '
                    'Reviews you post show only your display name.'),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Data used by AI'),
        const Text('Journey DNA, gap analysis and recommendations use only these inputs:',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        for (final i in aiInputs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: AppColors.primarySoft, child: Icon(i.$1, color: AppColors.primary)),
            title: Text(i.$2),
            subtitle: Text('${i.$3}\nUsed for: ${i.$4}'),
            isThreeLine: true,
          ),
        const SizedBox(height: 8),
        const Text('Not used: your name, email, photos, journal text or location.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          child: const Text('Read the full privacy policy'),
        ),
      ]),
    );
  }
}
