import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';

/// Reviews: average, count, newest first; visited users can review (US-13.1).
class ReviewsSection extends StatelessWidget {
  final District district;
  const ReviewsSection({super.key, required this.district});

  @override
  Widget build(BuildContext context) {
    final repo = CommunityRepository();
    final profile = context.watch<ProfileProvider>().profile;
    final visited = context.watch<VisitProvider>().isVisited(district.id);
    return StreamBuilder<List<Review>>(
      stream: repo.reviewsFor(district.id),
      builder: (context, snap) {
        final reviews = snap.data ?? const [];
        final avg = reviews.isEmpty
            ? 0.0
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
        final mine = reviews.where((r) => r.uid == profile?.uid).firstOrNull;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle('Reviews',
              trailing: reviews.isEmpty
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                      Text(' ${avg.toStringAsFixed(1)} (${reviews.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ])),
          if (visited)
            OutlinedButton.icon(
              onPressed: () => _write(context, profile!, mine),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(mine == null ? 'Rate & review ${district.name}' : 'Edit your review'),
            )
          else
            const Text('Mark this district visited to leave a review.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          if (reviews.isEmpty)
            const Text('No reviews yet.', style: TextStyle(color: AppColors.textSecondary)),
          for (final r in reviews)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InfoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    _Stars(r.rating),
                    const Spacer(),
                    if (r.createdAt != null)
                      Text(DateFormat.yMMMd().format(r.createdAt!),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 6),
                  Text(r.text),
                  if (r.uid == profile?.uid)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (await confirmDialog(context,
                              title: 'Delete your review?',
                              message: 'This cannot be undone.',
                              confirm: 'Delete',
                              destructive: true)) {
                            await repo.deleteReview(r);
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    ),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  Future<void> _write(BuildContext context, UserProfile p, Review? existing) async {
    var rating = existing?.rating ?? 0;
    final text = TextEditingController(text: existing?.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Review ${district.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => set(() => rating = i),
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.warning, size: 32),
                ),
            ]),
            TextField(
              controller: text,
              maxLines: 4,
              maxLength: 500,
              // Rebuild so Publish enables as soon as there is text.
              onChanged: (_) => set(() {}),
              decoration: const InputDecoration(hintText: 'What should other travellers know?'),
            ),
            Text('Shown as "${p.displayName}"',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: rating == 0 || text.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await CommunityRepository().saveReview(Review(
      id: '',
      districtId: district.id,
      uid: p.uid,
      displayName: p.displayName,
      rating: rating,
      text: text.text.trim(),
      createdAt: existing?.createdAt,
    ));
    if (context.mounted) showSnack(context, 'Review published.');
  }
}

class _Stars extends StatelessWidget {
  final int n;
  const _Stars(this.n);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= n ? Icons.star_rounded : Icons.star_border_rounded,
              size: 16, color: AppColors.warning),
      ]);
}
