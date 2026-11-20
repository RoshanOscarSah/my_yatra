import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/repositories/community_repository.dart';
import '../../core/widgets/common.dart';
import 'admin_home.dart';

/// US-15.7: remove inappropriate reviews (logged in the change log).
class AdminReviewsScreen extends StatelessWidget {
  const AdminReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DistrictProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: StreamBuilder<List<Review>>(
        stream: CommunityRepository().allReviews(),
        builder: (context, snap) {
          final reviews = snap.data ?? const [];
          if (reviews.isEmpty) {
            return const EmptyState(icon: Icons.rate_review_outlined, title: 'No reviews yet', message: 'Reviews from travellers appear here.');
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final r in reviews)
              Card(
                child: ListTile(
                  title: Text('${dp.byId(r.districtId)?.name ?? r.districtId} · ${'★' * r.rating}'),
                  subtitle: Text('${r.text}\n${r.displayName}'
                      '${r.createdAt == null ? '' : ' · ${DateFormat.yMMMd().format(r.createdAt!)}'}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await confirmDialog(context,
                          title: 'Remove this review?', message: 'It will be deleted for everyone.', confirm: 'Remove', destructive: true);
                      if (!ok || !context.mounted) return;
                      final a = adminOf(context);
                      await CommunityRepository().adminDeleteReview(r, adminUid: a.uid, adminName: a.name);
                    },
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
