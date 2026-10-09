// Camera barcode scanning with a manual-entry fallback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/providers.dart';

/// Camera barcode scanner (product barcodes only). Pops with the barcode
/// string, or null if cancelled. The code can also be typed.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Set after the first pop so repeated detections don't pop twice.
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code) {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  /// Accepts the first detected code that is 6 to 14 digits.
  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && RegExp(r'^\d{6,14}$').hasMatch(v)) {
        _finish(v);
        return;
      }
    }
  }

  Future<void> _typeCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _TypeBarcodeDialog(),
    );
    if (code != null && mounted) _finish(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          // Browsers can't switch the torch; toggleTorch() throws on web.
          if (!ref.watch(isWebProvider))
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                final isOn = state.torchState == TorchState.on;
                return IconButton(
                  tooltip: isOn ? 'Turn torch off' : 'Turn torch on',
                  icon: Icon(
                    isOn
                        ? Icons.flashlight_on
                        : Icons.flashlight_on_outlined,
                    color: isOn ? Theme.of(context).colorScheme.primary : null,
                  ),
                  onPressed: () => _controller.toggleTorch(),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              debugPrint('food: camera error ${error.errorCode.name}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Camera permission is needed to scan. You can type '
                              'the barcode instead.'
                        : 'The camera isn\'t available right now. You can '
                              'type the barcode instead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton.tonalIcon(
                onPressed: _typeCode,
                icon: const Icon(Icons.keyboard),
                label: const Text('Type barcode'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for typing a barcode by hand. Pops with the digits, or null.
class _TypeBarcodeDialog extends StatefulWidget {
  const _TypeBarcodeDialog();

  @override
  State<_TypeBarcodeDialog> createState() => _TypeBarcodeDialogState();
}

class _TypeBarcodeDialogState extends State<_TypeBarcodeDialog> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final v = _c.text.trim();
    if (!RegExp(r'^\d{6,14}$').hasMatch(v)) {
      setState(() => _error = 'Enter the digits under the barcode');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Barcode'),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _ok(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Look up')),
      ],
    );
  }
}
