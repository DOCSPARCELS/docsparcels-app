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

/// Barra in alto.
/// - Home (senza [titolo]): logo al centro.
/// - Tutte le altre (nota 373 V8): titolo della pagina al centro, logo piccolo a destra;
///   toccando il logo si torna sempre alla pagina principale.
PreferredSizeWidget barraApp(BuildContext context,
    {String? titolo, String? prefisso, List<Widget>? azioni, PreferredSizeWidget? sotto, Widget? inizio}) {
  if (titolo == null) {
    return AppBar(
      toolbarHeight: 78,
      centerTitle: true,
      leading: inizio,
      title: const LogoApp(altezza: 48), // nota 373 V23: piu' grande solo nella home
      actions: azioni,
      bottom: sotto,
    );
  }
  return AppBar(
    toolbarHeight: 64,
    centerTitle: true,
    leading: inizio,
    title: Text.rich(
        TextSpan(children: [
          // nota 373 V23: es. «MOS» in grigio leggero, cosi' risalta il numero
          if (prefisso != null) TextSpan(text: '$prefisso ', style: TextStyle(color: context.colori.grigioLeggero)),
          TextSpan(text: titolo),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.colori.testo)),
    actions: [
      ...?azioni,
      Padding(
        padding: const EdgeInsets.only(right: 12, left: 4),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const LogoApp(altezza: 24),
        ),
      ),
    ],
    bottom: sotto,
  );
}
