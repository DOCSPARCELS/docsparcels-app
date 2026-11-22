import 'package:flutter/material.dart';

import '../stile.dart';
import '../testi.dart';

/// Le cinque lingue su una riga, nome piccolo e sotto la bandierina (nota 373 V9-V11).
/// La stessa all'accesso e in «Il mio profilo»; la lingua scelta in grassetto, senza verde.
class SceltaLingua extends StatelessWidget {
  const SceltaLingua({super.key, required this.scegli});

  final ValueChanged<String> scegli;

  static const _bandiere = {'it': '🇮🇹', 'en': '🇬🇧', 'es': '🇪🇸', 'fr': '🇫🇷', 'de': '🇩🇪'};

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return Row(children: [
      for (final l in Testi.lingue)
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: t.lingua == l ? context.colori.testo : Stile.grigio,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => scegli(l),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(t.t('lingua_$l'),
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, fontWeight: t.lingua == l ? FontWeight.w700 : FontWeight.w500)),
              ),
              const SizedBox(height: 4),
              Text(_bandiere[l] ?? '', style: const TextStyle(fontSize: 18)),
            ]),
          ),
        ),
    ]);
  }
}
