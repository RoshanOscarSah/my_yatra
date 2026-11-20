import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';

/// Safety tips, emergency numbers, active alerts and check-in (US-12.1, US-12.2).
class SafetySection extends StatelessWidget {
  final District district;
  const SafetySection({super.key, required this.district});

  /// Nepal's national emergency numbers (verify before release).
  static const emergencyNumbers = [
    ('Police', '100'),
    ('Ambulance', '102'),
    ('Fire', '101'),
    ('Tourist Police', '1144'),
  ];

  static Future<void> call(BuildContext context, String number) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok && context.mounted) showSnack(context, 'Call $number from your phone.');
  }

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Safety'),
      StreamBuilder<List<SafetyAlert>>(
        stream: repo.activeAlerts(district.id),
        builder: (_, snap) {
          final alerts = snap.data ?? const [];
          return Column(children: [
            for (final a in alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InfoCard(
                  color: const Color(0xFFFDECEA),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Posted ${a.createdAt == null ? '' : DateFormat.yMMMd().format(a.createdAt!)} · '
                          'valid until ${DateFormat.yMMMd().format(a.expiresAt)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
      if (district.safetyNotes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InfoCard(
            color: AppColors.goldSoft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.health_and_safety_outlined, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(district.safetyNotes)),
            ]),
          ),
        ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in emergencyNumbers)
          ActionChip(
            avatar: const Icon(Icons.call, size: 16),
            label: Text('${e.$1} ${e.$2}'),
            onPressed: () => call(context, e.$2),
          ),
      ]),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => checkIn(context, district.name),
        icon: const Icon(Icons.sms_outlined),
        label: Text('Check in: I\'m safe in ${district.name}'),
      ),
    ]);
  }
}

/// A short warning near the top of the district page, so an active alert is
/// seen without scrolling down to the Safety section (US-12.1).
class ActiveAlertBanner extends StatelessWidget {
  final String districtId;
  const ActiveAlertBanner({super.key, required this.districtId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SafetyAlert>>(
      stream: CommunityRepository().activeAlerts(districtId),
      builder: (_, snap) {
        final alerts = snap.data ?? const [];
        if (alerts.isEmpty) return const SizedBox.shrink();
        final more = alerts.length - 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InfoCard(
            color: const Color(0xFFFDECEA),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(alerts.first.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${more > 0 ? '+$more more · ' : ''}See Safety below for details',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Opens the user's own messaging app with a prefilled message (US-12.2).
/// No location is read or tracked.
Future<void> checkIn(BuildContext context, String districtName) async {
  final contact = context.read<ProfileProvider>().profile?.emergencyContact;
  if (contact == null) {
    showSnack(context, 'Add an emergency contact in Profile → Settings first.');
    return;
  }
  final time = DateFormat('d MMM, h:mm a').format(DateTime.now());
  final body = 'Hi ${contact.name}, I\'m safe in $districtName ($time). — sent from MyYatra';
  final uri = Uri(scheme: 'sms', path: contact.phone, queryParameters: {'body': body});
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) showSnack(context, 'Could not open your messaging app.');
}
