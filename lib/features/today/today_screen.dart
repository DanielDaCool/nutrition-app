// OWNER: weight & charts agent (D). Contract stub: keep the class name/constructor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../activity/widgets/activity_card.dart';
import '../food/widgets/meals_section.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayKey = ref.watch(selectedDayProvider);
    return Scaffold(
      appBar: AppBar(title: Text(dayKey)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          MealsSection(dayKey: dayKey),
          ActivityCard(dayKey: dayKey),
        ],
      ),
    );
  }
}
