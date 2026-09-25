// OWNER: Health Connect agent (C). Contract stub: keep the class name/constructor.
import 'package:flutter/material.dart';

/// Settings row: Health Connect status, grant permissions, sync now.
class HealthConnectSettingsTile extends StatelessWidget {
  const HealthConnectSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.favorite_outline),
      title: Text('Health Connect'),
      subtitle: Text('Coming soon'),
    );
  }
}
