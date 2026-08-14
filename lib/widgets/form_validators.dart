import 'package:flutter/material.dart';

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

/// A standardized text form field with built-in validation.
///
/// Replaces the repetitive TextField + validator pattern used across tabs.
class ValidatedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        isDense: true,
      ),
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
    );
  }
}
