import 'package:flutter/material.dart';

/// Colori del gestionale: pulsanti verde scuro, il resto verde chiaro, angoli a 2 px.
/// Carattere Raleway, dentro l'app (nota 373 V2): il sito resta con Montserrat.
/// Raleway di suo scrive i numeri «all'antica» (altezze diverse): per prezzi, MOS e date
/// si usano le cifre allineate (lnum) e di larghezza uguale (tnum).
/// Due temi, chiaro e scuro (nota 373 V3): i colori che cambiano col tema si leggono
/// con context.colori, mai fissi nelle schermate.
class Stile {
  static const Color verdePulsanti = Color(0xFF1A6B3C);
  static const Color verde = Color(0xFF4CAF50);
  /// Testi secondari. Nota 373 V14: nel tema chiaro un grigio scuro ben leggibile sul bianco,
  /// nel tema scuro com'era. [temaScuro] lo aggiorna l'app a ogni cambio di tema (main.dart).
  static bool temaScuro = false;
  static const Color grigioChiaro = Color(0xFF5C5C5C);
  static const Color grigioScuro = Color(0xFF878787);
  static Color get grigio => temaScuro ? grigioScuro : grigioChiaro;
  static const Color rosso = Color(0xFFD10001);

  /// Icone dei PDF (nota 373 V8)
  static const Color rossoLeggero = Color(0xFFE57373);
  static const BorderRadius angoli = BorderRadius.all(Radius.circular(2));

  /// Nota 390: bordo dei pulsanti con contorno (Indietro e simili), piu' tenue del verde pieno
  static Color get bordoVerde => verde.withValues(alpha: 0.5);

  /// Nota 390: sfondo della home nel tema chiaro, un po' piu' scuro del bianco
  static const Color sfondoHomeChiaro = Color(0xFFD9DDE1); // V4: ancora piu' scuro

  /// Fondo del tema scuro (lo usano ancora le pagine sempre scure, come il pagamento myPOS)
  static const Color sfondo = Color(0xFF1E1E1E);

  static ThemeData tema({required bool scuro}) {
    final c = scuro ? Colori.scuro : Colori.chiaro;
    final base = ThemeData(brightness: scuro ? Brightness.dark : Brightness.light, useMaterial3: true, fontFamily: 'Raleway');
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
      textTheme: temaTesti(base.textTheme).apply(bodyColor: c.testo, displayColor: c.testo),
      primaryTextTheme: temaTesti(base.primaryTextTheme),
      scaffoldBackgroundColor: c.fondo,
      colorScheme: base.colorScheme.copyWith(primary: verde, secondary: verde, surface: c.card),
      appBarTheme: AppBarTheme(
        backgroundColor: c.barra,
        foregroundColor: c.testo,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.card, surfaceTintColor: Colors.transparent),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.barra,
        surfaceTintColor: Colors.transparent,
        indicatorColor: verde.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? verde : (scuro ? grigioScuro : grigioChiaro))),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Raleway',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? verde : (scuro ? grigioScuro : grigioChiaro))),
      ),
      dividerColor: c.bordo,
      // Nota 373 V13: campi senza riquadro, con un fondo (scuro ? grigioScuro : grigioChiaro) leggerissimo; il verde solo mentre si scrive.
      // I campi mancanti restano col bordo rosso (lo mettono le schermate).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fondoCampi,
        border: const OutlineInputBorder(borderRadius: angoli, borderSide: BorderSide.none),
        enabledBorder: const OutlineInputBorder(borderRadius: angoli, borderSide: BorderSide.none),
        focusedBorder: const OutlineInputBorder(borderRadius: angoli, borderSide: BorderSide(color: verde)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: verde,
          side: BorderSide(color: bordoVerde), // nota 390: bordo piu' tenue
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
      chipTheme: ChipThemeData(
        selectedColor: verde.withValues(alpha: 0.25),
        shape: const RoundedRectangleBorder(borderRadius: angoli),
      ),
    );
  }
}

/// I colori che cambiano fra tema chiaro e scuro.
class Colori {
  const Colori({
    required this.fondo,
    required this.card,
    required this.bordo,
    required this.bordoCampi,
    required this.barra,
    required this.testo,
    required this.cerchioIcona,
    required this.fondoCampi,
    required this.grigioLeggero,
  });

  final Color fondo;
  final Color card;
  final Color bordo;
  final Color bordoCampi;
  final Color barra;
  final Color testo;

  /// Fondo dei cerchi delle icone nelle card (quello della voce principale e' verdePulsanti)
  final Color cerchioIcona;

  /// Fondo dei campi (nota 373 V13): appena diverso dallo sfondo, al posto del riquadro
  final Color fondoCampi;

  /// Scritte che lasciano risaltare quello che hanno accanto, es. «MOS» (nota 373 V23)
  final Color grigioLeggero;

  static const scuro = Colori(
    fondo: Color(0xFF1E1E1E),
    card: Color(0xFF2A2A2A),
    bordo: Color(0xFF444444),
    bordoCampi: Color(0xFF666666),
    barra: Color(0xFF141418),
    testo: Colors.white,
    cerchioIcona: Color(0xFF23462D),
    fondoCampi: Color(0xFF272727), // nota 373 V23: piu' vicino al nero
    grigioLeggero: Color(0xFF777777),
  );

  static const chiaro = Colori(
    fondo: Color(0xFFF4F5F6),
    card: Colors.white,
    bordo: Color(0xFFDDDDDD),
    bordoCampi: Color(0xFFBBBBBB),
    barra: Colors.white,
    testo: Color(0xFF1E1E1E),
    cerchioIcona: Color(0xFFDCEFE0),
    fondoCampi: Color(0xFFE9EBEE),
    grigioLeggero: Color(0xFFA0A0A0),
  );
}

extension ColoriDelTema on BuildContext {
  bool get temaScuro => Theme.of(this).brightness == Brightness.dark;

  Colori get colori => temaScuro ? Colori.scuro : Colori.chiaro;
}
