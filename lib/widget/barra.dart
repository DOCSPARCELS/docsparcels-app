import 'package:flutter/material.dart';

import '../stile.dart';

/// Logo di Doc's & Parcels (nota 373 V3): nel tema chiaro com'e', nel tema scuro con le scritte
/// grigie in grigio chiaro, direttamente sul fondo (senza riquadro bianco).
class LogoApp extends StatelessWidget {
  const LogoApp({super.key, this.altezza = 38});

  final double altezza;

  @override
  Widget build(BuildContext context) => Image.asset(
        context.temaScuro ? 'assets/immagini/logo_scuro.png' : 'assets/immagini/logo.png',
        height: altezza,
        semanticLabel: "Doc's & Parcels",
      );
}

/// Barra in alto di tutte le schermate: logo sempre centrato, sotto il nome della pagina.
PreferredSizeWidget barraApp(BuildContext context,
    {String? titolo, List<Widget>? azioni, PreferredSizeWidget? sotto, Widget? inizio}) {
  return AppBar(
    toolbarHeight: titolo == null ? 70 : 90,
    centerTitle: true,
    leading: inizio,
    title: Column(mainAxisSize: MainAxisSize.min, children: [
      const LogoApp(),
      if (titolo != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(titolo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colori.testo)),
        ),
    ]),
    actions: azioni,
    bottom: sotto,
  );
}
