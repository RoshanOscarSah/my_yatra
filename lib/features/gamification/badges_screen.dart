import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/widgets/common.dart';
import '../dna/dna_provider.dart';
import 'engine/stats.dart';
import 'stats_provider.dart';

IconData badgeIcon(String key) => switch (key) {
      'flag' => Icons.flag_rounded,
      'hiking' => Icons.hiking_rounded,
      'explore' => Icons.explore_rounded,
      'landscape' => Icons.landscape_rounded,
      'flight' => Icons.flight_takeoff_rounded,
      'stars' => Icons.stars_rounded,
      'map' => Icons.map_rounded,
      'public' => Icons.public_rounded,
      _ => Icons.emoji_events_rounded,
    };

/// Badges, district challenges and gap challenges (US-9.1, US-9.2).
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileP = context.watch<ProfileProvider>();
    if (!profileP.gamificationOn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Badges & challenges')),
        body: const EmptyState(
          icon: Icons.toggle_off_outlined,
          title: 'Badges are switched off',
          message: 'Turn them back on in Profile → Settings.',
        ),
      );
    }
    final sp = context.watch<StatsProvider>();
    final s = sp.stats;
    final dna = context.watch<DnaProvider>().result;
    final dp = context.watch<DistrictProvider>();
    final profile = profileP.profile!;

    final gapChallenges = dna == null
        ? <GapChallenge>[]
        : GapChallenge.generate(
            gaps: dna.ranked.reversed.where(dna.gaps.contains).toList(),
            perProvince: s.perProvince,
            districtExists: (c, p) =>
                dp.inProvince(p).any((d) => d.experienceTypes.contains(c) && !s.visitedIds.contains(d.id)),
          ).where((g) => !profile.dismissedChallenges.contains(g.id)).toList();

    Widget badgeTile(Badge b) {
      final unlocked = b.isUnlocked(s);
      return InfoCard(
        color: unlocked ? AppColors.primarySoft : AppColors.surface,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: unlocked ? AppColors.primary : AppColors.border,
            child: Icon(badgeIcon(b.icon), color: unlocked ? Colors.white : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(b.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: b.progress(s),
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
            ]),
          ),
          if (unlocked) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.verified, color: AppColors.primary)),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Badges & challenges')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('${sp.unlockedBadges.length} of ${sp.allBadges.length} earned',
            style: const TextStyle(color: AppColors.textSecondary)),
        const SectionTitle('Milestones'),
        for (final b in milestoneBadges) Padding(padding: const EdgeInsets.only(bottom: 8), child: badgeTile(b)),
        const SectionTitle('District challenges'),
        for (final b in districtChallenges) Padding(padding: const EdgeInsets.only(bottom: 8), child: badgeTile(b)),
        const SectionTitle('Challenges from your gaps'),
        if (gapChallenges.isEmpty)
          const Text('No gap challenges right now. Keep exploring!',
              style: TextStyle(color: AppColors.textSecondary)),
        for (final g in gapChallenges)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GapChallengeTile(
              challenge: g,
              accepted: profile.acceptedChallenges.contains(g.id),
              complete: g.isComplete(sp.statsVisits),
            ),
          ),
      ]),
    );
  }
}

class _GapChallengeTile extends StatelessWidget {
  final GapChallenge challenge;
  final bool accepted;
  final bool complete;
  const _GapChallengeTile({required this.challenge, required this.accepted, required this.complete});

  @override
  Widget build(BuildContext context) {
    final profile = context.read<ProfileProvider>();
    final p = profile.profile!;
    return InfoCard(
      color: complete && accepted ? AppColors.primarySoft : AppColors.goldSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          'You have not explored many ${challenge.category.label.toLowerCase()} places, and '
          '${Province.nameOf(challenge.province)} is one of your least-explored provinces.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        if (accepted && complete)
          const TagChip('Completed!', icon: Icons.check)
        else if (accepted)
          const TagChip('Accepted · in progress', color: Colors.white)
        else
          Row(children: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => profile.update({
                'acceptedChallenges': [...p.acceptedChallenges, challenge.id]
              }),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => profile.update({
                'dismissedChallenges': [...p.dismissedChallenges, challenge.id]
              }),
              child: const Text('Dismiss'),
            ),
          ]),
      ]),
    );
  }
}
