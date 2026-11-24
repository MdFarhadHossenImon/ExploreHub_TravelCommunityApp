import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens: deep green surfaces with warm tan accents.
/// (Names kept from the first version so every screen picks up the new look.)
class C {
  static const primary = Color(0xFFE8B16D); // tan accent
  static const primaryDark = Color(0xFFC98F4A);
  static const on = Color(0xFF1B2B2A); // text/icons placed on the accent
  static const sky = Color(0xFF8FB3AC); // sage
  static const ink = Color(0xFFF1ECE2); // main text
  static const muted = Color(0xFF8EA6A2);
  static const line = Color(0xFF2E4B49);
  static const bg = Color(0xFF1B3130);
  static const card = Color(0xFF223D3C);
  static const tint = Color(0x24E8B16D);
  static const cream = Color(0xFFF5F0E6); // light splash / logo background
  static const star = Color(0xFFF5B301);
  static const ok = Color(0xFFE8B16D);
  static const danger = Color(0xFFE5806F);
}

/// Cards are separated by a hairline border instead of a drop shadow on dark surfaces.
const softShadow = <BoxShadow>[];

OutlineInputBorder _border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: C.primary,
      onPrimary: C.on,
      secondary: C.sky,
      onSecondary: C.on,
      surface: C.card,
      onSurface: C.ink,
      error: C.danger,
      outline: C.line,
    ),
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    dividerColor: C.line,
  );
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink, fontFamilyFallback: const ['NotoSansBengali']);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: C.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: C.muted),
      border: _border(C.line),
      enabledBorder: _border(C.line),
      focusedBorder: _border(C.primary),
      errorBorder: _border(C.danger),
      focusedErrorBorder: _border(C.danger),
    ),
    cardColor: C.card,
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1),
    dialogTheme: DialogThemeData(backgroundColor: C.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    popupMenuTheme: PopupMenuThemeData(color: C.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.primary,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: C.on, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: C.card,
        foregroundColor: C.muted,
        selectedBackgroundColor: C.primary,
        selectedForegroundColor: C.on,
        side: const BorderSide(color: C.line),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.on : C.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.primary : C.line),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: C.primary, foregroundColor: C.on),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.primary)),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: C.card, indicatorColor: C.primary),
  );
}
