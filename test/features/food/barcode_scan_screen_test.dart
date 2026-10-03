import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/app/providers.dart';
import 'package:nutrition_app/features/food/screens/barcode_scan_screen.dart';

void main() {
  Future<void> pumpScan(WidgetTester tester, {required bool isWeb}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isWebProvider.overrideWithValue(isWeb)],
        child: const MaterialApp(home: BarcodeScanScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('Android offers the torch button', (tester) async {
    await pumpScan(tester, isWeb: false);
    expect(find.byTooltip('Torch'), findsOneWidget);
    expect(find.text('Type barcode'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('web leaves out the torch button, which browsers lack', (
    tester,
  ) async {
    await pumpScan(tester, isWeb: true);
    expect(find.byTooltip('Torch'), findsNothing);
    expect(find.text('Type barcode'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
