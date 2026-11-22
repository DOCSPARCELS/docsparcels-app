import 'package:flutter/material.dart';

import '../servizi/tema.dart';
import '../stile.dart';
import '../testi.dart';

/// Scelta del tema (nota 373 V6): Chiaro, Scuro, Automatico, tre pulsanti della stessa larghezza.
/// La stessa in «Il mio profilo» → «Aspetto» e nella schermata di accesso.
class SceltaTema extends StatelessWidget {
  const SceltaTema({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaApp.scelta,
      builder: (_, modo, __) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<ThemeMode>(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: Stile.verdePulsanti,
            selectedForegroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
          ),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: ThemeMode.light, label: Text(t.t('tema_chiaro'))),
            ButtonSegment(value: ThemeMode.dark, label: Text(t.t('tema_scuro'))),
            ButtonSegment(value: ThemeMode.system, label: Text(t.t('tema_automatico'))),
          ],
          selected: {modo},
          onSelectionChanged: (s) => TemaApp.imposta(s.first),
        ),
      ),
    );
  }
}
