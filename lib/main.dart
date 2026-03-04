import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/bindings/home_binding.dart';
import 'app/views/home_view.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'Video Downloader Hub',
    debugShowCheckedModeBanner: false,
    initialBinding: HomeBinding(),
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF143A52),
        onPrimary: Colors.white,
        secondary: Color(0xFFB8903D),
        onSecondary: Color(0xFF1F1606),
        surface: Color(0xFFFFFBF4),
        onSurface: Color(0xFF1E2A32),
      ),
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        headlineMedium: GoogleFonts.cormorantGaramond(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleLarge: GoogleFonts.cormorantGaramond(
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.manrope(
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF102D41),
        titleTextStyle: GoogleFonts.cormorantGaramond(
          color: const Color(0xFF102D41),
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD2C2A1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7C8A9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF143A52), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        backgroundColor: Colors.white.withValues(alpha: 0.74),
        side: const BorderSide(color: Color(0xFFD7C8A9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    home: const HomeView(),
  );
}
