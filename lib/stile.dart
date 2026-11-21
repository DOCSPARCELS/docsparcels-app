import 'package:flutter/material.dart';

/// Colori del gestionale: pulsanti verde scuro, il resto verde chiaro, angoli a 2 px.
/// Carattere Raleway, dentro l'app (nota 373 V2): il sito resta con Montserrat.
/// Raleway di suo scrive i numeri «all'antica» (altezze diverse): per prezzi, MOS e date
/// si usano le cifre allineate (lnum) e di larghezza uguale (tnum).
class Stile {
  static const Color verdePulsanti = Color(0xFF1A6B3C);
  static const Color verde = Color(0xFF4CAF50);
  static const Color sfondo = Color(0xFF1E1E1E);
  static const Color grigio = Color(0xFF878787);
  static const Color rosso = Color(0xFFD10001);
  static const BorderRadius angoli = BorderRadius.all(Radius.circular(2));

  static ThemeData tema() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'Raleway');
    const cifre = [FontFeature.liningFigures(), FontFeature.tabularFigures()];
    TextStyle? conCifre(TextStyle? s) => s?.copyWith(fontFeatures: cifre);
    TextTheme temaTesti(TextTheme t) => t.copyWith(
          displayLarge: conCifre(t.displayLarge),
          displayMedium: conCifre(t.displayMedium),
          displaySmall: conCifre(t.displaySmall),
          headlineLarge: conCifre(t.headlineLarge),
          headlineMedium: conCifre(t.headlineMedium),
          headlineSmall: conCifre(t.headlineSmall),
          titleLarge: conCifre(t.titleLarge),
          titleMedium: conCifre(t.titleMedium),
          titleSmall: conCifre(t.titleSmall),
          bodyLarge: conCifre(t.bodyLarge),
          bodyMedium: conCifre(t.bodyMedium),
          bodySmall: conCifre(t.bodySmall),
          labelLarge: conCifre(t.labelLarge),
          labelMedium: conCifre(t.labelMedium),
          labelSmall: conCifre(t.labelSmall),
        );
    return base.copyWith(
      textTheme: temaTesti(base.textTheme),
      primaryTextTheme: temaTesti(base.primaryTextTheme),
      scaffoldBackgroundColor: sfondo,
      colorScheme: base.colorScheme.copyWith(primary: verde, secondary: verde),
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
