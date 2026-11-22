import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import 'entrata.dart';

String _testo(dynamic v) => v == null ? '' : '$v'.trim();

/// Stato del ritiro: lo traduce l'app (5 lingue); quello del tracciamento arriva gia' scritto.
String testoStatoRitiro(Testi t, Map<String, dynamic> r) {
  final chiave = _testo(r['stato_chiave']);
  return chiave.isEmpty ? Api.frase(_testo(r['stato'])) : t.t(chiave);
}

Color coloreStatoRitiro(BuildContext context, Map<String, dynamic> r) {
  final valore = int.tryParse(_testo(r['colore']).replaceAll('#', ''), radix: 16);
  final colore = valore == null ? Stile.grigio : Color(0xFF000000 | valore);
  return context.temaScuro ? colore : (Color.lerp(colore, Colors.black, 0.35) ?? colore);
}

String indirizzoRitiro(Map<String, dynamic> r) => [
      Api.nomeProprio(_testo(r['indirizzo'])),
      Api.rigaLuogo(r['cap'], r['citta'], r['provincia']),
    ].where((v) => v.isNotEmpty).join('\n');

/// Scheda di un ritiro (nota 373 V29), aperta dall'elenco «Ritiri».
/// Giorno, corriere, indirizzo, stato e prenotazione arrivano dall'elenco. Colli e note il server
/// li da' solo con la spedizione, e solo per il suo ritiro piu' recente ([ultimoDellaSpedizione]).
class SchermataSchedaRitiro extends StatefulWidget {
  const SchermataSchedaRitiro({super.key, required this.ritiro, required this.ultimoDellaSpedizione});

  final Map<String, dynamic> ritiro;
  final bool ultimoDellaSpedizione;

  /// Le righe fra parentesi quadre sono annotazioni interne (es. «[Email …]»): mai al cliente,
  /// come nella scheda ritiro del sito.
  static String noteCliente(dynamic note) => _testo(note)
      .split('\n')
      .map((r) => r.trim())
      .where((r) => r.isNotEmpty && !r.startsWith('['))
      .join(' · ');

  @override
  State<SchermataSchedaRitiro> createState() => _SchermataSchedaRitiroState();
}

class _SchermataSchedaRitiroState extends State<SchermataSchedaRitiro> {
  List<Map> _colli = [];
  String _note = '';
  bool _attesa = false;

  @override
  void initState() {
    super.initState();
    final id = widget.ritiro['spedizione_id'];
    if (id is int && id > 0 && widget.ultimoDellaSpedizione) {
      _attesa = true;
      _caricaDallaSpedizione(id);
    }
  }

  Future<void> _caricaDallaSpedizione(int id) async {
    try {
      final s = await Api.spedizione(id);
      final r = s['ritiro'];
      if (!mounted || r is! Map) return;
      // un altro giorno = non e' questo ritiro
      if (Api.dataBreve(_testo(r['data_ritiro'])) != _testo(widget.ritiro['giorno'])) return;
      setState(() {
        _note = SchermataSchedaRitiro.noteCliente(r['note']);
        _colli = ((s['colli'] as List?) ?? []).whereType<Map>().toList();
      });
    } on ErroreApi catch (e) {
      // se la spedizione non si puo' leggere la scheda resta con i dati dell'elenco
      if (e.codice != 'chiave_non_valida') return;
      await Api.esci();
      if (!mounted) return;
      Navigator.of(context)
          .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  static String _collo(Map c, String lingua) {
    String numero(num v) {
      final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
      return lingua == 'en' ? s : s.replaceAll('.', ',');
    }

    num valore(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
    final peso = valore(c['peso']);
    final misure = [c['lunghezza'], c['larghezza'], c['altezza']].map(valore).toList();
    return [
      if (peso > 0) '${numero(peso)} kg',
      if (misure.every((m) => m > 0)) '${misure.map(numero).join(' × ')} cm',
    ].join(' · ');
  }

  Widget _riga(String etichetta, String valore, {Color? colore}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(etichetta, style: TextStyle(color: Stile.grigio, fontSize: 13))),
          Expanded(
            child: Text(valore.isEmpty ? '-' : valore,
                style: TextStyle(fontSize: 13, color: colore, fontWeight: colore == null ? null : FontWeight.w600)),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final r = widget.ritiro;
    final prenotazione = _testo(r['prenotazione']);
    return Scaffold(
      appBar: barraApp(context, titolo: t.t('ritiro')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _riga(t.t('stato'), testoStatoRitiro(t, r), colore: coloreStatoRitiro(context, r)),
          _riga(t.t('giorno_ritiro'), _testo(r['giorno'])),
          _riga(t.t('corriere_ritiro'), _testo(r['vettore'])),
          _riga(t.t('indirizzo'), indirizzoRitiro(r)),
          if (prenotazione.isNotEmpty) _riga(t.t('prenotazione_ritiro'), prenotazione),
          for (var i = 0; i < _colli.length; i++) _riga('${t.t('collo')} ${i + 1}', _collo(_colli[i], t.lingua)),
          if (_note.isNotEmpty) _riga(t.t('note_ritiro'), _note),
          if (_attesa) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        ]),
      ),
    );
  }
}
