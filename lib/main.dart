import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'servizi/biometria.dart';
import 'servizi/chiave.dart';
import 'schermate/entrata.dart';
import 'schermate/profilo.dart';
import 'schermate/sblocco.dart';
import 'stile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Configurazione da google-services.json (Android) / GoogleService-Info.plist (iPhone)
    await Firebase.initializeApp();
  } catch (_) {
    // senza Firebase l'app funziona lo stesso, solo senza notifiche
  }
  // Con una chiave gia' salvata si apre il profilo (o prima lo sblocco con Face ID /
  // impronta, se scelto); se la chiave non vale piu', il profilo riporta all'entrata.
  // Toccando una notifica l'app si apre qui: per ora sul profilo.
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
    return MaterialApp(
      title: "Doc's & Parcels",
      debugShowCheckedModeBanner: false,
      theme: Stile.tema(),
      supportedLocales: const [Locale('it'), Locale('en'), Locale('es'), Locale('fr'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: conSblocco
          ? const SchermataSblocco()
          : conChiave
              ? const SchermataProfilo()
              : const SchermataEntrata(),
    );
  }
}
