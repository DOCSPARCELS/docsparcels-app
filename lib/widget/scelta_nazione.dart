import 'package:flutter/material.dart';

import '../stile.dart';
import '../testi.dart';

/// Elenco delle nazioni con ricerca per nome, alias o codice (Preventivo veloce e Nuova spedizione).
class SceltaNazione extends StatefulWidget {
  const SceltaNazione({super.key, required this.nazioni, required this.testi});

  final List<Map<String, dynamic>> nazioni;
  final Testi testi;

  /// Apre l'elenco dal basso e ritorna la nazione scelta (null se chiuso).
  static Future<Map<String, dynamic>?> apri(BuildContext context, List<Map<String, dynamic>> nazioni) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Stile.sfondo,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (_) => SceltaNazione(nazioni: nazioni, testi: Testi.di(context)),
    );
  }

  @override
  State<SceltaNazione> createState() => _SceltaNazioneState();
}

class _SceltaNazioneState extends State<SceltaNazione> {
  String _cerca = '';

  bool _corrisponde(Map<String, dynamic> n) {
    if (_cerca.isEmpty) return true;
    final q = _cerca.toLowerCase();
    if ('${n['nome']}'.toLowerCase().contains(q) || '${n['codice']}'.toLowerCase() == q) return true;
    return ((n['alias'] as List?) ?? []).any((a) => '$a'.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final elenco = widget.nazioni.where(_corrisponde).toList()
      ..sort((a, b) => '${a['nome']}'.compareTo('${b['nome']}'));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                    labelText: widget.testi.t('cerca_nazione'), prefixIcon: const Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => _cerca = v.trim()),
              ),
            ),
            Expanded(
              child: elenco.isEmpty
                  ? Center(child: Text(widget.testi.t('nessuna_nazione'), style: const TextStyle(color: Stile.grigio)))
                  : ListView.builder(
                      itemCount: elenco.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text('${elenco[i]['nome']}'),
                        trailing: Text('${elenco[i]['codice']}', style: const TextStyle(color: Stile.grigio)),
                        onTap: () => Navigator.pop(context, elenco[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
