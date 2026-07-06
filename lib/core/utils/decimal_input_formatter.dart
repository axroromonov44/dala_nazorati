import 'package:flutter/services.dart';

/// Restricts a decimal text field to digits and a single dot, capping the
/// fractional part to [maxDecimals] digits as the user types or pastes.
///
/// Structural issues (multiple dots, leading zeros, missing integer part)
/// are intentionally left untouched here so they can be surfaced as an
/// "invalid number" error via [isValidDecimal] instead of being silently
/// blocked.
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.maxDecimals = 3});

  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    if (!RegExp(r'^[0-9.]*$').hasMatch(text)) {
      return oldValue;
    }

    final dotIndex = text.indexOf('.');
    if (dotIndex == -1) return newValue;

    final decimals = text.substring(dotIndex + 1);
    if (decimals.length <= maxDecimals || decimals.contains('.')) {
      return newValue;
    }

    final capped = '${text.substring(0, dotIndex + 1)}${decimals.substring(0, maxDecimals)}';
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

/// Matches a valid non-negative decimal number: no leading zeros (other
/// than a lone "0"), a single decimal point, an integer part before it,
/// and up to [maxDecimals] digits after it.
bool isValidDecimal(String value, {int maxDecimals = 3}) {
  if (value.isEmpty) return true;
  final pattern = RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]{0,' + maxDecimals.toString() + r'})?$');
  return pattern.hasMatch(value);
}
