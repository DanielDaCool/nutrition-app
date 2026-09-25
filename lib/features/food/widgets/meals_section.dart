// OWNER: food agent (B). Contract stub: keep the class name and constructor.
import 'package:flutter/material.dart';

/// The meals of one day (breakfast/lunch/dinner/snacks) with add buttons and
/// the "fully logged" toggle. Shown on the Today screen.
class MealsSection extends StatelessWidget {
  const MealsSection({super.key, required this.dayKey});

  final String dayKey;

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(title: Text('Meals'), subtitle: Text('Coming soon')),
    );
  }
}
