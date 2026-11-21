import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'servizi/biometria.dart';
import 'servizi/chiave.dart';
import 'servizi/lingua.dart';
import 'servizi/notifiche.dart';
import 'servizi/tema.dart';
import 'schermate/entrata.dart';
import 'schermate/profilo.dart';
import 'schermate/sblocco.dart';
import 'stile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Configurazione da google-services.json (Android) / GoogleService-Info.plist (iPhone)
    await Firebase.initializeApp();
    // Toccando una notifica di spedizione si apre il suo dettaglio, dopo profilo e sblocco
    await Notifiche.ascoltaTocchi();
  } catch (_) {
    // senza Firebase l'app funziona lo stesso, solo senza notifiche
  }
  // Con una chiave gia' salvata si apre il profilo (o prima lo sblocco con Face ID /
  // impronta, se scelto); se la chiave non vale piu', il profilo riporta all'entrata.
  await LinguaApp.carica();
  await TemaApp.carica();
  final chiave = await ArchivioChiave.leggi();
  final conChiave = chiave != null && chiave.isNotEmpty;
  final conSblocco = conChiave && await Biometria.scelta() == 'si';
  runApp(AppDocsParcels(conChiave: conChiave, conSblocco: conSblocco));
}

class AppDocsParcels extends StatelessWidget {
  const AppDocsParcels({super.key, required this.conChiave, this.conSblocco = false});

  final bool conChiave;
  final bool conSblocco;

  @override
  Widget build(BuildContext context) {
    // Lingua (nota 372) e tema (nota 373 V3) scelti nel profilo cambiano tutta l'app subito;
    // senza scelta valgono quelli del telefono
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaApp.scelta,
      builder: (_, tema, __) => ValueListenableBuilder<Locale?>(
        valueListenable: LinguaApp.scelta,
        builder: (_, lingua, __) => MaterialApp(
          title: "Doc's & Parcels",
          debugShowCheckedModeBanner: false,
          navigatorKey: Notifiche.navigatore,
          theme: Stile.tema(scuro: false),
          darkTheme: Stile.tema(scuro: true),
          themeMode: tema,
          locale: lingua,
          supportedLocales: const [Locale('it'), Locale('en'), Locale('es'), Locale('fr'), Locale('de')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // --dart-define=PROVA_ENTRATA=true: solo per le prove, apre l'accesso senza togliere la chiave
          home: const bool.fromEnvironment('PROVA_ENTRATA')
              ? const SchermataEntrata()
              : conSblocco
                  ? const SchermataSblocco()
                  : conChiave
                      ? const SchermataProfilo()
                      : const SchermataEntrata(),
        ),
      ),
    );
  }
}
