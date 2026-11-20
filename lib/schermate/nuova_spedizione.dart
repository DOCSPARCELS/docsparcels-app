import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/scelta_nazione.dart';
import 'entrata.dart';
import 'pagamento_carta.dart';
import 'profilo.dart';

/// Nuova spedizione del cliente (nota 367 V2): la stessa richiesta dell'area cliente web.
/// Un passo alla volta: mittente, destinatario, colli, servizio, ritiro, riepilogo e invio.
/// La bozza si salva sul server a ogni passo, quindi si ritrova anche sul sito.
class SchermataNuovaSpedizione extends StatefulWidget {
  const SchermataNuovaSpedizione({super.key});

  @override
  State<SchermataNuovaSpedizione> createState() => _SchermataNuovaSpedizioneState();
}

/// Mittente o destinatario.
class _Sezione {
  final societa = TextEditingController();
  final contatto = TextEditingController();
  final indirizzo = TextEditingController();
  final cap = TextEditingController();
  final citta = TextEditingController();
  final provincia = TextEditingController();
  final telefono = TextEditingController();
  final email = TextEditingController();
  Map<String, dynamic>? nazione;

  /// Codice del contatto della rubrica da cui viene; null se scritta a mano o ritoccata.
  String? codiceRubrica;
  bool salvaInRubrica = false;

  List<TextEditingController> get campi => [societa, contatto, indirizzo, cap, citta, provincia, telefono, email];

  void compila(Map<String, dynamic> c, Map<String, dynamic>? naz) {
    societa.text = '${c['societa'] ?? ''}';
    contatto.text = '${c['contatto'] ?? ''}';
    indirizzo.text = '${c['indirizzo'] ?? ''}';
    cap.text = '${c['cap'] ?? ''}';
    citta.text = '${c['citta'] ?? ''}';
    provincia.text = '${c['provincia'] ?? ''}';
    telefono.text = '${c['telefono'] ?? ''}';
    email.text = '${c['email'] ?? ''}'.toLowerCase();
    nazione = naz;
  }

  bool get italia => '${nazione?['codice'] ?? ''}'.toUpperCase() == 'IT';

  void dispose() {
    for (final c in campi) {
      c.dispose();
    }
  }
}

class _Collo {
  final peso = TextEditingController();
  final lunghezza = TextEditingController();
  final larghezza = TextEditingController();
  final altezza = TextEditingController();
  int? imballaggio;

  void dispose() {
    for (final c in [peso, lunghezza, larghezza, altezza]) {
      c.dispose();
    }
  }
}

const _passi = 6;
const _serviziPoint = {14, 810, 811, 812, 813, 814};

class _SchermataNuovaSpedizioneState extends State<SchermataNuovaSpedizione> {
  int _passo = 0;
  bool _attesa = true;
  String? _errore;
  Set<String> _mancanti = {};

  Map<String, dynamic> _dati = {};
  List<Map<String, dynamic>> _nazioni = [];
  Set<String> _ue = {};
  List<Map<String, dynamic>>? _rubrica;

  final _mitt = _Sezione();
  final _dest = _Sezione();
  final List<_Collo> _colli = [_Collo()];
  final _descrizione = TextEditingController();
  bool _documenti = false;
  int? _residenziale; // 0 azienda, 1 privato
  String? _dataSpedizione; // AAAA-MM-GG

  List<Map<String, dynamic>>? _servizi;
  Map<String, dynamic>? _servizio;
  Map<String, dynamic>? _puntoMittente;
  Map<String, dynamic>? _puntoDestinazione;

  bool? _ritiro;
  String? _ritiroData;
  final Map<String, String> _orari = {
    'ritiro_ora_mattino_dalle': '09:00',
    'ritiro_ora_mattino_alle': '13:00',
    'ritiro_ora_pomeriggio_dalle': '14:00',
    'ritiro_ora_pomeriggio_alle': '18:00',
    'ritiro_ora_pronti_dalle': '09:00',
  };
  final _puntoRitiro = TextEditingController();
  final _noteRitiro = TextEditingController();

  int? _bozzaId;
  String? _mos;
  Map<String, dynamic>? _prezzo;
  Map<String, dynamic>? _pagamento;
  String? _metodo;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _mitt.dispose();
    _dest.dispose();
    for (final c in _colli) {
      c.dispose();
    }
    for (final c in [_descrizione, _puntoRitiro, _noteRitiro]) {
      c.dispose();
    }
    super.dispose();
  }

  Testi get _t => Testi.di(context);

  // ------------------------------------------------------------------ dati

  Future<void> _carica() async {
    try {
      final risultati = await Future.wait([Api.datiNuovaSpedizione(), Api.nazioni(), Api.nazioniUe()]);
      if (!mounted) return;
      _dati = risultati[0] as Map<String, dynamic>;
      _nazioni = risultati[1] as List<Map<String, dynamic>>;
      _ue = risultati[2] as Set<String>;
      final m = (_dati['mittente'] as Map?)?.cast<String, dynamic>() ?? {};
      _mitt.compila(m, _nazione('${m['codice_nazione'] ?? ''}'));
      _mitt.codiceRubrica = '${_dati['codice_cliente'] ?? ''}';
      _dest.nazione = _nazione('IT');
      _dataSpedizione = '${_dati['prima_data_spedizione'] ?? ''}';
      _colli.first.imballaggio = _imballaggioPredefinito();
      setState(() => _attesa = false);
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
      if (mounted) setState(() => _attesa = false);
    }
  }

  Map<String, dynamic>? _nazione(String codice) =>
      _nazioni.where((n) => '${n['codice']}'.toUpperCase() == codice.toUpperCase()).firstOrNull;

  List<Map<String, dynamic>> get _imballaggi =>
      ((_dati['imballaggi'] as List?) ?? []).cast<Map<String, dynamic>>();

  /// Busta (Envelope) per i documenti, altrimenti il primo imballaggio che non e' una busta
  int? _imballaggioPredefinito() {
    final lista = _imballaggi;
    if (lista.isEmpty) return null;
    if (_documenti) return lista.firstWhere((i) => i['id'] == 1, orElse: () => lista.first)['id'] as int?;
    return lista.firstWhere((i) => i['id'] != 1 && !'${i['nome']}'.toLowerCase().contains('busta'),
        orElse: () => lista.first)['id'] as int?;
  }

  int? _tipologia(String tipo) => ((_dati['tipologie'] as List?) ?? [])
      .cast<Map<String, dynamic>>()
      .where((t) => t['tipo_spedizione'] == tipo)
      .map((t) => t['id'] as int?)
      .firstOrNull;

  Future<void> _gestisciErrore(ErroreApi e) async {
    if (e.codice == 'chiave_non_valida') {
      await Api.esci();
      if (!mounted) return;
      Navigator.of(context)
          .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
      return;
    }
    if (mounted) setState(() => _errore = e.messaggio ?? _t.errore(e.codice));
  }

  static double _numero(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  String _euro(num? v) => SchermataProfiloState.euro(v ?? 0, _t.lingua);

  /// AAAA-MM-GG -> gg.mm.aa
  static String _data(String? iso) {
    if (iso == null || iso.length < 10) return '';
    return '${iso.substring(8, 10)}.${iso.substring(5, 7)}.${iso.substring(2, 4)}';
  }

  bool get _fuoriUe {
    final codice = '${_dest.nazione?['codice'] ?? ''}'.toUpperCase();
    return codice.isNotEmpty && _ue.isNotEmpty && !_ue.contains(codice) && !_documenti;
  }

  Map<String, dynamic> _sezionePerServer(String pre, _Sezione s) => {
        '${pre}_societa': s.societa.text.trim(),
        '${pre}_contatto': s.contatto.text.trim(),
        '${pre}_indirizzo': s.indirizzo.text.trim(),
        '${pre}_cap': s.cap.text.trim(),
        '${pre}_citta': s.citta.text.trim(),
        '${pre}_provincia': s.provincia.text.trim().toUpperCase(),
        '${pre}_nazione': '${s.nazione?['nome'] ?? ''}',
        '${pre}_codice_nazione': '${s.nazione?['codice'] ?? ''}',
        '${pre}_telefono': s.telefono.text.trim(),
        '${pre}_email': s.email.text.trim().toLowerCase(),
        '${pre}_codice_rubrica': s.codiceRubrica ?? '',
      };

  List<Map<String, dynamic>> get _colliPerServer => [
        for (final c in _colli)
          {
            'tipologia': _tipologia(_documenti ? 'DOCS' : 'PKG'),
            'imballaggio': c.imballaggio,
            'peso': _numero(c.peso),
            'lunghezza': _numero(c.lunghezza),
            'larghezza': _numero(c.larghezza),
            'altezza': _numero(c.altezza),
          }
      ];

  Map<String, dynamic> _bozzaPerServer() => {
        'spedizione_id': _bozzaId,
        ..._sezionePerServer('mitt', _mitt),
        ..._sezionePerServer('dest', _dest),
        'colli': _colliPerServer,
        'descrizione_contenuto': _descrizione.text.trim(),
        'residenziale': _residenziale,
        'data_spedizione': _dataSpedizione,
        'servizio_id': _servizio?['id'],
        'agenzia_point_mittente': _puntoMittente == null ? '' : jsonEncode(_puntoMittente),
        'agenzia_point_destinazione': _puntoDestinazione == null ? '' : jsonEncode(_puntoDestinazione),
        'ritiro_scelta': _ritiro == null ? '' : (_ritiro! ? 'si' : 'no'),
        'ritiro_attivo': _ritiro == true,
        if (_ritiro == true) ...{
          'ritiro_data': _ritiroData,
          ..._orari,
          'ritiro_punto': _puntoRitiro.text.trim(),
          'ritiro_istruzioni_note': _noteRitiro.text.trim(),
        },
      };

  /// Salva la bozza sul server (crea alla prima volta). true se riuscito.
  Future<bool> _salvaBozza() async {
    try {
      final r = await Api.salvaBozza(_bozzaPerServer());
      _bozzaId = r['spedizione_id'] as int? ?? _bozzaId;
      _mos = r['mos'] == null ? _mos : '${r['mos']}';
      _prezzo = (r['prezzo'] as Map?)?.cast<String, dynamic>();
      return true;
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
      return false;
    }
  }

  // ------------------------------------------------------------------ controlli

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _snc = RegExp(r'\bs\.?\s*n\.?\s*c\.?(\s|$)', caseSensitive: false);

  Set<String> _controllaSezione(String pre, _Sezione s) {
    final m = <String>{};
    void vuoto(String campo, TextEditingController c) {
      if (c.text.trim().isEmpty) m.add('${pre}_$campo');
    }

    vuoto('societa', s.societa);
    vuoto('contatto', s.contatto);
    vuoto('indirizzo', s.indirizzo);
    vuoto('citta', s.citta);
    vuoto('telefono', s.telefono);
    vuoto('email', s.email);
    if (s.nazione == null) m.add('${pre}_nazione');
    if (s.nazione?['cap_obbligatorio'] != false) vuoto('cap', s.cap);
    if (s.italia) vuoto('provincia', s.provincia);
    if (s.email.text.trim().isNotEmpty && !_email.hasMatch(s.email.text.trim())) m.add('${pre}_email');
    return m;
  }

  bool _mancaCivico(_Sezione s) {
    final testo = s.indirizzo.text.trim();
    return s.italia && testo.isNotEmpty && !RegExp(r'\d').hasMatch(testo) && !_snc.hasMatch(testo);
  }

  /// Controlli del passo corrente; null se si può andare avanti, altrimenti il messaggio.
  String? _controllaPasso() {
    final t = _t;
    switch (_passo) {
      case 0:
      case 1:
        final s = _passo == 0 ? _mitt : _dest;
        _mancanti = _controllaSezione(_passo == 0 ? 'mitt' : 'dest', s);
        if (_mancanti.isNotEmpty) return t.t('errore_campi_mancanti');
        if (_mancaCivico(s)) return t.t('manca_civico');
        return null;
      case 2:
        _mancanti = {
          for (var i = 0; i < _colli.length; i++)
            if (_numero(_colli[i].peso) <= 0) 'peso_$i',
          if (_descrizione.text.trim().isEmpty) 'descrizione',
          if (_residenziale == null) 'residenziale',
        };
        if (_mancanti.isNotEmpty) return t.t('errore_campi_mancanti');
        if (_fuoriUe) return t.t('fuori_ue_dal_sito');
        return null;
      case 3:
        if (_servizio == null) return t.t('scegli_servizio');
        final id = _servizio!['id'] as int?;
        if (id == 14 || id == 810) {
          if (_puntoMittente == null) return t.t('scegli_punto');
        }
        if ({14, 811, 812, 813, 814}.contains(id) && _puntoDestinazione == null) return t.t('scegli_punto');
        return null;
      case 4:
        if (_portaAlPunto) _ritiro = false;
        if (_ritiro == null) return t.t('scegli_ritiro');
        if (_ritiro == true) {
          _mancanti = {
            if (_ritiroData == null) 'ritiro_data',
            if (_puntoRitiro.text.trim().isEmpty) 'ritiro_punto',
          };
          if (_mancanti.isNotEmpty) return t.t('errore_campi_mancanti');
        }
        return null;
    }
    return null;
  }

  Future<void> _avanti() async {
    FocusScope.of(context).unfocus();
    final errore = _controllaPasso();
    setState(() => _errore = errore);
    if (errore != null) return;
    setState(() => _attesa = true);
    // Salvataggio con questo passo: il servizio e il prezzo dipendono dai dati gia' scritti
    final ok = await _salvaBozza();
    if (!mounted) return;
    if (!ok) {
      setState(() => _attesa = false);
      return;
    }
    if (_passo == 0 || _passo == 1) await _salvaInRubricaSeServe(_passo == 0 ? _mitt : _dest);
    if (_passo == 2) {
      _servizio = null;
      _puntoMittente = null;
      _puntoDestinazione = null;
      await _calcola();
    }
    if (_passo == 4) await _caricaPagamento();
    if (!mounted) return;
    setState(() {
      _attesa = false;
      if (_errore == null) {
        _passo++;
        _mancanti = {};
      }
    });
  }

  Future<void> _salvaInRubricaSeServe(_Sezione s) async {
    if (!s.salvaInRubrica || s.codiceRubrica != null) return;
    try {
      await Api.salvaInRubrica({
        'societa': s.societa.text.trim(),
        'contatto': s.contatto.text.trim(),
        'indirizzo': s.indirizzo.text.trim(),
        'citta': s.citta.text.trim(),
        'cap': s.cap.text.trim(),
        'provincia': s.provincia.text.trim().toUpperCase(),
        'nazione': '${s.nazione?['nome'] ?? ''}',
        'codice_nazione': '${s.nazione?['codice'] ?? ''}',
        'telefono': s.telefono.text.trim(),
        'email': s.email.text.trim().toLowerCase(),
      });
      s.salvaInRubrica = false;
      _rubrica = null; // la prossima apertura la ricarica
    } on ErroreApi catch (e) {
      // la spedizione va avanti lo stesso: si avvisa e basta
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.messaggio ?? _t.t('rubrica_non_salvata'))));
      }
    }
  }

  Future<void> _calcola() async {
    try {
      final servizi = await Api.calcola({
        'mitt_codice_nazione': _mitt.nazione?['codice'],
        'dest_codice_nazione': _dest.nazione?['codice'],
        'mitt_citta': _mitt.citta.text.trim(),
        'dest_citta': _dest.citta.text.trim(),
        'mitt_cap': _mitt.cap.text.trim(),
        'dest_cap': _dest.cap.text.trim(),
        'residenziale': _residenziale,
        'colli': _colliPerServer,
      });
      _servizi = servizi;
      if (servizi.isEmpty) _errore = _t.t('errore_nessuna_tariffa');
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
    }
  }

  Future<void> _caricaPagamento() async {
    try {
      _pagamento = await Api.opzioniPagamento(_bozzaId!);
      final p = _pagamento!;
      if (p['prepagato'] == true) {
        _metodo = p['sufficiente'] == true ? 'credito' : null;
      } else if (p['rimessa'] == true) {
        _metodo = null;
      } else {
        _metodo = null;
      }
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
    }
  }

  /// Servizi in cui il cliente porta il pacco al punto di partenza: il ritiro non c'e'
  bool get _portaAlPunto => {14, 810}.contains(_servizio?['id']);

  bool get _servePagamento => _pagamento?['prepagato'] == true || _pagamento?['rimessa'] == true;

  // ------------------------------------------------------------------ invio

  Future<void> _invia() async {
    final t = _t;
    if (_servePagamento && _metodo == null) {
      setState(() => _errore = t.t('scegli_pagamento'));
      return;
    }
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      final r = await Api.inviaSpedizione(_bozzaId!, _servePagamento ? _metodo : null);
      if (!mounted) return;
      final numero = '${r['nuova_id'] ?? _mos ?? ''}';
      final pagamento = (r['pagamento'] as Map?)?.cast<String, dynamic>();
      if (pagamento?['metodo'] == 'carta' && pagamento?['url'] != null) {
        await _pagaConCarta(numero, '${pagamento!['url']}');
        return;
      }
      if (pagamento?['metodo'] == 'bonifico') {
        await _mostraBonifico(numero, pagamento!);
        return;
      }
      await _esito(t.t('spedizione_inviata').replaceAll('{n}', numero), riuscito: true);
    } on ErroreApi catch (e) {
      if (e.corpo?['prezzo_aggiornato'] == true) {
        // il listino e' cambiato: si rilegge il prezzo e si chiede di rivedere il riepilogo
        await _salvaBozza();
      }
      await _gestisciErrore(e);
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  Future<void> _pagaConCarta(String numero, String url) async {
    final t = _t;
    var esito = await SchermataPagamentoCarta.apri(context, url);
    while (esito != EsitoCarta.riuscito) {
      if (!mounted) return;
      // Non pagata: la spedizione resta in attesa di pagamento. Si riprova o si torna alla bozza
      final scelta = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
          title: Text(t.t(esito == EsitoCarta.nonRiuscito ? 'pagamento_non_riuscito' : 'pagamento_non_completato'),
              textAlign: TextAlign.center),
          content: Text(t.t('pagamento_riprova_testo'), textAlign: TextAlign.center),
          actions: [
            Row(children: [
              Expanded(child: _pulsanteBordo(t.t('torna_alla_bozza'), () => Navigator.pop(c, false))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(t.t('riprova')))),
            ]),
          ],
        ),
      );
      if (!mounted) return;
      if (scelta != true) {
        try {
          await Api.annullaPagamento(int.parse(numero));
        } on ErroreApi catch (e) {
          await _gestisciErrore(e);
          return;
        }
        if (!mounted) return;
        await _esito(t.t('pagamento_annullato_bozza'), riuscito: false);
        return;
      }
      esito = await SchermataPagamentoCarta.apri(context, url);
    }
    if (!mounted) return;
    await _esito(t.t('pagamento_riuscito').replaceAll('{n}', numero), riuscito: true);
  }

  Future<void> _mostraBonifico(String numero, Map<String, dynamic> p) async {
    final t = _t;
    final banca = (p['banca'] as Map?)?.cast<String, dynamic>() ?? {};
    final righe = <List<String>>[
      [t.t('banca'), '${banca['nome'] ?? ''}'],
      ['IBAN', '${banca['iban'] ?? ''}'],
      ['BIC', '${banca['bic'] ?? ''}'],
      [t.t('intestato_a'), '${banca['intestato_a'] ?? ''}'],
      [t.t('importo'), _euro(p['importo'] as num?)],
      [t.t('causale'), '${p['causale'] ?? ''}'],
    ];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(t.t('spedizione_inviata').replaceAll('{n}', numero), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t.t('bonifico_testo'), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            for (final r in righe)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r[0], style: const TextStyle(color: Stile.grigio, fontSize: 12)),
                subtitle: Text(r[1], style: const TextStyle(color: Colors.white, fontSize: 14)),
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
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _esito(String testo, {required bool riuscito}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        icon: Icon(riuscito ? Icons.check_circle : Icons.info_outline,
            color: riuscito ? Stile.verde : Stile.grigio, size: 48),
        content: Text(testo, textAlign: TextAlign.center),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(_t.t('ok')))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ rubrica e punti

  Future<void> _scegliDaRubrica(_Sezione s) async {
    final t = _t;
    if (_rubrica == null) {
      setState(() => _attesa = true);
      try {
        _rubrica = await Api.rubrica();
      } on ErroreApi catch (e) {
        await _gestisciErrore(e);
      }
      if (!mounted) return;
      setState(() => _attesa = false);
      if (_rubrica == null) return;
    }
    final scelto = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Stile.sfondo,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (_) => _SceltaRubrica(voci: _rubrica!, testi: t),
    );
    if (scelto == null) return;
    setState(() {
      s.compila({
        'societa': scelto['societa_op'],
        'contatto': scelto['contatto'],
        'indirizzo': scelto['indirizzo_op'],
        'cap': scelto['cap_op'],
        'citta': scelto['citta_op'],
        'provincia': scelto['provincia_op'],
        'telefono': scelto['telefono_op'],
        'email': scelto['email_op'],
      }, _nazione('${scelto['codice_nazione_op'] ?? ''}'));
      s.codiceRubrica = scelto['tipo'] == 'contatto' ? '${scelto['codice'] ?? ''}' : null;
      s.salvaInRubrica = false;
      _mancanti = {};
      _errore = null;
    });
  }

  Future<void> _scegliPunto(String ruolo) async {
    final t = _t;
    setState(() {
      _attesa = true;
      _errore = null;
    });
    List<Map<String, dynamic>> punti = [];
    try {
      punti = await Api.puntiServizio({
        'servizio_id': _servizio!['id'],
        'ruolo': ruolo,
        ..._sezionePerServer('mitt', _mitt),
        ..._sezionePerServer('dest', _dest),
        'colli': _colliPerServer,
        'residenziale': _residenziale,
      });
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
    }
    if (!mounted) return;
    setState(() => _attesa = false);
    if (punti.isEmpty) {
      if (_errore == null) setState(() => _errore = t.t('nessun_punto'));
      return;
    }
    final scelto = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Stile.sfondo,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (_) => _SceltaPunto(
          punti: punti, testi: t, euro: _euro, titolo: t.t(ruolo == 'mittente' ? 'punto_partenza' : 'punto_arrivo')),
    );
    if (scelto == null) return;
    setState(() {
      if (ruolo == 'mittente') {
        _puntoMittente = scelto;
      } else {
        _puntoDestinazione = scelto;
      }
    });
  }

  // ------------------------------------------------------------------ interfaccia

  InputDecoration _decorazione(String etichetta, String campo) => InputDecoration(
        labelText: etichetta,
        isDense: true,
        enabledBorder: _mancanti.contains(campo)
            ? const OutlineInputBorder(borderRadius: Stile.angoli, borderSide: BorderSide(color: Stile.rosso))
            : null,
      );

  Widget _campo(TextEditingController c, String etichetta, String campo,
          {TextInputType? tipo, int? max, _Sezione? sezione, TextCapitalization maiuscole = TextCapitalization.none}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: tipo,
          maxLength: max,
          textCapitalization: maiuscole,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            // dato ritoccato: non e' piu' quello della rubrica
            if (sezione != null && sezione.codiceRubrica != null) setState(() => sezione.codiceRubrica = null);
            if (_mancanti.isNotEmpty || _errore != null) {
              setState(() {
                _mancanti = {};
                _errore = null;
              });
            }
          },
          decoration: _decorazione(etichetta, campo).copyWith(counterText: ''),
        ),
      );

  Widget _pulsanteBordo(String testo, VoidCallback? azione, {IconData? icona}) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Stile.verde,
          side: const BorderSide(color: Stile.verde),
          shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
          minimumSize: const Size.fromHeight(44),
        ),
        icon: icona == null ? const SizedBox.shrink() : Icon(icona, size: 18),
        label: Text(testo),
        onPressed: azione,
      );

  Widget _sezione(String pre, _Sezione s) {
    final t = _t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _pulsanteBordo(t.t('scegli_da_rubrica'), _attesa ? null : () => _scegliDaRubrica(s), icona: Icons.contacts),
      const SizedBox(height: 16),
      _campo(s.societa, t.t('societa'), '${pre}_societa', sezione: s, maiuscole: TextCapitalization.words),
      _campo(s.contatto, t.t('nome'), '${pre}_contatto', sezione: s, maiuscole: TextCapitalization.words),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            final n = await SceltaNazione.apri(context, _nazioni);
            if (n == null) return;
            setState(() {
              s.nazione = n;
              s.codiceRubrica = null;
              _mancanti.remove('${pre}_nazione');
            });
          },
          child: InputDecorator(
            decoration: _decorazione(t.t('nazione'), '${pre}_nazione').copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
            child: Text(s.nazione == null ? '' : '${s.nazione!['nome']} (${s.nazione!['codice']})'),
          ),
        ),
      ),
      _campo(s.indirizzo, t.t('indirizzo'), '${pre}_indirizzo', sezione: s, max: 35, maiuscole: TextCapitalization.words),
      Row(children: [
        SizedBox(width: 100, child: _campo(s.cap, t.t('cap'), '${pre}_cap', sezione: s, max: 9)),
        const SizedBox(width: 8),
        Expanded(child: _campo(s.citta, t.t('citta'), '${pre}_citta', sezione: s, maiuscole: TextCapitalization.words)),
        const SizedBox(width: 8),
        SizedBox(
            width: 88,
            child: _campo(s.provincia, t.t('provincia'), '${pre}_provincia',
                sezione: s, max: s.italia ? 2 : 3, maiuscole: TextCapitalization.characters)),
      ]),
      _campo(s.telefono, t.t('telefono'), '${pre}_telefono', sezione: s, tipo: TextInputType.phone, max: 15),
      _campo(s.email, t.t('email_campo'), '${pre}_email', sezione: s, tipo: TextInputType.emailAddress, max: 50),
      if (s.codiceRubrica == null)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: Stile.verde,
          value: s.salvaInRubrica,
          title: Text(t.t('salva_in_rubrica')),
          onChanged: (v) => setState(() => s.salvaInRubrica = v ?? false),
        ),
    ]);
  }

  Widget _campoNumero(TextEditingController c, String etichetta, String campo, {String? unita}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) {
          if (_mancanti.isNotEmpty) setState(() => _mancanti = {});
        },
        decoration: _decorazione(etichetta, campo).copyWith(suffixText: unita),
      );

  Widget _passoColli() {
    final t = _t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<bool>(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: Stile.verdePulsanti,
          selectedForegroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        ),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: true, label: Text(t.t('documenti'))),
          ButtonSegment(value: false, label: Text(t.t('pacco'))),
        ],
        selected: {_documenti},
        onSelectionChanged: (s) => setState(() {
          _documenti = s.first;
          for (final c in _colli) {
            c.imballaggio = _imballaggioPredefinito();
          }
        }),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < _colli.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
          decoration: BoxDecoration(border: Border.all(color: Stile.grigio), borderRadius: Stile.angoli),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('${t.t('collo')} ${i + 1}', style: const TextStyle(color: Stile.grigio))),
              if (_colli.length > 1)
                IconButton(
                  tooltip: t.t('togli_collo'),
                  icon: const Icon(Icons.close, color: Stile.grigio, size: 20),
                  onPressed: () => setState(() => _colli.removeAt(i).dispose()),
                )
              else
                const SizedBox(height: 40),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(children: [
                if (_imballaggi.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _colli[i].imballaggio,
                    isDense: true,
                    decoration: _decorazione(t.t('imballaggio'), 'imballaggio_$i'),
                    items: [
                      for (final im in _imballaggi)
                        DropdownMenuItem(value: im['id'] as int, child: Text('${im['nome']}')),
                    ],
                    onChanged: (v) => setState(() => _colli[i].imballaggio = v),
                  ),
                  const SizedBox(height: 12),
                ],
                _campoNumero(_colli[i].peso, t.t('peso_kg'), 'peso_$i'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _campoNumero(_colli[i].lunghezza, t.t('lunghezza_cm'), '', unita: 'cm')),
                  const SizedBox(width: 8),
                  Expanded(child: _campoNumero(_colli[i].larghezza, t.t('larghezza_cm'), '', unita: 'cm')),
                  const SizedBox(width: 8),
                  Expanded(child: _campoNumero(_colli[i].altezza, t.t('altezza_cm'), '', unita: 'cm')),
                ]),
              ]),
            ),
          ]),
        ),
      _pulsanteBordo(t.t('aggiungi_collo'), () {
        final nuovo = _Collo()..imballaggio = _colli.last.imballaggio;
        setState(() => _colli.add(nuovo));
      }, icona: Icons.add),
      const SizedBox(height: 16),
      _campo(_descrizione, t.t('descrizione_contenuto'), 'descrizione', max: 15),
      Text(t.t('destinatario_e'),
          style: TextStyle(color: _mancanti.contains('residenziale') ? Stile.rosso : Stile.grigio)),
      Row(children: [
        Expanded(
          child: RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            activeColor: Stile.verde,
            value: 0,
            groupValue: _residenziale,
            title: Text(t.t('azienda')),
            onChanged: (v) => setState(() => _residenziale = v),
          ),
        ),
        Expanded(
          child: RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            activeColor: Stile.verde,
            value: 1,
            groupValue: _residenziale,
            title: Text(t.t('privato')),
            onChanged: (v) => setState(() => _residenziale = v),
          ),
        ),
      ]),
      if (_fuoriUe)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(t.t('fuori_ue_dal_sito'), textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso)),
        ),
    ]);
  }

  Widget _passoServizio() {
    final t = _t;
    final servizi = _servizi ?? [];
    final id = _servizio?['id'] as int?;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final s in servizi)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: s['id'] == id ? Stile.verde : Stile.grigio, width: 4)),
            color: s['id'] == id ? Stile.verde.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
            borderRadius: Stile.angoli,
          ),
          child: ListTile(
            title: Text('${s['nome'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: s['iva_inclusa'] == true ? Text(t.t('iva_inclusa'), style: const TextStyle(fontSize: 11)) : null,
            trailing: Text(_euro(s['totale'] as num?),
                style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
            onTap: () => setState(() {
              _servizio = s;
              _puntoMittente = null;
              _puntoDestinazione = null;
              _errore = null;
            }),
          ),
        ),
      if (id != null && _serviziPoint.contains(id)) ...[
        const SizedBox(height: 8),
        if (id == 14 || id == 810) _rigaPunto(t.t('punto_partenza'), _puntoMittente, () => _scegliPunto('mittente')),
        if (id != 810) _rigaPunto(t.t('punto_arrivo'), _puntoDestinazione, () => _scegliPunto('destinazione')),
      ],
    ]);
  }

  Widget _rigaPunto(String etichetta, Map<String, dynamic>? punto, VoidCallback scegli) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _pulsanteBordo(
            punto == null ? etichetta : '$etichetta: ${punto['name'] ?? ''}, ${punto['address'] ?? ''}',
            _attesa ? null : scegli,
            icona: Icons.place),
      );

  Future<void> _scegliData(void Function(String) imposta, String? attuale) async {
    final primo = DateTime.tryParse(_dataSpedizione ?? '') ?? DateTime.now();
    final scelto = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(attuale ?? '') ?? primo,
      firstDate: primo,
      lastDate: primo.add(const Duration(days: 60)),
      selectableDayPredicate: (d) => d.weekday <= 5,
    );
    if (scelto == null) return;
    final iso = '${scelto.year}-${scelto.month.toString().padLeft(2, '0')}-${scelto.day.toString().padLeft(2, '0')}';
    setState(() => imposta(iso));
  }

  Future<void> _scegliOra(String chiave) async {
    final parti = (_orari[chiave] ?? '09:00').split(':');
    final scelta = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parti[0]), minute: int.parse(parti[1])),
      builder: (c, figlio) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: figlio!),
    );
    if (scelta == null) return;
    setState(() => _orari[chiave] =
        '${scelta.hour.toString().padLeft(2, '0')}:${scelta.minute.toString().padLeft(2, '0')}');
  }

  Widget _riquadroOra(String etichetta, String chiave) => Expanded(
        child: InkWell(
          onTap: () => _scegliOra(chiave),
          child: InputDecorator(
            decoration: InputDecoration(labelText: etichetta, isDense: true),
            child: Text(_orari[chiave] ?? ''),
          ),
        ),
      );

  Widget _passoRitiro() {
    final t = _t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () => _scegliData((v) {
          _dataSpedizione = v;
          if (_ritiroData != null && _ritiroData!.compareTo(v) < 0) _ritiroData = v;
        }, _dataSpedizione),
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: t.t('data_spedizione'), isDense: true, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          child: Text(_data(_dataSpedizione)),
        ),
      ),
      const SizedBox(height: 16),
      if (_portaAlPunto)
        Text('${t.t('porta_al_punto')} ${_puntoMittente?['name'] ?? ''}, ${_puntoMittente?['address'] ?? ''}',
            style: const TextStyle(fontSize: 14)),
      if (!_portaAlPunto) ...[
      Text(t.t('vuoi_ritiro'), style: const TextStyle(color: Stile.grigio)),
      Row(children: [
        Expanded(
          child: RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            activeColor: Stile.verde,
            value: true,
            groupValue: _ritiro,
            title: Text(t.t('si')),
            onChanged: (v) => setState(() {
              _ritiro = v;
              _ritiroData ??= _dataSpedizione;
            }),
          ),
        ),
        Expanded(
          child: RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            activeColor: Stile.verde,
            value: false,
            groupValue: _ritiro,
            title: Text(t.t('no')),
            onChanged: (v) => setState(() => _ritiro = v),
          ),
        ),
      ]),
      if (_ritiro == false)
        Text(t.t('senza_ritiro_testo'), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
      if (_ritiro == true) ...[
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _scegliData((v) => _ritiroData = v, _ritiroData),
          child: InputDecorator(
            decoration: _decorazione(t.t('giorno_ritiro'), 'ritiro_data')
                .copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
            child: Text(_data(_ritiroData)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _riquadroOra(t.t('mattino_dalle'), 'ritiro_ora_mattino_dalle'),
          const SizedBox(width: 8),
          _riquadroOra(t.t('alle'), 'ritiro_ora_mattino_alle'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _riquadroOra(t.t('pomeriggio_dalle'), 'ritiro_ora_pomeriggio_dalle'),
          const SizedBox(width: 8),
          _riquadroOra(t.t('alle'), 'ritiro_ora_pomeriggio_alle'),
        ]),
        const SizedBox(height: 12),
        Row(children: [_riquadroOra(t.t('pronti_dalle'), 'ritiro_ora_pronti_dalle'), const Spacer()]),
        const SizedBox(height: 12),
        _campo(_puntoRitiro, t.t('punto_ritiro'), 'ritiro_punto', max: 25),
        _campo(_noteRitiro, t.t('note_ritiro'), 'ritiro_note'),
      ],
      ],
    ]);
  }

  Widget _riga(String etichetta, String valore, {bool forte = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(etichetta, style: const TextStyle(color: Stile.grigio, fontSize: 13))),
          Expanded(
              child: Text(valore,
                  style: TextStyle(
                      fontSize: forte ? 16 : 13,
                      fontWeight: forte ? FontWeight.w600 : FontWeight.normal,
                      color: forte ? Stile.verde : null))),
        ]),
      );

  String _indirizzoBreve(_Sezione s) =>
      '${s.societa.text.trim()}\n${s.indirizzo.text.trim()}, ${s.cap.text.trim()} ${s.citta.text.trim()} (${s.nazione?['codice'] ?? ''})';

  Widget _passoRiepilogo() {
    final t = _t;
    final p = _pagamento ?? {};
    final totale = (_prezzo?['totale'] as num?) ?? (_servizio?['totale'] as num?);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_mos != null) _riga('MOS', _mos!),
      _riga(t.t('mittente'), _indirizzoBreve(_mitt)),
      _riga(t.t('destinatario'), _indirizzoBreve(_dest)),
      _riga(t.t('colli_titolo'),
          '${_colli.length} · ${_colli.fold<double>(0, (a, c) => a + _numero(c.peso)).toStringAsFixed(1).replaceAll('.', ',')} kg'),
      _riga(t.t('servizio'), '${_servizio?['nome'] ?? ''}'),
      if (_puntoMittente != null) _riga(t.t('punto_partenza'), '${_puntoMittente!['name'] ?? ''}'),
      if (_puntoDestinazione != null) _riga(t.t('punto_arrivo'), '${_puntoDestinazione!['name'] ?? ''}'),
      _riga(t.t('data_spedizione'), _data(_dataSpedizione)),
      if (!_portaAlPunto)
        _riga(t.t('ritiro'), _ritiro == true ? '${_data(_ritiroData)} · ${_puntoRitiro.text.trim()}' : t.t('no')),
      const Divider(height: 24),
      _riga(t.t('totale'), _euro(totale), forte: true),
      if (_servePagamento) ...[
        const SizedBox(height: 16),
        Text(t.t('come_paghi'), style: const TextStyle(color: Stile.grigio)),
        if (p['prepagato'] == true)
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            activeColor: Stile.verde,
            value: 'credito',
            groupValue: _metodo,
            title: Text(t.t('paga_credito')),
            subtitle: Text('${t.t('credito_residuo')} ${_euro(p['residuo'] as num?)}',
                style: TextStyle(color: p['sufficiente'] == true ? Stile.verde : Stile.rosso, fontSize: 12)),
            onChanged: p['sufficiente'] == true ? (v) => setState(() => _metodo = v) : null,
          ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          activeColor: Stile.verde,
          value: 'carta',
          groupValue: _metodo,
          title: Text(t.t('paga_carta')),
          onChanged: (v) => setState(() => _metodo = v),
        ),
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          activeColor: Stile.verde,
          value: 'bonifico',
          groupValue: _metodo,
          title: Text(t.t('paga_bonifico')),
          onChanged: (v) => setState(() => _metodo = v),
        ),
      ],
    ]);
  }

  String _titoloPasso(int passo) {
    final t = _t;
    return [
      t.t('mittente'),
      t.t('destinatario'),
      t.t('colli_titolo'),
      t.t('servizio'),
      t.t('ritiro'),
      t.t('riepilogo'),
    ][passo];
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final ultimo = _passo == _passi - 1;
    Widget contenuto;
    switch (_passo) {
      case 0:
        contenuto = _sezione('mitt', _mitt);
      case 1:
        contenuto = _sezione('dest', _dest);
      case 2:
        contenuto = _passoColli();
      case 3:
        contenuto = _passoServizio();
      case 4:
        contenuto = _passoRitiro();
      default:
        contenuto = _passoRiepilogo();
    }
    return PopScope(
      canPop: _passo == 0,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto && _passo > 0 && !_attesa) {
          setState(() {
            _passo--;
            _errore = null;
            _mancanti = {};
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.t('nuova_spedizione'))),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            child: _dati.isEmpty && _attesa
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    LinearProgressIndicator(
                        value: (_passo + 1) / _passi, color: Stile.verde, backgroundColor: Colors.white12),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          Text('${_passo + 1}/$_passi · ${_titoloPasso(_passo)}',
                              style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 16),
                          contenuto,
                          if (_errore != null) ...[
                            const SizedBox(height: 16),
                            Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso)),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(children: [
                        if (_passo > 0) ...[
                          Expanded(
                            child: _pulsanteBordo(t.t('indietro'), _attesa
                                ? null
                                : () => setState(() {
                                      _passo--;
                                      _errore = null;
                                      _mancanti = {};
                                    })),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _attesa ? null : (ultimo ? _invia : _avanti),
                            child: _attesa
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(t.t(ultimo ? 'invia_richiesta' : 'avanti')),
                          ),
                        ),
                      ]),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Rubrica del cliente con ricerca (contatti e indirizzi gia' usati).
class _SceltaRubrica extends StatefulWidget {
  const _SceltaRubrica({required this.voci, required this.testi});

  final List<Map<String, dynamic>> voci;
  final Testi testi;

  @override
  State<_SceltaRubrica> createState() => _SceltaRubricaState();
}

class _SceltaRubricaState extends State<_SceltaRubrica> {
  String _cerca = '';

  @override
  Widget build(BuildContext context) {
    final q = _cerca.toLowerCase();
    final elenco = widget.voci
        .where((v) =>
            q.isEmpty ||
            [v['societa_op'], v['contatto'], v['citta_op'], v['indirizzo_op']]
                .any((x) => '${x ?? ''}'.toLowerCase().contains(q)))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                  labelText: widget.testi.t('cerca_rubrica'), prefixIcon: const Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _cerca = v.trim()),
            ),
          ),
          Expanded(
            child: elenco.isEmpty
                ? Center(child: Text(widget.testi.t('rubrica_vuota'), style: const TextStyle(color: Stile.grigio)))
                : ListView.builder(
                    itemCount: elenco.length,
                    itemBuilder: (_, i) {
                      final v = elenco[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(v['tipo'] == 'contatto' ? Icons.person : Icons.history, color: Stile.grigio),
                        title: Text('${v['societa_op'] ?? v['contatto'] ?? ''}'),
                        subtitle: Text(
                            '${v['indirizzo_op'] ?? ''}, ${v['cap_op'] ?? ''} ${v['citta_op'] ?? ''} (${v['codice_nazione_op'] ?? ''})',
                            style: const TextStyle(color: Stile.grigio, fontSize: 12)),
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Punti dei servizi Point, con la differenza di prezzo quando c'e'.
class _SceltaPunto extends StatelessWidget {
  const _SceltaPunto({required this.punti, required this.testi, required this.euro, required this.titolo});

  final String titolo;
  final List<Map<String, dynamic>> punti;
  final Testi testi;
  final String Function(num?) euro;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: ListView.builder(
        itemCount: punti.length + 1,
        itemBuilder: (_, indice) {
          if (indice == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(titolo, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
            );
          }
          final i = indice - 1;
          final p = punti[i];
          final diff = p['differenza'] as num?;
          return ListTile(
            leading: const Icon(Icons.place, color: Stile.verde),
            title: Text('${p['name'] ?? ''}'),
            subtitle: Text('${p['address'] ?? ''}, ${p['zip_code'] ?? ''} ${p['city'] ?? ''}',
                style: const TextStyle(color: Stile.grigio, fontSize: 12)),
            trailing: diff == null ? null : Text('+ ${euro(diff)}', style: const TextStyle(color: Stile.verde)),
            onTap: () => Navigator.pop(context, p),
          );
        },
      ),
    );
  }
}
