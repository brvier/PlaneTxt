import 'package:flutter/material.dart';

enum AppTheme {
  gruvbox,
  nord,
  adwaita,
  monokai,
  everforest,
}

class AppThemeData {
  final String name;
  final String description;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const AppThemeData({
    required this.name,
    required this.description,
    required this.lightTheme,
    required this.darkTheme,
  });
}

class AppThemes {
  static final Map<AppTheme, AppThemeData> _themes = {
    AppTheme.gruvbox: AppThemeData(
      name: 'Gruvbox',
      description: 'Retro groove color scheme',
      lightTheme: _gruvboxLightTheme,
      darkTheme: _gruvboxDarkTheme,
    ),
    AppTheme.nord: AppThemeData(
      name: 'Nord',
      description: 'Arctic, north-bluish color palette',
      lightTheme: _nordLightTheme,
      darkTheme: _nordDarkTheme,
    ),
    AppTheme.adwaita: AppThemeData(
      name: 'Adwaita',
      description: 'GNOME default theme',
      lightTheme: _adwaitaLightTheme,
      darkTheme: _adwaitaDarkTheme,
    ),
    AppTheme.monokai: AppThemeData(
      name: 'Monokai',
      description: 'Classic monokai color scheme',
      lightTheme: _monokaiLightTheme,
      darkTheme: _monokaiDarkTheme,
    ),
    AppTheme.everforest: AppThemeData(
      name: 'Everforest',
      description: 'Comfortable and pleasant color scheme',
      lightTheme: _everforestLightTheme,
      darkTheme: _everforestDarkTheme,
    ),
  };

  static AppThemeData getTheme(AppTheme theme) => _themes[theme]!;
  static List<AppTheme> get allThemes => AppTheme.values;
  static AppTheme get defaultTheme => AppTheme.gruvbox;

  // Gruvbox Themes
  static final ThemeData _gruvboxLightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF458588), // blue
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF689D6A), // green
      onSecondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFFB16286), // purple
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFCC241D), // red
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFBF1C7), // bg0
      onSurface: Color(0xFF3C3836), // fg0
      surfaceContainerHighest: Color(0xFFF2E5BC), // bg1
      onSurfaceVariant: Color(0xFF665C54), // fg1
      outline: Color(0xFF928374), // gray
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFFF2E5BC), // bg1
      foregroundColor: Color(0xFF3C3836), // fg0
    ),
  );

  static final ThemeData _gruvboxDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF83A598), // blue
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFB8BB26), // green
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFD3869B), // purple
      onTertiary: Color(0xFF000000),
      error: Color(0xFFFB4934), // red
      onError: Color(0xFF000000),
      surface: Color(0xFF282828), // bg0
      onSurface: Color(0xFFEBDBB2), // fg0
      surfaceContainerHighest: Color(0xFF3C3836), // bg1
      onSurfaceVariant: Color(0xFFA89984), // fg1
      outline: Color(0xFF928374), // gray
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF3C3836), // bg1
      foregroundColor: Color(0xFFEBDBB2), // fg0
    ),
  );

  // Nord Themes
  static final ThemeData _nordLightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF5E81AC), // nord8
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF88C0D0), // nord7
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFB48EAD), // nord15
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFBF616A), // nord11
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFECEFF4), // nord6
      onSurface: Color(0xFF2E3440), // nord0
      surfaceContainerHighest: Color(0xFFE5E9F0), // nord5
      onSurfaceVariant: Color(0xFF4C566A), // nord3
      outline: Color(0xFF88C0D0), // nord7
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFFE5E9F0), // nord5
      foregroundColor: Color(0xFF2E3440), // nord0
    ),
  );

  static final ThemeData _nordDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF88C0D0), // nord7
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFA3BE8C), // nord14
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFB48EAD), // nord15
      onTertiary: Color(0xFF000000),
      error: Color(0xFFBF616A), // nord11
      onError: Color(0xFF000000),
      surface: Color(0xFF2E3440), // nord0
      onSurface: Color(0xFFD8DEE9), // nord4
      surfaceContainerHighest: Color(0xFF3B4252), // nord1
      onSurfaceVariant: Color(0xFF4C566A), // nord3
      outline: Color(0xFF5E81AC), // nord8
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF3B4252), // nord1
      foregroundColor: Color(0xFFD8DEE9), // nord4
    ),
  );

  // Adwaita Themes
  static final ThemeData _adwaitaLightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF3584E4), // blue-3
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF2EC27E), // green-3
      onSecondary: Color(0xFFFFFFFF),
      tertiary: Color(0xFFC061CB), // purple-3
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFE01B24), // red-3
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF), // white
      onSurface: Color(0xFF2E3436), // dark-1
      surfaceContainerHighest: Color(0xFFF6F5F4), // light-1
      onSurfaceVariant: Color(0xFF5E5C64), // dark-2
      outline: Color(0xFF9CA0A0), // medium-1
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFFF6F5F4), // light-1
      foregroundColor: Color(0xFF2E3436), // dark-1
    ),
  );

  static final ThemeData _adwaitaDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF62A0EA), // blue-4
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFF8FF0A4), // green-4
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFC061CB), // purple-3
      onTertiary: Color(0xFF000000),
      error: Color(0xFFF66151), // red-4
      onError: Color(0xFF000000),
      surface: Color(0xFF242424), // dark-4
      onSurface: Color(0xFFF6F5F4), // light-1
      surfaceContainerHighest: Color(0xFF2E3436), // dark-1
      onSurfaceVariant: Color(0xFF9CA0A0), // medium-1
      outline: Color(0xFF5E5C64), // dark-2
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF2E3436), // dark-1
      foregroundColor: Color(0xFFF6F5F4), // light-1
    ),
  );

  // Monokai Themes
  static final ThemeData _monokaiLightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF66D9EF), // cyan
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFA6E22E), // green
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFAE81FF), // purple
      onTertiary: Color(0xFF000000),
      error: Color(0xFFF92672), // pink
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF8F8F2), // background
      onSurface: Color(0xFF272822), // foreground
      surfaceContainerHighest: Color(0xFFE6E6E1), // selection
      onSurfaceVariant: Color(0xFF75715E), // comment
      outline: Color(0xFFA6E22E), // green
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFFE6E6E1), // selection
      foregroundColor: Color(0xFF272822), // foreground
    ),
  );

  static final ThemeData _monokaiDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF66D9EF), // cyan
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFA6E22E), // green
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFAE81FF), // purple
      onTertiary: Color(0xFF000000),
      error: Color(0xFFF92672), // pink
      onError: Color(0xFF000000),
      surface: Color(0xFF272822), // background
      onSurface: Color(0xFFF8F8F2), // foreground
      surfaceContainerHighest: Color(0xFF3E3D32), // selection
      onSurfaceVariant: Color(0xFF75715E), // comment
      outline: Color(0xFFA6E22E), // green
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF3E3D32), // selection
      foregroundColor: Color(0xFFF8F8F2), // foreground
    ),
  );

  // Everforest Themes
  static final ThemeData _everforestLightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7FBBB3), // blue
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFFA7C080), // green
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFD699B6), // pink
      onTertiary: Color(0xFF000000),
      error: Color(0xFFF85552), // red
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFFDF6E3), // bg0
      onSurface: Color(0xFF5C6A72), // fg
      surfaceContainerHighest: Color(0xFFF4F0D9), // bg1
      onSurfaceVariant: Color(0xFF8292A2), // fg2
      outline: Color(0xFF93A7A7), // gray
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFFF4F0D9), // bg1
      foregroundColor: Color(0xFF5C6A72), // fg
    ),
  );

  static final ThemeData _everforestDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF7FBBB3), // blue
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFA7C080), // green
      onSecondary: Color(0xFF000000),
      tertiary: Color(0xFFD699B6), // pink
      onTertiary: Color(0xFF000000),
      error: Color(0xFFF85552), // red
      onError: Color(0xFF000000),
      surface: Color(0xFF2D353B), // bg0
      onSurface: Color(0xFFD3C6AA), // fg
      surfaceContainerHighest: Color(0xFF343F44), // bg1
      onSurfaceVariant: Color(0xFF9DA9A0), // fg2
      outline: Color(0xFF7A8478), // gray
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF343F44), // bg1
      foregroundColor: Color(0xFFD3C6AA), // fg
    ),
  );
}
