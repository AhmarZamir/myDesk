import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_gate.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  runApp(const MyDeskApp());
}

class MyDeskApp extends StatelessWidget {
  const MyDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    const sage = Color(0xFF496A5B);
    const terracotta = Color(0xFFB97858);
    const sand = Color(0xFFE9E1D5);
    const cream = Color(0xFFF7F1E8);
    const ink = Color(0xFF25312C);
    const mutedInk = Color(0xFF68736D);
    const border = Color(0xFFD8CDBE);

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: sage,
      onPrimary: Color(0xFFFFFBF5),
      primaryContainer: Color(0xFFD8E4DB),
      onPrimaryContainer: Color(0xFF203D31),
      secondary: terracotta,
      onSecondary: Color(0xFFFFFBF5),
      secondaryContainer: Color(0xFFF0D9CC),
      onSecondaryContainer: Color(0xFF56301F),
      tertiary: Color(0xFF6C748F),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE1E3EE),
      onTertiaryContainer: Color(0xFF292D42),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: cream,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFE2D9CD),
      onSurfaceVariant: mutedInk,
      outline: border,
      outlineVariant: Color(0xFFE5DBCF),
      shadow: Color(0x33000000),
      scrim: Color(0x66000000),
      inverseSurface: ink,
      onInverseSurface: Color(0xFFF4EEE6),
      inversePrimary: Color(0xFFAFCBB9),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'myDesk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: sand,
        fontFamily: 'sans-serif',
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: ink,
              displayColor: ink,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: sand,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: cream,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          shadowColor: Color(0x1F25312C),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
            side: BorderSide(color: border, width: 0.7),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFFDDD3C5),
          indicatorColor: sage,
          selectedIconTheme: IconThemeData(color: Colors.white),
          selectedLabelTextStyle: TextStyle(color: sage, fontWeight: FontWeight.w700),
          unselectedIconTheme: IconThemeData(color: mutedInk),
          unselectedLabelTextStyle: TextStyle(color: mutedInk),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: cream,
          indicatorColor: Color(0xFFD8E4DB),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFBF7F0),
          labelStyle: TextStyle(color: mutedInk),
          hintStyle: TextStyle(color: Color(0xFF8B948F)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: sage, width: 1.7),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFFB3261E)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFFB3261E), width: 1.7),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: sage,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: sage,
            side: const BorderSide(color: sage),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE8DED2),
          selectedColor: const Color(0xFFD8E4DB),
          labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 0.7),
        dialogTheme: const DialogThemeData(
          backgroundColor: cream,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: ink,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: SupabaseConfig.isConfigured
          ? const AuthGate()
          : const _ConfigurationScreen(),
    );
  }
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text('myDesk setup required', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        'The app is ready for Supabase, but credentials are intentionally not committed to GitHub.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const SelectableText(
                          '''flutter run -d chrome \\
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \\
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY''',
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Run the SQL migrations in supabase/migrations before signing up.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
