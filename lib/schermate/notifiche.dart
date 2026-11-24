import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../servizi/api.dart';
import '../servizi/notifiche.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import 'dettaglio_spedizione.dart';

/// Nota 392 V2: le notifiche del cliente, le stesse della campanella del sito.
/// Pallino verde sulle nuove; toccandone una diventa letta e, se e' di una spedizione, la apre.
class SchermataNotifiche extends StatefulWidget {
  const SchermataNotifiche({super.key});

  @override
  State<SchermataNotifiche> createState() => _SchermataNotificheState();
}

class _SchermataNotificheState extends State<SchermataNotifiche> {
  List<Map<String, dynamic>> _righe = [];
  bool _attesa = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _attesa = _righe.isEmpty;
      _errore = null;
    });
    try {
      final r = await Api.notifiche();
      Notifiche.mostraNumero((r['non_lette_recenti'] as num?)?.toInt() ?? 0);
      if (!mounted) return;
      setState(() => _righe = ((r['notifiche'] as List?) ?? []).cast<Map<String, dynamic>>());
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  bool _letta(Map<String, dynamic> n) => n['letta'] == true || n['letta'] == 1;

  Future<void> _tutteLette() async {
    await Notifiche.segnaLette();
    await _carica();
  }

  Future<void> _apri(Map<String, dynamic> n) async {
    final id = (n['id'] as num?)?.toInt();
    if (!_letta(n) && id != null) {
      setState(() => n['letta'] = 1);
      await Notifiche.segnaLette(id: id);
    }
    final spedizione = (n['spedizione_id'] as num?)?.toInt();
    if (spedizione != null && '${n['url'] ?? ''}'.startsWith('/cliente/spedizione/') && mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SchermataDettaglioSpedizione(id: spedizione)));
    }
    if (mounted) _carica();
  }

  /// Il gestionale manda «24.11.2026 - 15:40»: qui «24.11.26 · 15:40»
  static String _data(String testo) {
    final m = RegExp(r'^(\d{2})\.(\d{2})\.\d{2}(\d{2}) - (\d{2}:\d{2})').firstMatch(testo);
    return m == null ? testo : '${m[1]}.${m[2]}.${m[3]} · ${m[4]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final nuove = _righe.where((n) => !_letta(n)).length;
    return Scaffold(
      appBar: barraApp(context, titolo: t.t('notifiche')),
      body: SafeArea(
        child: _attesa
            ? const Center(child: CircularProgressIndicator())
            : _errore != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_errore!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _carica, child: Text(t.t('riprova'))),
                      ]),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carica,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        if (nuove > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Stile.verdePulsanti,
                                foregroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
                              ),
                              onPressed: _tutteLette,
                              icon: const Icon(Symbols.done_all, size: 20),
                              label: Text(t.t('segna_tutte_lette')),
                            ),
                          ),
                        if (nuove > 0) const SizedBox(height: 8),
                        if (_righe.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 60),
                            child: Center(
                                child: Text(t.t('nessuna_notifica'),
                                    style: TextStyle(color: context.colori.grigioLeggero))),
                          ),
                        for (final n in _righe) _riga(n),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _riga(Map<String, dynamic> n) {
    final letta = _letta(n);
    final messaggio = '${n['messaggio'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colori.card,
        borderRadius: Stile.angoli,
        child: InkWell(
          borderRadius: Stile.angoli,
          onTap: () => _apri(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // pallino verde sulle nuove
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 10),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: letta ? Colors.transparent : Stile.verde),
                ),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${n['titolo'] ?? ''}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: letta ? FontWeight.w400 : FontWeight.w600,
                          color: context.colori.testo)),
                  if (messaggio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(messaggio, style: TextStyle(fontSize: 13, color: context.colori.grigioLeggero)),
                  ],
                  const SizedBox(height: 4),
                  Text(_data('${n['data_creazione'] ?? ''}'),
                      style: TextStyle(fontSize: 12, color: context.colori.grigioLeggero)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
