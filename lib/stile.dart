import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colori e font del gestionale: pulsanti verde scuro, il resto verde chiaro,
/// Montserrat, angoli a 2 px.
class Stile {
  static const Color verdePulsanti = Color(0xFF1A6B3C);
  static const Color verde = Color(0xFF4CAF50);
  static const Color sfondo = Color(0xFF1E1E1E);
  static const Color grigio = Color(0xFF878787);
  static const Color rosso = Color(0xFFD10001);
  static const BorderRadius angoli = BorderRadius.all(Radius.circular(2));

  static ThemeData tema() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: sfondo,
      colorScheme: base.colorScheme.copyWith(primary: verde, secondary: verde),
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: angoli),
        focusedBorder: OutlineInputBorder(borderRadius: angoli, borderSide: BorderSide(color: verde)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: verde,
          side: const BorderSide(color: verde),
          shape: const RoundedRectangleBorder(borderRadius: angoli),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: verdePulsanti,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: angoli),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
