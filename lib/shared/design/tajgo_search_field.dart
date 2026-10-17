import 'package:flutter/material.dart';

import '../../core/design/tajgo_design.dart';

/// Единое поле поиска TajGo.
///
/// Используется для поиска товаров/магазинов (не для адресов карты — там свой
/// компонент). Поддерживает readOnly-режим (как кнопка, открывающая экран поиска).
class TajGoSearchField extends StatelessWidget {
  const TajGoSearchField({
    super.key,
    this.controller,
    this.hintText = 'Найти товар, ресторан или магазин',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final hasText = controller?.text.isNotEmpty ?? false;
    return Semantics(
      textField: true,
      label: hintText,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        style: TajGoTypography.body,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TajGoTypography.body.copyWith(color: TajGoColors.muted),
          prefixIcon: const Icon(
            Icons.search,
            color: TajGoColors.muted,
            size: TajGoIconSizes.lg,
          ),
          suffixIcon: (hasText && onClear != null)
              ? IconButton(
                  icon: const Icon(Icons.close, size: TajGoIconSizes.md),
                  color: TajGoColors.muted,
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: TajGoColors.card,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: TajGoSpacing.md,
            horizontal: TajGoSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: TajGoRadius.smAll,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: TajGoRadius.smAll,
            borderSide: BorderSide(
              color: TajGoColors.ink.withValues(alpha: 0.06),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: TajGoRadius.smAll,
            borderSide: const BorderSide(color: TajGoColors.green, width: 1.5),
          ),
        ),
      ),
    );
  }
}
