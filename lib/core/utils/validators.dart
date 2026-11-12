class Validators {
  const Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+\-]+@[\w\-]+(\.[\w\-]+)+$',
  );

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email address is required.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid work email address.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Password is required.';
    }
    if (text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  static String? validateNonEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }
}

