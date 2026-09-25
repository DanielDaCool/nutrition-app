import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Camera barcode scanner (product barcodes only). Pops with the barcode
/// string, or null if cancelled. The code can also be typed.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
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
          IconButton(
            tooltip: 'Torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera permission is needed to scan. You can type '
                            'the barcode instead.'
                      : 'Camera unavailable (${error.errorCode.name}). You '
                            'can type the barcode instead.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
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
