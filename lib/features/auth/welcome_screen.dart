import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nepal_map.dart';
import 'auth_screen.dart';

/// Figma 01 Welcome.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.travel_explore_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('MyYatra',
                        style: AppTheme.serif(20, color: AppColors.primary)),
                  ]),
                  const Spacer(),
                  const SizedBox(
                    height: 170,
                    child: IgnorePointer(
                      child: NepalMap(
                        labelToId: {},
                        visitedIds: {},
                        interactive: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Every district.\nA new story.', style: AppTheme.serif(36)),
                  const SizedBox(height: 12),
                  const Text(
                    'Track the places you have been across Nepal\'s 77 districts, '
                    'discover your Journey DNA and get ideas for where to go next.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Get started',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AuthScreen(startOnRegister: true))),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen())),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
