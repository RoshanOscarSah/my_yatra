import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/repositories/district_repository.dart';
import '../../core/widgets/common.dart';
import 'admin_alerts_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_changelog_screen.dart';
import 'admin_districts_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_reviews_screen.dart';

/// Shows [child] only to admins. Firestore rules enforce the same on the server.
class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<ProfileProvider>().isAdmin;
    if (isAdmin) return child;
    return Scaffold(
      appBar: AppBar(),
      body: const EmptyState(
          icon: Icons.lock_outline, title: 'Admins only', message: 'You do not have access to this page.'),
    );
  }
}

/// Admin identity for change-log entries.
({String uid, String name}) adminOf(BuildContext context) {
  final p = context.read<ProfileProvider>().profile!;
  return (uid: p.uid, name: p.displayName);
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool _seeding = false;

  Future<void> _seed() async {
    final ok = await confirmDialog(context,
        title: 'Seed district data?',
        message: 'Writes the bundled data for all 77 districts and their places to Firestore. '
            'Existing district documents with the same id are overwritten.',
        confirm: 'Seed');
    if (!ok || !mounted) return;
    setState(() => _seeding = true);
    final a = adminOf(context);
    try {
      await DistrictRepository().seed(adminUid: a.uid, adminName: a.name);
      if (mounted) showSnack(context, '77 districts seeded.');
    } catch (e) {
      if (mounted) showSnack(context, 'Seeding failed: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminGate(child: w)));
    Widget tile(IconData i, String t, String s, Widget page) => Card(
          child: ListTile(
            leading: Icon(i, color: AppColors.primary),
            title: Text(t),
            subtitle: Text(s),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => go(page),
          ),
        );
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          InfoCard(
            color: dp.fromFirestore ? AppColors.lavender : AppColors.goldSoft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dp.fromFirestore
                  ? 'District data is served from Firestore (${dp.districts.length} districts).'
                  : 'Firestore has no district data yet. The app is using the bundled data.'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('seed'),
                onPressed: _seeding ? null : _seed,
                icon: _seeding
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(dp.fromFirestore ? 'Re-seed bundled data' : 'Seed 77 districts'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          tile(Icons.map_outlined, 'Districts & places', 'Edit information, places, less-explored', const AdminDistrictsScreen()),
          tile(Icons.warning_amber_rounded, 'Safety alerts', 'Add alerts with an expiry date', const AdminAlertsScreen()),
          tile(Icons.inbox_outlined, 'Feedback inbox', 'App feedback, reports, wrong info', const AdminFeedbackScreen()),
          tile(Icons.rate_review_outlined, 'Review moderation', 'Remove inappropriate reviews', const AdminReviewsScreen()),
          tile(Icons.bar_chart, 'Content analytics', 'Coverage, missing fields, visit totals', const AdminAnalyticsScreen()),
          tile(Icons.history, 'Recent changes', 'Who changed what and when', const AdminChangeLogScreen()),
        ]),
      ),
    );
  }
}
