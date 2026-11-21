import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../schermate/profilo.dart';
import '../stile.dart';
import '../testi.dart';

/// Dati del bonifico da copiare (banca, IBAN, BIC, intestatario, importo, causale), come li
/// manda il gestionale: {importo, causale, banca: {nome, iban, bic, intestato_a}}.
/// Lo usano Nuova spedizione (nota 367) e Pagamenti e fatture (nota 369).
class RiquadroBonifico {
  static Future<void> mostra(BuildContext context, Map<String, dynamic> p, {required String titolo}) async {
    final t = Testi.di(context);
    final banca = (p['banca'] as Map?)?.cast<String, dynamic>() ?? {};
    final righe = <List<String>>[
      [t.t('banca'), '${banca['nome'] ?? ''}'],
      ['IBAN', '${banca['iban'] ?? ''}'],
      ['BIC', '${banca['bic'] ?? ''}'],
      [t.t('intestato_a'), '${banca['intestato_a'] ?? ''}'],
      [t.t('importo'), SchermataProfiloState.euro((p['importo'] as num?) ?? 0, t.lingua)],
      [t.t('causale'), '${p['causale'] ?? ''}'],
    ];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(titolo, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t.t('bonifico_testo'), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            for (final r in righe)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r[0], style: const TextStyle(color: Stile.grigio, fontSize: 12)),
                subtitle: Text(r[1], style: TextStyle(color: context.colori.testo, fontSize: 14)),
                trailing: IconButton(
                  tooltip: t.t('copia'),
                  icon: const Icon(Icons.copy, size: 18, color: Stile.verde),
                  onPressed: () => Clipboard.setData(ClipboardData(text: r[1].replaceAll(' ', r[0] == 'IBAN' ? '' : ' '))),
                ),
              ),
          ]),
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(t.t('ok')))],
      ),
    );
  }
}
