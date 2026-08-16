/// Static collection of common form validation functions.
class FormValidators {
  FormValidators._();

  /// Returns an error message if the value is null or empty.
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Returns an error message if the value is not a valid hostname.
  static String? hostname(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final hostnameRegex = RegExp(
      r'^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
    );
    if (!hostnameRegex.hasMatch(value.trim())) {
      return 'Enter a valid hostname (e.g., example.com)';
    }
    return null;
  }

  /// Returns an error message if the value is not a valid URL.
  static String? url(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a valid URL (e.g., https://example.com/callback)';
    }
    return null;
  }

  /// Returns an error message if the value is not a valid email.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Returns an error message if the value is shorter than [min] characters.
  static String? minLength(
    String? value,
    int min, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim().length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  /// Returns an error message if the value contains invalid characters.
  static String? alphanumeric(
    String? value, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.trim())) {
      return '$fieldName may only contain letters, numbers, hyphens, and underscores';
    }
    return null;
  }
}
