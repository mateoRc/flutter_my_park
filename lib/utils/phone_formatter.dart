/// Utility helpers for sanitising and validating phone numbers entered by users.
///
/// The helpers assume international numbers with a leading `+` and digits.
/// They strip spaces and punctuation, and enforce a 7–15 digit length (roughly
/// aligned with ITU E.164 guidance).
String normalizePhoneNumber(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  var seenPlus = false;

  for (final rune in trimmed.runes) {
    final char = String.fromCharCode(rune);
    if (char == '+') {
      if (!seenPlus && buffer.isEmpty) {
        buffer.write(char);
        seenPlus = true;
      }
      // Ignore additional plus characters.
    } else if (_digitRegex.hasMatch(char)) {
      buffer.write(char);
    }
    // All other characters (spaces, hyphens, etc.) are ignored.
  }

  final normalized = buffer.toString();
  if (normalized.isEmpty || normalized == '+') {
    return '';
  }
  return normalized;
}

/// Returns a display value for the form field. Currently identical to the
/// normalised value but extracted for future formatting tweaks (grouping, etc.).
String formatPhoneNumberForDisplay(String input) {
  return normalizePhoneNumber(input);
}

/// Validates an international phone number and returns an error message when
/// invalid. Returns `null` when the number passes all checks.
String? validatePhoneNumber(String input) {
  final normalized = normalizePhoneNumber(input);
  if (normalized.isEmpty) {
    return 'Phone number is required';
  }
  if (!normalized.startsWith('+')) {
    return 'Include the country code (e.g. +385123456)';
  }

  final digits = normalized.substring(1);
  if (!_digitsOnlyRegex.hasMatch(digits)) {
    return 'Only digits are allowed after the country code';
  }
  if (digits.length < 7) {
    return 'Phone number is too short';
  }
  if (digits.length > 15) {
    return 'Phone number is too long';
  }

  return null;
}

final RegExp _digitRegex = RegExp(r'[0-9]');
final RegExp _digitsOnlyRegex = RegExp(r'^[0-9]+$');
