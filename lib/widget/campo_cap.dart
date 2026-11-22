import 'package:flutter/material.dart';

import '../stile.dart';
import '../testi.dart';

/// Campo del CAP (nota 373 V18), stesso controllo del gestionale:
/// - la nazione ha il CAP (nazioni.cap_obbligatorio): campo obbligatorio con l'icona info
///   che mostra il formato e un esempio (nazioni.formato_cap / esempio_cap);
/// - la nazione non ha il CAP: il campo non si mostra ([serve] = false).
class CampoCap extends StatelessWidget {
  const CampoCap({
    super.key,
    required this.controller,
    required this.nazione,
    required this.decorazione,
    this.cambiato,
  });

  final TextEditingController controller;
  final Map<String, dynamic>? nazione;
  final InputDecoration decorazione;
  final VoidCallback? cambiato;

  /// Il CAP si chiede? Senza nazione scelta si', come nel gestionale.
  static bool serve(Map<String, dynamic>? nazione) => nazione?['cap_obbligatorio'] != false;

  void _mostraFormato(BuildContext context) {
    final t = Testi.di(context);
    final formati = ((nazione?['formati_cap'] as List?) ?? []).map((f) => '$f').toList();
    final esempio = '${nazione?['esempio_cap'] ?? ''}'.trim();
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text('${t.t('formato_cap')} · ${nazione?['nome'] ?? ''}', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (formati.isEmpty) Text(t.t('formato_cap_assente'), textAlign: TextAlign.center),
          for (final f in formati)
            Text(f, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (esempio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${t.t('esempio')}: $esempio', textAlign: TextAlign.center, style: TextStyle(color: Stile.grigio)),
          ],
        ]),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(t.t('ok')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLength: 10,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          onChanged: (_) => cambiato?.call(),
          decoration: decorazione.copyWith(
            counterText: '',
            suffixIcon: IconButton(
              tooltip: Testi.di(context).t('formato_cap'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, size: 18, color: Stile.verde),
              onPressed: () => _mostraFormato(context),
            ),
          ),
        ),
      );
}
