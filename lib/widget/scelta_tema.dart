import 'package:flutter/material.dart';

import '../servizi/tema.dart';
import '../stile.dart';
import '../testi.dart';

/// Scelta del tema: Chiaro, Scuro, Automatico, tre pulsanti della stessa larghezza (nota 373 V6).
/// Nota 373 V10: neutri come nel gestionale, niente verde; icone sole, luna e cerchio meta' e meta'.
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
        for (final (i, (valore, icona, testo)) in [
          (ThemeMode.light, Icons.light_mode_outlined, t.t('tema_chiaro')),
          (ThemeMode.dark, Icons.dark_mode_outlined, t.t('tema_scuro')),
          (ThemeMode.system, Icons.contrast, t.t('tema_automatico')),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.testo,
                backgroundColor: modo == valore ? Stile.grigio.withValues(alpha: 0.22) : Colors.transparent,
                side: BorderSide(color: modo == valore ? Stile.grigio : c.bordoCampi),
                shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => TemaApp.imposta(valore),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(icona, size: 18),
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
        ],
      ]),
    );
  }
}
