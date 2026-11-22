import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import '../widget/campo_cap.dart';
import '../widget/scelta_nazione.dart';
import 'entrata.dart';

/// Prenota ritiro (nota 373 V18): la stessa richiesta della pagina «Nuovo ritiro» del sito
/// (POST /cliente/api/ritiri). Indirizzo dall'anagrafica del cliente, corriere, giorno,
/// orari, punto di ritiro e colli. Il ritiro nasce «Da prenotare» (o si prenota da solo
/// se il cliente ha l'autoritiro, come sul sito).
class SchermataPrenotaRitiro extends StatefulWidget {
  const SchermataPrenotaRitiro({super.key});

  @override
  State<SchermataPrenotaRitiro> createState() => _SchermataPrenotaRitiroState();
}

class _Collo {
  int? tipologia;
  int? imballaggio;
  final peso = TextEditingController();
  final lunghezza = TextEditingController();
  final larghezza = TextEditingController();
  final altezza = TextEditingController();

  List<TextEditingController> get campi => [peso, lunghezza, larghezza, altezza];

  void dispose() {
    for (final c in campi) {
      c.dispose();
    }
  }
}

class _SchermataPrenotaRitiroState extends State<SchermataPrenotaRitiro> {
  bool _attesa = true;
  bool _invio = false;
  String? _errore;
  Set<String> _mancanti = {};

  List<Map<String, dynamic>> _nazioni = [];
  List<Map<String, dynamic>> _tipologie = [];
  List<Map<String, dynamic>> _imballaggi = [];
  List<String> _vettori = [];
  String? _primoGiorno;

  final _societa = TextEditingController();
  final _contatto = TextEditingController();
  final _indirizzo = TextEditingController();
  final _cap = TextEditingController();
  final _citta = TextEditingController();
  final _provincia = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  Map<String, dynamic>? _nazione;

  String? _vettore;
  String? _giorno;
  final Map<String, String> _orari = {
    'ritiro_ora_mattino_dalle': '09:00',
    'ritiro_ora_mattino_alle': '13:00',
    'ritiro_ora_pomeriggio_dalle': '14:00',
    'ritiro_ora_pomeriggio_alle': '18:00',
    'ritiro_ora_pronti_dalle': '09:00',
  };
  final _punto = TextEditingController();
  final _note = TextEditingController();
  final List<_Collo> _colli = [_Collo()];

  Testi get _t => Testi.di(context);

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    for (final c in [_societa, _contatto, _indirizzo, _cap, _citta, _provincia, _telefono, _email, _punto, _note]) {
      c.dispose();
    }
    for (final c in _colli) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final r = await Future.wait([Api.datiNuovaSpedizione(), Api.nazioni()]);
      if (!mounted) return;
      final dati = r[0] as Map<String, dynamic>;
      _nazioni = r[1] as List<Map<String, dynamic>>;
      _tipologie = ((dati['tipologie'] as List?) ?? []).cast<Map<String, dynamic>>();
      _imballaggi = ((dati['imballaggi'] as List?) ?? []).cast<Map<String, dynamic>>();
      _vettori = ((dati['vettori_ritiro'] as List?) ?? []).map((v) => '$v').toList();
      _primoGiorno = '${dati['prima_data_spedizione'] ?? ''}';
      _giorno = _primoGiorno!.isEmpty ? null : _primoGiorno;
      String v(dynamic x) => x == null ? '' : '$x'.trim();
      final m = (dati['mittente'] as Map?)?.cast<String, dynamic>() ?? {};
      _societa.text = v(m['societa']);
      _contatto.text = v(m['contatto']);
      _indirizzo.text = v(m['indirizzo']);
      _cap.text = v(m['cap']);
      _citta.text = v(m['citta']);
      _provincia.text = v(m['provincia']);
      _telefono.text = v(m['telefono']);
      _email.text = v(m['email']).toLowerCase();
      final codice = v(m['codice_nazione']).toUpperCase();
      _nazione = _nazioni.where((n) => '${n['codice']}'.toUpperCase() == (codice.isEmpty ? 'IT' : codice)).firstOrNull;
      // orari e punto abituali della scheda del cliente
      final abituale = (dati['ritiro_abituale'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final chiave in _orari.keys.toList()) {
        final ora = v(abituale[chiave]);
        if (RegExp(r'^\d{2}:\d{2}').hasMatch(ora)) _orari[chiave] = ora.substring(0, 5);
      }
      _punto.text = v(abituale['ritiro_punto']);
      _colli.first.tipologia = _tipologie.where((x) => x['tipo_spedizione'] != 'DOCS').firstOrNull?['id'] as int?;
      _colli.first.imballaggio =
          _imballaggi.where((x) => x['id'] != 1).firstOrNull?['id'] as int? ?? _imballaggi.firstOrNull?['id'] as int?;
      setState(() => _attesa = false);
    } on ErroreApi catch (e) {
      if (e.codice == 'chiave_non_valida') {
        await Api.esci();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
        return;
      }
      if (mounted) {
        setState(() {
          _attesa = false;
          _errore = e.messaggio ?? _t.errore(e.codice);
        });
      }
    }
  }

  static num _numero(TextEditingController c) => num.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Set<String> _controlla() {
    final m = <String>{};
    void vuoto(String chiave, TextEditingController c) {
      if (c.text.trim().isEmpty) m.add(chiave);
    }

    vuoto('contatto', _contatto);
    vuoto('indirizzo', _indirizzo);
    vuoto('citta', _citta);
    vuoto('telefono', _telefono);
    vuoto('email', _email);
    if (_nazione == null) m.add('nazione');
    if (_nazione?['cap_obbligatorio'] != false) vuoto('cap', _cap);
    if ('${_nazione?['codice'] ?? ''}'.toUpperCase() == 'IT') vuoto('provincia', _provincia);
    if (_vettore == null) m.add('vettore');
    if (_giorno == null) m.add('giorno');
    vuoto('punto', _punto);
    for (var i = 0; i < _colli.length; i++) {
      final c = _colli[i];
      if (c.tipologia == null) m.add('tipologia_$i');
      if (c.imballaggio == null) m.add('imballaggio_$i');
      for (final (nome, campo) in [('peso', c.peso), ('lung', c.lunghezza), ('larg', c.larghezza), ('alt', c.altezza)]) {
        if (_numero(campo) <= 0) m.add('${nome}_$i');
      }
    }
    return m;
  }

  Future<void> _invia() async {
    final t = _t;
    FocusScope.of(context).unfocus();
    final mancanti = _controlla();
    if (mancanti.isNotEmpty) {
      setState(() {
        _mancanti = mancanti;
        _errore = t.t('errore_campi_mancanti');
      });
      return;
    }
    setState(() {
      _invio = true;
      _errore = null;
    });
    try {
      final r = await Api.prenotaRitiro({
        'mitt_societa': _societa.text.trim(),
        'mitt_contatto': _contatto.text.trim(),
        'mitt_indirizzo': _indirizzo.text.trim(),
        'mitt_cap': _cap.text.trim(),
        'mitt_citta': _citta.text.trim(),
        'mitt_provincia': _provincia.text.trim().toUpperCase(),
        'mitt_nazione': _nazione?['nome'],
        'mitt_codice_nazione': _nazione?['codice'],
        'mitt_telefono': _telefono.text.trim(),
        'mitt_email': _email.text.trim().toLowerCase(),
        'vettore': _vettore,
        'ritiro_attivo': true,
        'ritiro_data': _giorno,
        ..._orari,
        'ritiro_punto': _punto.text.trim(),
        'ritiro_istruzioni_note': _note.text.trim(),
        'colli': [
          for (final c in _colli)
            {
              'tipologia': c.tipologia,
              'imballaggio': c.imballaggio,
              'peso': _numero(c.peso),
              'lunghezza': _numero(c.lunghezza),
              'larghezza': _numero(c.larghezza),
              'altezza': _numero(c.altezza),
            }
        ],
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
          icon: const Icon(Icons.check_circle, color: Stile.verde, size: 48),
          content: Text('${r['messaggio'] ?? t.t('ritiro_richiesto')}', textAlign: TextAlign.center),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(t.t('ok')))],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio ?? t.errore(e.codice));
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  // ------------------------------------------------------------------ interfaccia

  InputDecoration _decorazione(String etichetta, String campo) => InputDecoration(
        labelText: etichetta,
        isDense: true,
        enabledBorder: _mancanti.contains(campo)
            ? const OutlineInputBorder(borderRadius: Stile.angoli, borderSide: BorderSide(color: Stile.rosso, width: 2))
            : null,
      );

  Widget _campo(TextEditingController c, String etichetta, String campo,
          {TextInputType? tipo, int? max, TextCapitalization maiuscole = TextCapitalization.none}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: tipo,
          maxLength: max,
          textCapitalization: maiuscole,
          onChanged: (_) {
            if (_mancanti.contains(campo)) setState(() => _mancanti.remove(campo));
          },
          decoration: _decorazione(etichetta, campo).copyWith(counterText: ''),
        ),
      );

  Widget _titolo(String testo) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: Text(testo, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
      );

  String _dataBreve(String? iso) =>
      iso == null || iso.length < 10 ? '' : '${iso.substring(8, 10)}.${iso.substring(5, 7)}.${iso.substring(2, 4)}';

  Future<void> _scegliGiorno() async {
    final primo = DateTime.tryParse(_primoGiorno ?? '') ?? DateTime.now();
    final scelto = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_giorno ?? '') ?? primo,
      firstDate: primo,
      lastDate: primo.add(const Duration(days: 60)),
      selectableDayPredicate: (d) => d.weekday <= 5,
    );
    if (scelto == null) return;
    setState(() {
      _giorno = '${scelto.year}-${scelto.month.toString().padLeft(2, '0')}-${scelto.day.toString().padLeft(2, '0')}';
      _mancanti.remove('giorno');
    });
  }

  Future<void> _scegliOra(String chiave) async {
    final parti = (_orari[chiave] ?? '09:00').split(':');
    final scelta = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parti[0]), minute: int.parse(parti[1])),
      builder: (c, figlio) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: figlio!),
    );
    if (scelta == null) return;
    setState(() =>
        _orari[chiave] = '${scelta.hour.toString().padLeft(2, '0')}:${scelta.minute.toString().padLeft(2, '0')}');
  }

  Widget _ora(String etichetta, String chiave) => Expanded(
        child: InkWell(
          onTap: () => _scegliOra(chiave),
          child: InputDecorator(
            decoration: InputDecoration(labelText: etichetta, isDense: true),
            child: Text(_orari[chiave] ?? ''),
          ),
        ),
      );

  Widget _collo(int i) {
    final t = _t;
    final c = _colli[i];
    Widget numero(TextEditingController campo, String etichetta, String chiave, {String? unita}) => TextField(
          controller: campo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) {
            if (_mancanti.contains(chiave)) setState(() => _mancanti.remove(chiave));
          },
          decoration: _decorazione(etichetta, chiave).copyWith(suffixText: unita),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      decoration: BoxDecoration(border: Border.all(color: context.colori.bordo), borderRadius: Stile.angoli),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${t.t('collo')} ${i + 1}', style: TextStyle(color: Stile.grigio))),
          if (_colli.length > 1)
            IconButton(
              tooltip: t.t('togli_collo'),
              icon: Icon(Icons.close, color: Stile.grigio, size: 20),
              onPressed: () => setState(() => _colli.removeAt(i).dispose()),
            )
          else
            const SizedBox(height: 40),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(children: [
            DropdownButtonFormField<int>(
              initialValue: c.tipologia,
              isDense: true,
              decoration: _decorazione(t.t('tipologia'), 'tipologia_$i'),
              items: [for (final x in _tipologie) DropdownMenuItem(value: x['id'] as int, child: Text('${x['nome']}'))],
              onChanged: (v) => setState(() => c.tipologia = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: c.imballaggio,
              isDense: true,
              decoration: _decorazione(t.t('imballaggio'), 'imballaggio_$i'),
              items: [for (final x in _imballaggi) DropdownMenuItem(value: x['id'] as int, child: Text('${x['nome']}'))],
              onChanged: (v) => setState(() => c.imballaggio = v),
            ),
            const SizedBox(height: 12),
            numero(c.peso, t.t('peso_kg'), 'peso_$i'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: numero(c.lunghezza, t.t('lunghezza_cm'), 'lung_$i', unita: 'cm')),
              const SizedBox(width: 8),
              Expanded(child: numero(c.larghezza, t.t('larghezza_cm'), 'larg_$i', unita: 'cm')),
              const SizedBox(width: 8),
              Expanded(child: numero(c.altezza, t.t('altezza_cm'), 'alt_$i', unita: 'cm')),
            ]),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      appBar: barraApp(context, titolo: t.t('prenota_ritiro')),
      body: SafeArea(
        child: _attesa
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
                  _titolo(t.t('indirizzo_ritiro')),
                  _campo(_societa, t.t('societa'), 'societa', maiuscole: TextCapitalization.words),
                  _campo(_contatto, t.t('nome'), 'contatto', maiuscole: TextCapitalization.words),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        final n = await SceltaNazione.apri(context, _nazioni);
                        if (n != null) {
                          setState(() {
                            _nazione = n;
                            _mancanti.remove('nazione');
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: _decorazione(t.t('nazione'), 'nazione')
                            .copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
                        child: Text(_nazione == null ? '' : '${_nazione!['nome']} (${_nazione!['codice']})'),
                      ),
                    ),
                  ),
                  _campo(_indirizzo, t.t('indirizzo'), 'indirizzo', max: 35, maiuscole: TextCapitalization.words),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (CampoCap.serve(_nazione)) ...[
                      SizedBox(
                        width: 120,
                        child: CampoCap(
                          controller: _cap,
                          nazione: _nazione,
                          decorazione: _decorazione(t.t('cap'), 'cap'),
                          cambiato: () {
                            if (_mancanti.contains('cap')) setState(() => _mancanti.remove('cap'));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(child: _campo(_citta, t.t('citta'), 'citta', maiuscole: TextCapitalization.words)),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 80,
                        child: _campo(_provincia, t.t('provincia'), 'provincia',
                            max: 3, maiuscole: TextCapitalization.characters)),
                  ]),
                  _campo(_telefono, t.t('telefono'), 'telefono', tipo: TextInputType.phone, max: 15),
                  _campo(_email, t.t('email_campo'), 'email', tipo: TextInputType.emailAddress, max: 50),
                  _titolo(t.t('corriere_ritiro')),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final v in _vettori)
                      ChoiceChip(
                        label: Text(v),
                        selected: _vettore == v,
                        side: _mancanti.contains('vettore') ? const BorderSide(color: Stile.rosso, width: 2) : null,
                        onSelected: (_) => setState(() {
                          _vettore = v;
                          _mancanti.remove('vettore');
                        }),
                      ),
                  ]),
                  _titolo(t.t('ritiro')),
                  InkWell(
                    onTap: _scegliGiorno,
                    child: InputDecorator(
                      decoration: _decorazione(t.t('giorno_ritiro'), 'giorno')
                          .copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                      child: Text(_dataBreve(_giorno)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _ora(t.t('mattino_dalle'), 'ritiro_ora_mattino_dalle'),
                    const SizedBox(width: 8),
                    _ora(t.t('alle'), 'ritiro_ora_mattino_alle'),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _ora(t.t('pomeriggio_dalle'), 'ritiro_ora_pomeriggio_dalle'),
                    const SizedBox(width: 8),
                    _ora(t.t('alle'), 'ritiro_ora_pomeriggio_alle'),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [_ora(t.t('pronti_dalle'), 'ritiro_ora_pronti_dalle'), const Spacer()]),
                  const SizedBox(height: 12),
                  _campo(_punto, t.t('punto_ritiro'), 'punto', max: 25),
                  _campo(_note, t.t('note_ritiro'), 'note'),
                  _titolo(t.t('colli_titolo')),
                  for (var i = 0; i < _colli.length; i++) _collo(i),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(t.t('aggiungi_collo')),
                    onPressed: () => setState(() => _colli.add(_Collo()
                      ..tipologia = _colli.last.tipologia
                      ..imballaggio = _colli.last.imballaggio)),
                  ),
                  if (_errore != null) ...[
                    const SizedBox(height: 16),
                    Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _invio ? null : _invia,
                    child: _invio
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t.t('chiedi_ritiro')),
                  ),
                ]),
              ),
      ),
    );
  }
}
