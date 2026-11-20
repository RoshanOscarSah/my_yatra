import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/widgets/common.dart';
import '../admin/admin_home.dart';
import '../dna/dna_provider.dart';
import '../dna/dna_screen.dart';
import '../feedback/feedback_screen.dart';
import '../gamification/badges_screen.dart';
import '../gamification/stats_provider.dart';
import '../itinerary/itinerary_list_screen.dart';
import '../offline/downloads_screen.dart';
import 'edit_profile_screen.dart';
import 'preferences_screen.dart';
import 'privacy_data_screen.dart';
import 'settings_screen.dart';

/// Figma 11 Profile.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final p = pp.profile;
    final stats = context.watch<StatsProvider>();
    final dna = context.watch<DnaProvider>().result;
    if (p == null) return const SizedBox.shrink();

    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    Widget item(IconData icon, String title, Widget page, {String? subtitle}) => ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(page),
        );

    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        InfoCard(
          color: AppColors.lavender,
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text(p.name, style: AppTheme.serif(22)),
            Text(dna?.type ?? '', style: const TextStyle(color: AppColors.textSecondary)),
            if (p.isAdmin) const Padding(padding: EdgeInsets.only(top: 6), child: TagChip('Admin')),
            const SizedBox(height: 16),
            Row(children: [
              StatTile('${stats.stats.visitedCount}', stats.stats.visitedCount == 1 ? 'district' : 'districts'),
              StatTile('${stats.stats.percent.toStringAsFixed(0)}%', 'of Nepal'),
              if (p.gamificationOn) StatTile('${stats.unlockedBadges.length}', stats.unlockedBadges.length == 1 ? 'badge' : 'badges'),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            item(Icons.fingerprint, 'Journey DNA', const DnaScreen()),
            if (p.gamificationOn) item(Icons.emoji_events_outlined, 'Badges & challenges', const BadgesScreen()),
            item(Icons.event_note_outlined, 'My itineraries', const ItineraryListScreen()),
            item(Icons.download_outlined, 'Downloads (offline)', const DownloadsScreen()),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            item(Icons.person_outline, 'Edit profile', const EditProfileScreen()),
            item(Icons.tune, 'Preferences', const PreferencesScreen(), subtitle: 'Interests, habits, budget, season'),
            item(Icons.settings_outlined, 'Settings', const SettingsScreen()),
            item(Icons.lock_outline, 'Privacy & security', const PrivacyDataScreen()),
            item(Icons.feedback_outlined, 'Feedback & my reports', const FeedbackScreen()),
            if (p.isAdmin) item(Icons.admin_panel_settings_outlined, 'Admin', const AdminHome()),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('logout'),
          onPressed: () async {
            final ok = await confirmDialog(context, title: 'Log out?', message: 'You will need to sign in again.', confirm: 'Log out');
            if (ok && context.mounted) await signOutEverywhere(context.read<AuthProvider>());
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ]),
    );
  }
}
