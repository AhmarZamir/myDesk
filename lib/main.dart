import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth/auth_gate.dart';
import 'core/app_semantics.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  }
  runApp(const MyDeskApp());
}

class MyDeskApp extends StatelessWidget {
  const MyDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    const black = Color(0xFF07090D);
    const panel = Color(0xFF0E1219);
    const panel2 = Color(0xFF151B25);
    const blue = Color(0xFF2F80FF);
    const blueBright = Color(0xFF58A6FF);
    const text = Color(0xFFF3F7FF);
    const muted = Color(0xFF8E9AAF);
    const border = Color(0xFF222A38);

    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: blue,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF102A52),
      onPrimaryContainer: Color(0xFFD9E9FF),
      secondary: blueBright,
      onSecondary: Color(0xFF03111F),
      secondaryContainer: Color(0xFF12375D),
      onSecondaryContainer: Color(0xFFD6ECFF),
      tertiary: Color(0xFF8AB4F8),
      onTertiary: Color(0xFF07111E),
      tertiaryContainer: Color(0xFF1D3557),
      onTertiaryContainer: Color(0xFFDCEBFF),
      error: AppSemantics.outgoing,
      onError: Colors.white,
      errorContainer: Color(0xFF4A1720),
      onErrorContainer: Color(0xFFFFD9DE),
      surface: panel,
      onSurface: text,
      surfaceContainerHighest: panel2,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: Color(0xFF1A2230),
      shadow: Colors.black,
      scrim: Color(0xCC000000),
      inverseSurface: Color(0xFFE6ECF5),
      onInverseSurface: Color(0xFF10141B),
      inversePrimary: Color(0xFF0A5FD1),
    );

    final buttonOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) return Colors.white.withValues(alpha: .15);
      if (states.contains(WidgetState.hovered)) return Colors.white.withValues(alpha: .08);
      if (states.contains(WidgetState.focused)) return blueBright.withValues(alpha: .12);
      return null;
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'myDesk',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: black,
        fontFamily: 'sans-serif',
        hoverColor: blueBright.withValues(alpha: .07),
        focusColor: blueBright.withValues(alpha: .11),
        highlightColor: blueBright.withValues(alpha: .06),
        splashColor: blueBright.withValues(alpha: .10),
        textTheme: ThemeData.dark().textTheme.apply(bodyColor: text, displayColor: text),
        appBarTheme: const AppBarTheme(
          backgroundColor: black,
          foregroundColor: text,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: panel,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
            side: BorderSide(color: border, width: 0.8),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF090C12),
          indicatorColor: Color(0xFF173A68),
          selectedIconTheme: IconThemeData(color: blueBright),
          selectedLabelTextStyle: TextStyle(color: blueBright, fontWeight: FontWeight.w800),
          unselectedIconTheme: IconThemeData(color: muted),
          unselectedLabelTextStyle: TextStyle(color: muted),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0A0E14),
          indicatorColor: Color(0xFF173A68),
          surfaceTintColor: Colors.transparent,
          elevation: 12,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: panel2,
          labelStyle: TextStyle(color: muted),
          hintStyle: TextStyle(color: Color(0xFF657186)),
          prefixIconColor: muted,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: blue, width: 1.7),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: AppSemantics.outgoing),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: AppSemantics.outgoing, width: 1.7),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ).copyWith(overlayColor: buttonOverlay),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: blueBright,
            side: const BorderSide(color: Color(0xFF315C8E)),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ).copyWith(overlayColor: buttonOverlay),
        ),
        textButtonTheme: TextButtonThemeData(style: ButtonStyle(overlayColor: buttonOverlay)),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            overlayColor: buttonOverlay,
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: blue, foregroundColor: Colors.white),
        chipTheme: ChipThemeData(
          backgroundColor: panel2,
          selectedColor: const Color(0xFF173A68),
          labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w600),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 0.8),
        dialogTheme: const DialogThemeData(
          backgroundColor: panel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF172131),
          contentTextStyle: TextStyle(color: text),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: SupabaseConfig.isConfigured ? const AuthGate() : const _ConfigurationScreen(),
    );
  }
}

class _ConfigurationScreen extends StatelessWidget {
  const _ConfigurationScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1473E6), Color(0xFF58A6FF)]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  const Text('myDesk setup required', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('The app is ready for Supabase, but credentials are intentionally not committed to GitHub.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                    child: const SelectableText('flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY', style: TextStyle(fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 16),
                  const Text('Run the SQL migrations in supabase/migrations before signing up.', textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
