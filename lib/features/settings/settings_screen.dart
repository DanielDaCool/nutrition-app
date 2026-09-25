// OWNER: engine agent (A). Contract stub: keep the class name and constructor.
import 'package:flutter/material.dart';

import '../activity/widgets/health_connect_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          HealthConnectSettingsTile(),
        ],
      ),
    );
  }
}
