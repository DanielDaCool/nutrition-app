// OWNER: Health Connect agent (C). Contract stub: keep the class name/constructor.
import 'package:flutter/material.dart';

/// Steps and workouts for one day. Shown on the Today screen.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(title: Text('Activity'), subtitle: Text('Coming soon')),
    );
  }
}
