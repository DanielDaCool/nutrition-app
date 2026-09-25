// Text input helpers shared by the weigh-in dialog and Today's quick
// weigh-in: the keyboard type and a formatter that turns ',' into '.'.
import 'package:flutter/services.dart';

/// Decimal number keyboard for weights.
const weightKeyboardType = TextInputType.numberWithOptions(decimal: true);

/// Keeps digits and one decimal point; a typed ',' becomes '.'.
class WeightInputFormatter extends TextInputFormatter {
  const WeightInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    final valid = RegExp(r'^\d{0,3}(\.\d{0,2})?$').hasMatch(text);
    if (!valid) return oldValue;
    return newValue.copyWith(text: text);
  }
}
