import 'package:flutter/material.dart';

import '../servizi/tema.dart';
import '../stile.dart';
import '../testi.dart';

/// Scelta del tema: Chiaro, Scuro, Automatico, tre voci della stessa larghezza (nota 373 V6).
/// Nota 373 V11: senza riquadro, solo icona ed etichetta (sole, luna, cerchio meta' e meta');
/// la scelta attiva e' in grassetto e a colore pieno, le altre in grigio.
/// La stessa in «Il mio profilo» → «Aspetto» e nella schermata di accesso.
class SceltaTema extends StatelessWidget {
  const SceltaTema({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final c = context.colori;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaApp.scelta,
      builder: (_, modo, __) => Row(children: [
        for (final (valore, icona, testo) in [
          (ThemeMode.light, Icons.light_mode_outlined, t.t('tema_chiaro')),
          (ThemeMode.dark, Icons.dark_mode_outlined, t.t('tema_scuro')),
          (ThemeMode.system, Icons.contrast, t.t('tema_automatico')),
        ])
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: modo == valore ? c.testo : Stile.grigio,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => TemaApp.imposta(valore),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(icona, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(testo,
                        maxLines: 1,
                        style: TextStyle(fontWeight: modo == valore ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
