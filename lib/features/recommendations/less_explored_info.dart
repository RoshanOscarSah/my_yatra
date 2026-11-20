import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// US-6.4: what the "Less explored" label means.
void showLessExploredInfo(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.explore_off_outlined, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('What "less explored" means', style: AppTheme.serif(18)),
          ]),
          const SizedBox(height: 12),
          const Text(
            'This label comes from district data kept by the MyYatra team. A district is '
            'marked less explored when it receives relatively few domestic tourists and has '
            'fewer tourism services than well-known destinations, based on published tourism '
            'information and the team\'s review.\n\n'
            'Less-explored districts get a small bonus in your recommendations, but they are '
            'still ranked mainly by how well they match your Journey DNA and plans.',
            style: TextStyle(height: 1.45),
          ),
        ]),
      ),
    ),
  );
}
