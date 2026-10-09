import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_app/features/food/data/barcode_format.dart';

void main() {
  group('normalizeBarcode', () {
    test('widens a 12-digit UPC-A code to EAN-13 with a leading zero', () {
      expect(normalizeBarcode('036000291452'), '0036000291452');
    });

    test('leaves EAN-13, EAN-8 and other lengths unchanged', () {
      expect(normalizeBarcode('7290000066318'), '7290000066318');
      expect(normalizeBarcode('12345678'), '12345678');
      expect(normalizeBarcode('123456'), '123456');
    });

    test('trims whitespace', () {
      expect(normalizeBarcode('  7290000066318  '), '7290000066318');
      expect(normalizeBarcode(' 036000291452 '), '0036000291452');
    });

    test('leaves non-numeric or wrong-length input as-is', () {
      expect(normalizeBarcode('abc'), 'abc');
      expect(normalizeBarcode('123456789012345'), '123456789012345');
    });
  });

  group('barcodeVariants', () {
    test('a normalized EAN-13 from UPC-A also yields the UPC-A form', () {
      expect(barcodeVariants(normalizeBarcode('036000291452')), [
        '0036000291452',
        '036000291452',
      ]);
    });

    test('a barcode with no UPC-A/EAN-13 pairing yields itself only', () {
      expect(barcodeVariants('7290000066318'), ['7290000066318']);
    });
  });
}
