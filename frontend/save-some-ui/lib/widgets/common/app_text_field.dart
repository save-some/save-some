import 'package:flutter/material.dart';

/// A form field matching the design's auth inputs: leading glyph, cream fill,
/// taupe hairline border, 8px corners.
///
/// The `TextField` + `OutlineInputBorder` + lowercase-hint block this replaces
/// was copy-pasted four times across sign-in and sign-up. Borders and fill come
/// from the theme's inputDecorationTheme, so this only supplies content.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Disables autocorrect/suggestions/capitalisation, for usernames and URLs
  /// where the keyboard's help is actively unhelpful.
  final bool isIdentifier;

  const AppTextField({
    super.key,
    this.controller,
    required this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.isIdentifier = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      autocorrect: !isIdentifier,
      enableSuggestions: !isIdentifier,
      textCapitalization:
          isIdentifier ? TextCapitalization.none : TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        prefixIcon: icon == null
            ? null
            : Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}
