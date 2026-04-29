class GermanPhoneValidator {
  static const String invalidPhoneMessage =
      'Invalid German phone number. Please enter a valid number.';

  static String sanitize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), '');
  }

  static bool isValidGermanPhoneNumber(String input) {
    return validateGermanPhoneNumber(input) == null;
  }

  static String? validateGermanPhoneNumber(String input, {bool allowEmpty = true}) {
    final sanitized = sanitize(input);

    if (sanitized.isEmpty) {
      return allowEmpty ? null : invalidPhoneMessage;
    }

    // Optional + at start, then digits only.
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(sanitized)) {
      return invalidPhoneMessage;
    }

    // Must start with +49 (international) or 0 (local).
    // if (!(sanitized.startsWith('+49') || sanitized.startsWith('0'))) {
    //   return invalidPhoneMessage;
    // }

    final digitsOnly = sanitized.startsWith('+')
        ? sanitized.substring(1)
        : sanitized;

    // Typical German phone lengths in digits.
    if (digitsOnly.length < 10 || digitsOnly.length > 14) {
      return invalidPhoneMessage;
    }

    return null;
  }
}
