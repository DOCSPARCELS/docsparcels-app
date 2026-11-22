import 'package:flutter/material.dart';

import '../stile.dart';

/// Striscia col colore del servizio (nota 373 V17): colore pieno a sinistra che sfuma verso destra.
/// La stessa nel preventivo, nell'elenco delle spedizioni e nel dettaglio.
class StrisciaServizio extends StatelessWidget {
  const StrisciaServizio({super.key, required this.colore, this.larghezza = 24, this.altezza});

  final Color colore;
  final double larghezza;

  /// null = alta quanto lo spazio che ha (es. il bordo sinistro di una card)
  final double? altezza;

  /// '#RRGGBB' -> colore; verde se manca o non e' valido
  static Color daTesto(dynamic esadecimale) {
    final testo = '${esadecimale ?? ''}'.replaceAll('#', '').trim();
    final valore = int.tryParse(testo, radix: 16);
    if (testo.length != 6 || valore == null) return Stile.verde;
    return Color(0xFF000000 | valore);
  }

  @override
  Widget build(BuildContext context) => Container(
        width: larghezza,
        height: altezza,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [colore, colore.withValues(alpha: 0)]),
        ),
      );
}
