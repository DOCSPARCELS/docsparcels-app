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
/// Si mostra subito con i dati dell'elenco; colli, note e stato aggiornato arrivano da
/// GET /cliente/api/ritiri/<id> (nota 373 V30), che vale anche per i ritiri senza spedizione.
/// Le note le ripulisce il server dalle righe interne: qui si mostrano come arrivano.
class SchermataSchedaRitiro extends StatefulWidget {
  const SchermataSchedaRitiro({super.key, required this.ritiro});

  final Map<String, dynamic> ritiro;

  @override
  State<SchermataSchedaRitiro> createState() => _SchermataSchedaRitiroState();
}

class _SchermataSchedaRitiroState extends State<SchermataSchedaRitiro> {
  late Map<String, dynamic> _dati = widget.ritiro;
  List<Map> _colli = [];
  String _note = '';
  bool _attesa = false;

  @override
  void initState() {
    super.initState();
    final id = widget.ritiro['id'];
    if (id is int) {
      _attesa = true;
      _carica(id);
    }
  }

  Future<void> _carica(int id) async {
    try {
      final r = await Api.ritiro(id);
      if (!mounted) return;
      setState(() {
        _dati = {...widget.ritiro, ...r};
        _note = _testo(r['note']);
        _colli = ((r['colli'] as List?) ?? []).whereType<Map>().toList();
      });
    } on ErroreApi catch (e) {
      // se il server non risponde la scheda resta con i dati dell'elenco
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
    final r = _dati;
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
