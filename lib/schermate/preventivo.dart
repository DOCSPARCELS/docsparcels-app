import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import '../widget/scelta_nazione.dart';
import 'entrata.dart';
import 'nuova_spedizione.dart';
import 'profilo.dart';

/// Preventivo veloce: partenza, arrivo, documenti o pacco, colli e «Calcola».
/// I prezzi li calcola il server (/cliente/api/calcola), gli stessi dell'area cliente.
class SchermataPreventivo extends StatefulWidget {
  const SchermataPreventivo({super.key});

  @override
  State<SchermataPreventivo> createState() => _SchermataPreventivoState();
}

class _Collo {
  final peso = TextEditingController();
  final lunghezza = TextEditingController();
  final larghezza = TextEditingController();
  final altezza = TextEditingController();

  void dispose() {
    for (final c in [peso, lunghezza, larghezza, altezza]) {
      c.dispose();
    }
  }
}

class _Luogo {
  Map<String, dynamic>? nazione;
  final cap = TextEditingController();
  final citta = TextEditingController();

  /// Contatto scelto dalla rubrica (nota 373 V11): con «Spedisci» passa tutti i suoi dati
  Map<String, dynamic>? contatto;

  void dispose() {
    cap.dispose();
    citta.dispose();
  }
}

// Tipologie del gestionale: 1 = Documenti (DOCS), 2 = Merce (PKG)
const _tipologiaDocumenti = 1;
const _tipologiaPacco = 2;

class _SchermataPreventivoState extends State<SchermataPreventivo> {
  final _partenza = _Luogo();
  final _arrivo = _Luogo();
  final List<_Collo> _colli = [_Collo()];
  int _tipologia = _tipologiaPacco;
  List<Map<String, dynamic>> _nazioni = [];
  List<Map<String, dynamic>>? _tariffe;

  /// Nota 373 V5: dopo «Calcola» la pagina scorre da sola fino alle tariffe
  final _chiaveTariffe = GlobalKey();

  /// Nota 373 V11: rubrica (caricata alla prima apertura) e tariffa toccata, che mostra «Spedisci»
  List<Map<String, dynamic>>? _rubrica;
  int? _tariffaScelta;
  Set<String> _mancanti = {};
  String? _errore;
  bool _attesa = false;

  @override
  void initState() {
    super.initState();
    _caricaNazioni();
  }

  @override
  void dispose() {
    _partenza.dispose();
    _arrivo.dispose();
    for (final c in _colli) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _caricaNazioni() async {
    try {
      final nazioni = await Api.nazioni();
      if (!mounted) return;
      setState(() {
        _nazioni = nazioni;
        _partenza.nazione ??= nazioni.where((n) => n['codice'] == 'IT').firstOrNull;
      });
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
    }
  }

  Future<void> _gestisciErrore(ErroreApi e) async {
    if (e.codice == 'chiave_non_valida') {
      await Api.esci();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
      return;
    }
    if (mounted) setState(() => _errore = Testi.di(context).errore(e.codice));
  }

  static double _numero(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  bool _capObbligatorio(_Luogo l) => l.nazione?['cap_obbligatorio'] != false;

  Set<String> _campiMancanti() {
    final mancanti = <String>{};
    for (final (nome, luogo) in [('p', _partenza), ('a', _arrivo)]) {
      if (luogo.nazione == null) mancanti.add('${nome}_nazione');
      if (_capObbligatorio(luogo) && luogo.cap.text.trim().isEmpty) mancanti.add('${nome}_cap');
      if (luogo.citta.text.trim().isEmpty) mancanti.add('${nome}_citta');
    }
    for (var i = 0; i < _colli.length; i++) {
      if (_numero(_colli[i].peso) <= 0) mancanti.add('peso_$i');
    }
    return mancanti;
  }

  Future<void> _calcola() async {
    FocusScope.of(context).unfocus();
    final testi = Testi.di(context);
    final mancanti = _campiMancanti();
    setState(() {
      _mancanti = mancanti;
      _tariffe = null;
      _errore = mancanti.isEmpty ? null : testi.t('errore_campi_mancanti');
    });
    if (mancanti.isNotEmpty) return;
    setState(() => _attesa = true);
    try {
      final tariffe = await Api.calcola({
        'mitt_codice_nazione': _partenza.nazione!['codice'],
        'dest_codice_nazione': _arrivo.nazione!['codice'],
        'mitt_cap': _partenza.cap.text.trim(),
        'dest_cap': _arrivo.cap.text.trim(),
        'mitt_citta': _partenza.citta.text.trim(),
        'dest_citta': _arrivo.citta.text.trim(),
        'colli': [
          for (final c in _colli)
            {
              'tipologia': _tipologia,
              'imballaggio': '',
              'peso': _numero(c.peso),
              'lunghezza': _numero(c.lunghezza),
              'larghezza': _numero(c.larghezza),
              'altezza': _numero(c.altezza),
            }
        ],
      });
      if (!mounted) return;
      setState(() {
        _tariffe = tariffe;
        if (tariffe.isEmpty) _errore = testi.t('errore_nessuna_tariffa');
      });
      if (tariffe.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final destinazione = _chiaveTariffe.currentContext;
          if (destinazione != null) {
            Scrollable.ensureVisible(destinazione,
                duration: const Duration(milliseconds: 400), curve: Curves.easeOut, alignment: 0.05);
          }
        });
      }
    } on ErroreApi catch (e) {
      await _gestisciErrore(e);
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  /// I dati sono cambiati: le tariffe mostrate non valgono piu'.
  void _cambiato() {
    if (_tariffe != null || _errore != null || _mancanti.isNotEmpty) {
      setState(() {
        _tariffe = null;
        _tariffaScelta = null;
        _errore = null;
        _mancanti = {};
      });
    }
  }

  Future<void> _dallaRubrica(_Luogo luogo) async {
    final t = Testi.di(context);
    if (_rubrica == null) {
      try {
        _rubrica = await Api.rubrica();
      } on ErroreApi catch (e) {
        await _gestisciErrore(e);
      }
      if (!mounted || _rubrica == null) return;
    }
    final scelto = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colori.fondo,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (_) => SceltaRubrica(voci: _rubrica!, testi: t),
    );
    if (scelto == null || !mounted) return;
    setState(() {
      final codice = '${scelto['codice_nazione_op'] ?? ''}'.toUpperCase();
      luogo.nazione = _nazioni.where((n) => '${n['codice']}'.toUpperCase() == codice).firstOrNull ?? luogo.nazione;
      luogo.cap.text = '${scelto['cap_op'] ?? ''}'.trim();
      luogo.citta.text = '${scelto['citta_op'] ?? ''}'.trim();
      luogo.contatto = scelto;
      _mancanti = {};
    });
    _cambiato();
  }

  /// «Spedisci» su una tariffa: Nuova spedizione con i dati del preventivo gia' scritti
  void _spedisci(Map<String, dynamic> tariffa) {
    Map<String, dynamic> lato(_Luogo l) => {
          'codice_nazione': l.nazione?['codice'],
          'cap': l.cap.text.trim(),
          'citta': l.citta.text.trim(),
          'contatto': l.contatto,
        };
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SchermataNuovaSpedizione(daPreventivo: {
              'mitt': lato(_partenza),
              'dest': lato(_arrivo),
              'documenti': _tipologia == _tipologiaDocumenti,
              'colli': [
                for (final c in _colli)
                  {
                    'peso': c.peso.text.trim(),
                    'lunghezza': c.lunghezza.text.trim(),
                    'larghezza': c.larghezza.text.trim(),
                    'altezza': c.altezza.text.trim(),
                  }
              ],
              'servizio_id': tariffa['id'],
            })));
  }

  Future<void> _scegliNazione(_Luogo luogo) async {
    final scelta = await SceltaNazione.apri(context, _nazioni);
    if (scelta == null) return;
    setState(() {
      luogo.nazione = scelta;
      _mancanti.removeWhere((m) => m.endsWith('_nazione'));
    });
    _cambiato();
  }

  InputDecoration _decorazione(String etichetta, String campo) => InputDecoration(
        labelText: etichetta,
        isDense: true,
        enabledBorder: _mancanti.contains(campo)
            ? const OutlineInputBorder(borderRadius: Stile.angoli, borderSide: BorderSide(color: Stile.rosso))
            : null,
      );

  Widget _titolo(String testo, {VoidCallback? rubrica}) => Padding(
        padding: EdgeInsets.only(top: rubrica == null ? 20 : 8, bottom: rubrica == null ? 10 : 2),
        child: Row(children: [
          Expanded(child: Text(testo, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600))),
          // Nota 373 V11: come nel gestionale, l'iconcina apre la rubrica
          if (rubrica != null)
            IconButton(
              tooltip: Testi.di(context).t('scegli_da_rubrica'),
              icon: const Icon(Icons.people, color: Stile.verde),
              onPressed: rubrica,
            ),
        ]),
      );

  Widget _luogo(Testi testi, _Luogo luogo, String prefisso) {
    final nazione = luogo.nazione;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _nazioni.isEmpty ? null : () => _scegliNazione(luogo),
          child: InputDecorator(
            decoration: _decorazione(testi.t('nazione'), '${prefisso}_nazione')
                .copyWith(suffixIcon: const Icon(Icons.arrow_drop_down)),
            child: Text(nazione == null ? '' : '${nazione['nome']} (${nazione['codice']})'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: luogo.cap,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  luogo.contatto = null;
                  _cambiato();
                },
                decoration: _decorazione(testi.t('cap'), '${prefisso}_cap'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: luogo.citta,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  luogo.contatto = null;
                  _cambiato();
                },
                decoration: _decorazione(testi.t('citta'), '${prefisso}_citta'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _numeroCampo(TextEditingController c, String etichetta, String campo, {String? unita}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _cambiato(),
        decoration: _decorazione(etichetta, campo).copyWith(suffixText: unita),
      );

  Widget _collo(Testi testi, int i) {
    final c = _colli[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      decoration: BoxDecoration(border: Border.all(color: Stile.grigio), borderRadius: Stile.angoli),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('${testi.t('collo')} ${i + 1}', style: TextStyle(color: Stile.grigio))),
              if (_colli.length > 1)
                IconButton(
                  tooltip: testi.t('togli_collo'),
                  icon: Icon(Icons.close, color: Stile.grigio, size: 20),
                  onPressed: () {
                    setState(() {
                      _colli.removeAt(i).dispose();
                      _mancanti.clear();
                    });
                    _cambiato();
                  },
                )
              else
                const SizedBox(height: 40),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                _numeroCampo(c.peso, testi.t('peso_kg'), 'peso_$i'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _numeroCampo(c.lunghezza, testi.t('lunghezza_cm'), '', unita: 'cm')),
                    const SizedBox(width: 8),
                    Expanded(child: _numeroCampo(c.larghezza, testi.t('larghezza_cm'), '', unita: 'cm')),
                    const SizedBox(width: 8),
                    Expanded(child: _numeroCampo(c.altezza, testi.t('altezza_cm'), '', unita: 'cm')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Il colore del servizio come nel gestionale (campo colore della tabella servizi)
  static Color _coloreServizio(dynamic esadecimale) {
    final testo = '${esadecimale ?? ''}'.replaceAll('#', '').trim();
    final valore = int.tryParse(testo, radix: 16);
    if (testo.length != 6 || valore == null) return Stile.verde;
    return Color(0xFF000000 | valore);
  }

  Widget _tariffa(Testi testi, Map<String, dynamic> t) {
    final scelta = _tariffaScelta != null && _tariffaScelta == t['id'];
    return GestureDetector(
      onTap: () => setState(() => _tariffaScelta = scelta ? null : t['id'] as int?),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          // nota 373 V11: striscia piu' larga
          border: Border(left: BorderSide(color: _coloreServizio(t['colore']), width: 8)),
          color: context.colori.card,
          borderRadius: Stile.angoli,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            children: [
              Expanded(child: Text('${t['nome'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(SchermataProfiloState.euro((t['totale'] as num?) ?? 0, testi.lingua),
                      style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
                  if (t['iva_inclusa'] == true)
                    Text(testi.t('iva_inclusa'), style: TextStyle(color: Stile.grigio, fontSize: 11)),
                ],
              ),
            ],
          ),
          // Nota 373 V11: toccando la tariffa compare «Spedisci», rosso
          if (scelta) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Stile.rosso, foregroundColor: Colors.white, minimumSize: const Size(130, 40)),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: Text(testi.t('spedisci')),
                onPressed: () => _spedisci(t),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testi = Testi.di(context);
    return Scaffold(
      appBar: barraApp(context, titolo: testi.t('preventivo_veloce')),
      // Un tocco fuori dai campi chiude la tastiera
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _titolo(testi.t('partenza'), rubrica: () => _dallaRubrica(_partenza)),
            _luogo(testi, _partenza, 'p'),
            _titolo(testi.t('arrivo'), rubrica: () => _dallaRubrica(_arrivo)),
            _luogo(testi, _arrivo, 'a'),
            const SizedBox(height: 20),
            SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Stile.verdePulsanti,
                selectedForegroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
              ),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: _tipologiaDocumenti, label: Text(testi.t('documenti'))),
                ButtonSegment(value: _tipologiaPacco, label: Text(testi.t('merce'))),
              ],
              selected: {_tipologia},
              onSelectionChanged: (s) {
                setState(() => _tipologia = s.first);
                _cambiato();
              },
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < _colli.length; i++) _collo(testi, i),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Stile.verde,
                side: const BorderSide(color: Stile.verde),
                shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.add),
              label: Text(testi.t('aggiungi_collo')),
              onPressed: () {
                setState(() => _colli.add(_Collo()));
                _cambiato();
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _attesa ? null : _calcola,
              child: _attesa
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(testi.t('calcola')),
            ),
            if (_errore != null) ...[
              const SizedBox(height: 16),
              Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso)),
            ],
            if (_tariffe != null && _tariffe!.isNotEmpty) ...[
              KeyedSubtree(key: _chiaveTariffe, child: _titolo(testi.t('tariffe'))),
              for (final t in _tariffe!) _tariffa(testi, t),
            ],
          ]),
        ),
      ),
      ),
    );
  }
}
