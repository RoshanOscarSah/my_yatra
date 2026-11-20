import 'package:flutter/material.dart';

import '../../app/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const sections = [
    ('What we collect',
        'Your name and email, the interests, travel habits and planning preferences you choose, the districts you mark as visited, places and activities you record, journal entries and photos, itineraries, reviews and feedback.'),
    ('Private by default',
        'Your visits, journal entries, photos, itineraries and Journey DNA are stored in your own account and can only be read by you. Not even MyYatra admins can open them.'),
    ('What others can see',
        'Only reviews you choose to post are public, and they show your display name (first name and last initial), rating, text and date.'),
    ('How the AI uses your data',
        'Journey DNA, gap analysis and recommendations are calculated from your interests, habits, planning preferences, visited districts, recorded activities and your feedback on suggestions. Nothing is sold or used for advertising.'),
    ('Aggregate statistics',
        'Admins can see only total visit counts per district, with no names or accounts attached.'),
    ('Your control',
        'You can edit your profile and preferences at any time, and delete your account together with all of its data from Profile → Edit profile.'),
    ('Location',
        'MyYatra never tracks your location in the background. A check-in message is only sent when you tap Check in, using your own messaging app.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final s in sections) ...[
            Text(s.$1, style: AppTheme.serif(17)),
            const SizedBox(height: 6),
            Text(s.$2, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
