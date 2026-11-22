import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import 'entrata.dart';
import 'prenota_ritiro.dart';
import 'scheda_ritiro.dart';

/// Ritiri del cliente (nota 373 V23): gli stessi della pagina «Ritiri» del sito, con giorno,
/// corriere, indirizzo, stato e numero di prenotazione. In fondo il pulsante per un ritiro nuovo.
class SchermataRitiri extends StatefulWidget {
  const SchermataRitiri({super.key});

  @override
  State<SchermataRitiri> createState() => _SchermataRitiriState();
}

class _SchermataRitiriState extends State<SchermataRitiri> {
  final List<Map<String, dynamic>> _righe = [];
  int _pagina = 0;
  int _pagine = 1;
  bool _attesa = false;
  String? _errore;

  /// Ogni rilettura annulla le risposte di quelle prima
  int _giro = 0;

  @override
  void initState() {
    super.initState();
    _ricarica();
  }

  Future<void> _ricarica() async {
    _giro++;
    setState(() {
      _righe.clear();
      _pagina = 0;
      _pagine = 1;
      _attesa = false;
      _errore = null;
    });
    await _altri();
  }

  Future<void> _altri() async {
    if (_attesa || _pagina >= _pagine) return;
    final giro = _giro;
    setState(() => _attesa = true);
    try {
      final r = await Api.ritiri(pagina: _pagina + 1);
      if (!mounted || giro != _giro) return;
      setState(() {
        _righe.addAll(((r['ritiri'] as List?) ?? []).cast<Map<String, dynamic>>());
        _pagina = (r['pagina'] as int?) ?? _pagina + 1;
        _pagine = (r['pagine'] as int?) ?? _pagina;
      });
    } on ErroreApi catch (e) {
      if (!mounted || giro != _giro) return;
      if (e.codice == 'chiave_non_valida') {
        await Api.esci();
        if (!mounted) return;
        Navigator.of(context)
            .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
        return;
      }
      setState(() => _errore = e.messaggio ?? Testi.di(context).errore(e.codice));
    } finally {
      if (mounted && giro == _giro) setState(() => _attesa = false);
    }
  }

  Future<void> _nuovo() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchermataPrenotaRitiro()));
    if (mounted) _ricarica();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return Scaffold(
      appBar: barraApp(context, titolo: t.t('ritiri')),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: _elenco(t)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ElevatedButton(onPressed: _nuovo, child: Text(t.t('prenota_ritiro'))),
          ),
        ]),
      ),
    );
  }

  Widget _elenco(Testi t) {
    if (_errore != null && _righe.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_errore!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _ricarica, child: Text(t.t('riprova'))),
          ]),
        ),
      );
    }
    if (_righe.isEmpty) {
      return Center(
        child: _attesa
            ? const CircularProgressIndicator()
            : Text(t.t('nessun_ritiro'), style: TextStyle(color: Stile.grigio)),
      );
    }
    return RefreshIndicator(
      onRefresh: _ricarica,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _altri();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: _righe.length + (_attesa ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => i < _righe.length
              ? _riga(t, i)
              : const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }

  static String _testo(dynamic v) => v == null ? '' : '$v'.trim();

  /// Nota 373 V29: la scheda
  void _apri(Map<String, dynamic> r) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SchermataSchedaRitiro(ritiro: r)));
  }

  Widget _riga(Testi t, int indice) {
    final r = _righe[indice];
    final c = context.colori;
    final stato = testoStatoRitiro(t, r);
    final luogo = indirizzoRitiro(r);
    final prenotazione = _testo(r['prenotazione']);
    final dati = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text([_testo(r['giorno']), _testo(r['vettore'])].where((v) => v.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.testo)),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.42),
            child: Text(stato,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: coloreStatoRitiro(context, r))),
          ),
        ]),
        if (luogo.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(luogo, style: TextStyle(fontSize: 13, color: Stile.grigio)),
        ],
        if (prenotazione.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${t.t('prenotazione_ritiro')} ', style: TextStyle(color: Stile.grigio)),
              TextSpan(text: prenotazione, style: TextStyle(color: c.testo, fontWeight: FontWeight.w600)),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
        ],
    ]);
    // Nota 373 V29: la freccina come nelle ultime spedizioni della home
    return Material(
      color: c.card,
      borderRadius: Stile.angoli,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _apri(r),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
          child: Row(children: [Expanded(child: dati), Icon(Icons.chevron_right, color: Stile.grigio)]),
        ),
      ),
    );
  }
}
