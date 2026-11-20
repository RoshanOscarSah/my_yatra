import 'package:flutter/material.dart';

import '../core/models/experience.dart';

extension ExperienceUi on Experience {
  IconData get icon => switch (this) {
        Experience.nature => Icons.forest_rounded,
        Experience.culture => Icons.theater_comedy_rounded,
        Experience.adventure => Icons.hiking_rounded,
        Experience.food => Icons.restaurant_rounded,
        Experience.history => Icons.account_balance_rounded,
        Experience.spiritual => Icons.self_improvement_rounded,
      };

  String get blurb => switch (this) {
        Experience.nature => 'Lakes, forests, wildlife and mountain views',
        Experience.culture => 'Festivals, villages and local life',
        Experience.adventure => 'Treks, rafting and high passes',
        Experience.food => 'Local dishes, tea and markets',
        Experience.history => 'Palaces, forts and old towns',
        Experience.spiritual => 'Temples, stupas and pilgrimages',
      };
}
