import 'package:flutter/material.dart';

// Theme style keys for dark theme values
enum ThemeStyleKey {
  backgroundPrimaryColor,
  backgroundSecondaryColor,
  popupBackgroundColor,
  textFieldColor,
  accentColor,
  strokeColor,
  buttonColor,
  fontPrimaryColor,
  fontSecondaryColor,
  linkColor,
  focusColor,
  borderWidth,
  navigationControlBorderWidth,
  accentOpacityNormal,
  accentOpacityHover,
  accentOpacityHit,
  buttonOpacityNormal,
  buttonOpacityHover,
  buttonOpacityHit,
  itemOpacityDisabled,
}

const Map<ThemeStyleKey, dynamic> darkThemeValues = {
  ThemeStyleKey.backgroundPrimaryColor: Color.fromARGB(255, 34, 34, 35),
  ThemeStyleKey.backgroundSecondaryColor: Color.fromARGB(255, 30, 30, 31),
  ThemeStyleKey.popupBackgroundColor: Color.fromARGB(255, 42, 42, 43),
  ThemeStyleKey.textFieldColor: Color.fromARGB(255, 26, 26, 28),
  ThemeStyleKey.accentColor: Color(0xFF2093FE),
  ThemeStyleKey.strokeColor: Color(0xFF1E1E1E),
  ThemeStyleKey.buttonColor: Color(0xFF595959),
  ThemeStyleKey.fontPrimaryColor: Color(0xFFEBEBEB),
  ThemeStyleKey.fontSecondaryColor: Color(0xFFBDBDBD),
  ThemeStyleKey.linkColor: Color(0xFF70AFEA),
  ThemeStyleKey.focusColor: Color(0xFF75507B),
  ThemeStyleKey.borderWidth: 0.0,
  ThemeStyleKey.navigationControlBorderWidth: 2.0,
  ThemeStyleKey.accentOpacityNormal: 0.5,
  ThemeStyleKey.accentOpacityHover: 0.3,
  ThemeStyleKey.accentOpacityHit: 0.7,
  ThemeStyleKey.buttonOpacityNormal: 0.7,
  ThemeStyleKey.buttonOpacityHover: 0.5,
  ThemeStyleKey.buttonOpacityHit: 1.0,
  ThemeStyleKey.itemOpacityDisabled: 0.3,
};

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.dark(
      primary: darkThemeValues[ThemeStyleKey.accentColor],
      surface: darkThemeValues[ThemeStyleKey.backgroundPrimaryColor],
    ),
    scaffoldBackgroundColor: darkThemeValues[ThemeStyleKey.backgroundPrimaryColor],
    splashFactory: NoSplash.splashFactory,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        backgroundColor: darkThemeValues[ThemeStyleKey.buttonColor],
        foregroundColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        backgroundColor: darkThemeValues[ThemeStyleKey.buttonColor],
        foregroundColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        foregroundColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      color: darkThemeValues[ThemeStyleKey.popupBackgroundColor],
      textStyle: TextStyle(color: darkThemeValues[ThemeStyleKey.fontPrimaryColor]),
      position: PopupMenuPosition.under,
      menuPadding: EdgeInsets.all(0),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        foregroundColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: darkThemeValues[ThemeStyleKey.textFieldColor],
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
    ),
  );
}