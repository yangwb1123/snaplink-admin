/// Local-user form validators (username / email / initial password).
///
/// Pure rules returning catalog keys — the create/edit dialog renders them
/// through `context.tr` so zh users get translated validation copy.
library;

String? validateSnaplinkLocalUsername(String? value) {
  final username = value?.trim() ?? '';
  if (username.length < 3 || username.length > 50) {
    return 'Use 3–50 characters';
  }
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$').hasMatch(username)) {
    return 'Start with a letter; use letters, digits, _ or -';
  }
  return null;
}

String? validateSnaplinkLocalEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.length > 254 ||
      !RegExp(
        r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
      ).hasMatch(email)) {
    return 'Enter a valid email';
  }
  return null;
}

String? validateSnaplinkInitialPassword(String? value) {
  final password = value ?? '';
  if (password.length < 8 ||
      !RegExp(r'\p{L}', unicode: true).hasMatch(password) ||
      !RegExp(r'\p{N}', unicode: true).hasMatch(password)) {
    return 'Use 8+ characters with a letter and a digit';
  }
  return null;
}
