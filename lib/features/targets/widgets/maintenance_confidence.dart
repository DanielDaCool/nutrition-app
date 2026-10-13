// OWNER: engine agent (A).
import 'package:flutter/material.dart';

import '../engine/engine.dart';
import '../engine/readiness.dart';

/// One line on what a maintenance estimate is based on: how much of the
/// user's own data went in and how much is formula. It shows no range or
/// score; the engine doesn't model the uncertainty of the formula part.
///
/// The caller gates it with `AppFeature.targetInsights`.
class MaintenanceConfidenceLine extends StatelessWidget {
  const MaintenanceConfidenceLine({super.key, required this.explanation});

  final Explanation explanation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      basisLine(explanation),
      key: const Key('basisLine'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
