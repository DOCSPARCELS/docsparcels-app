import 'dart:async';

import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../widget/barra.dart';
import '../testi.dart';
import 'dettaglio_spedizione.dart';
import 'entrata.dart';
import 'nuova_spedizione.dart';
import 'pagamenti_fatture.dart';
import 'profilo.dart';
import '../widget/striscia_servizio.dart';

/// Le mie spedizioni (nota 368): le stesse righe e gli stessi filtri dell'elenco del sito.
class SchermataLeMieSpedizioni extends StatefulWidget {
  const SchermataLeMieSpedizioni({super.key});

  @override
  State<SchermataLeMieSpedizioni> createState() => _SchermataLeMieSpedizioniState();
}

const _filtri = ['', 'transito', 'consegnate', 'bozze'];
const _arancio = Color(0xFFFF9800);

class _SchermataLeMieSpedizioniState extends State<SchermataLeMieSpedizioni> with SingleTickerProviderStateMixin {
  late final TabController _schede = TabController(length: _filtri.length, vsync: this);
  final _cerca = TextEditingController();
  Timer? _ritardo;

  final List<Map<String, dynamic>> _righe = [];
  int _pagina = 0;
  int _pagine = 1;
  int _totale = 0;
  bool _attesa = false;
  String? _errore;

  /// Ogni nuova ricerca annulla le risposte di quelle prima
  int _giro = 0;

  /// Nota 373 V5: nelle Bozze anche le spedizioni con una richiesta di pagamento aperta
  List<Map<String, dynamic>> _daPagare = [];

  bool get _bozze => _filtri[_schede.index] == 'bozze';

  @override
  void initState() {
    super.initState();
    _schede.addListener(() {
      if (!_schede.indexIsChanging) _ricarica();
    });
    _ricarica();
  }

  @override
  void dispose() {
    _ritardo?.cancel();
    _schede.dispose();
    _cerca.dispose();
    super.dispose();
  }

  Testi get _t => Testi.di(context);

  Future<void> _ricarica() async {
    _giro++;
    setState(() {
      _righe.clear();
      _pagina = 0;
      _pagine = 1;
      _totale = 0;
      _errore = null;
      _daPagare = [];
    });
    if (_bozze || _filtri[_schede.index] == '') _caricaDaPagare(_giro);
    await _caricaAltre();
  }

  Future<void> _caricaDaPagare(int giro) async {
    try {
      final r = await Api.pagamentiAperti();
      if (!mounted || giro != _giro) return;
      final cerca = _cerca.text.trim().toLowerCase();
      setState(() => _daPagare = ((r['spedizioni'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) => cerca.isEmpty ||
              ['id', 'destinatario', 'dest_citta'].any((k) => '${s[k] ?? ''}'.toLowerCase().contains(cerca)))
          .map((s) => {
                ...s,
                'tipo': 'spedizione',
                'mos': s['id'],
                'data': Api.dataBreve('${s['data'] ?? ''}'),
                'totale': s['importo'],
                'da_pagare': true,
              })
          .toList());
    } on ErroreApi catch (_) {
      // l'elenco delle bozze resta comunque
    }
  }

  Future<void> _paga(Map<String, dynamic> s) async {
    final metodi = (((s['pagamento'] as Map?)?['metodi'] as List?) ?? ['carta', 'bonifico']).cast<String>();
    final cambiato = await pagaCon(context, metodi, (m) => Api.pagaSpedizione(s['id'] as int, m));
    if (cambiato && mounted) _ricarica();
  }

  Future<void> _caricaAltre() async {
    if (_attesa && _pagina > 0) return;
    if (_pagina >= _pagine) return;
    final giro = _giro;
    setState(() => _attesa = true);
    try {
      final r = await Api.leMieSpedizioni(
          stato: _filtri[_schede.index], cerca: _cerca.text.trim(), pagina: _pagina + 1);
      if (!mounted || giro != _giro) return;
      setState(() {
        _righe.addAll(((r['spedizioni'] as List?) ?? []).cast<Map<String, dynamic>>());
        _pagina = (r['pagina'] as int?) ?? _pagina + 1;
        _pagine = (r['pagine'] as int?) ?? _pagina;
        _totale = (r['totale'] as int?) ?? _righe.length;
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
      setState(() => _errore = e.messaggio ?? _t.errore(e.codice));
    } finally {
      if (mounted && giro == _giro) setState(() => _attesa = false);
    }
  }

  void _cercaCambiata(String _) {
    _ritardo?.cancel();
    _ritardo = Timer(const Duration(milliseconds: 500), _ricarica);
  }

  Future<void> _apri(Map<String, dynamic> r) async {
    final tipo = '${r['tipo']}';
    final id = r['id'] as int?;
    if (id == null) return;
    if (tipo == 'bozza') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => SchermataNuovaSpedizione(bozzaId: id)));
      if (mounted) _ricarica();
      return;
    }
    if (tipo == 'da_completare') {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
          content: Text(_t.t('da_completare_sul_sito'), textAlign: TextAlign.center),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(_t.t('chiudi')))],
        ),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SchermataDettaglioSpedizione(id: id, vecchia: tipo == 'vecchia')));
  }

  static Color _colore(String? esadecimale) {
    final testo = (esadecimale ?? '').replaceAll('#', '').trim();
    final valore = int.tryParse(testo, radix: 16);
    if (testo.length != 6 || valore == null) return Stile.grigio;
    return Color(0xFF000000 | valore);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      appBar: barraApp(
        context,
        titolo: t.t('le_mie_spedizioni'),
        sotto: TabBar(
          controller: _schede,
          // nota 373 V23: quattro schede su tutta la larghezza
          labelPadding: const EdgeInsets.symmetric(horizontal: 3),
          indicatorColor: Stile.verde,
          labelColor: Stile.verde,
          unselectedLabelColor: Stile.grigio,
          tabs: [
            for (final chiave in ['filtro_tutte', 'filtro_transito', 'filtro_consegnate', 'filtro_bozze'])
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(t.t(chiave)))),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _cerca,
                onChanged: _cercaCambiata,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _ricarica(),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: t.t('cerca_spedizione'),
                  suffixIcon: _cerca.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _cerca.clear();
                            _ricarica();
                          },
                        ),
                ),
              ),
            ),
            Expanded(child: _elenco(t)),
          ],
        ),
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
    // Nota 373 V6: una spedizione da pagare gia' in elenco prende li' il «Paga» (niente doppioni);
    // nelle Bozze quelle che mancano vanno in cima
    final daPagare = {for (final d in _daPagare) d['id']: d};
    final presenti = {for (final r in _righe) r['id']};
    final righe = [
      if (_bozze) ..._daPagare.where((d) => !presenti.contains(d['id'])),
      for (final r in _righe)
        daPagare.containsKey(r['id'])
            ? {
                ...r,
                'da_pagare': true,
                'pagamento': daPagare[r['id']]!['pagamento'],
                'scadenza_link': daPagare[r['id']]!['scadenza_link'],
              }
            : r,
    ];
    if (righe.isEmpty) {
      return _attesa
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _ricarica,
              child: ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(t.t('nessuna_spedizione'), textAlign: TextAlign.center,
                      style: TextStyle(color: Stile.grigio)),
                ),
              ]),
            );
    }
    final altre = _pagina < _pagine;
    return RefreshIndicator(
      onRefresh: _ricarica,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (altre && n.metrics.pixels > n.metrics.maxScrollExtent - 300) _caricaAltre();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: righe.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i == righe.length) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: _attesa
                      ? const CircularProgressIndicator()
                      : Text('${_righe.length} / $_totale', style: TextStyle(color: Stile.grigio, fontSize: 12)),
                ),
              );
            }
            return _riga(t, righe[i]);
          },
        ),
      ),
    );
  }

  /// Nota 373 V17: colori dello stato piu' scuri nel tema chiaro (sul bianco erano troppo chiari)
  Color _scuro(Color c) => context.temaScuro ? c : (Color.lerp(c, Colors.black, 0.35) ?? c);

  /// MOS a gruppi: 5557171 -> 555 7171
  static String _mos(dynamic v) {
    final s = '$v';
    return s.length == 7 ? '${s.substring(0, 3)} ${s.substring(3)}' : s;
  }

  /// Mittente o destinatario: nome in grassetto, sotto CAP, citta' e nazione (come la card della home)
  Widget _lato(String etichetta, dynamic nome, dynamic cap, dynamic citta, dynamic nazione) {
    String pulito(dynamic v) => Api.nomeProprio(v == null ? '' : '$v'.trim());
    final chi = pulito(nome);
    final luogo = [cap == null ? '' : '$cap'.trim(), pulito(citta)].where((v) => v.isNotEmpty).join(' ');
    final dove = [luogo, pulito(nazione)].where((v) => v.isNotEmpty).join(' · ');
    if (chi.isEmpty && dove.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(etichetta, style: TextStyle(color: Stile.grigio, fontSize: 13))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (chi.isNotEmpty)
              Text(chi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colori.testo)),
            if (dove.isNotEmpty) Text(dove, style: TextStyle(color: Stile.grigio, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  /// Richieste inviate e spedizioni da pagare: «In lavorazione» in arancio a destra (nota 373 V5).
  /// Nota 390: le bozze mai inviate non sono «in lavorazione» ma «Bozza», in grigio.
  static bool _inLavorazione(Map<String, dynamic> r) => r['da_pagare'] == true || '${r['tipo']}' == 'richiesta';

  static bool _bozza(Map<String, dynamic> r) =>
      r['da_pagare'] != true && const {'bozza', 'da_completare'}.contains('${r['tipo']}');

  Widget _riga(Testi t, Map<String, dynamic> r) {
    final lavorazione = _inLavorazione(r);
    final bozza = _bozza(r);
    final colore = _colore(r['colore'] as String?);
    final totale = r['totale'] as num?;
    return InkWell(
      borderRadius: Stile.angoli,
      onTap: () => _apri(r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        decoration: BoxDecoration(
            color: context.colori.card, border: Border.all(color: context.colori.bordo), borderRadius: Stile.angoli),
        // Nota 373 V29: la freccina come nelle ultime spedizioni della home
        child: Row(children: [
          Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nota 373 V10: come la card «Ultima spedizione»: MOS e data in evidenza, poi mittente e
            // destinatario con nome, CAP, citta' e nazione
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MOS ${_mos(r['mos'] ?? r['id'])}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.colori.testo)),
                    if ('${r['data'] ?? ''}'.isNotEmpty)
                      Text('${r['data']}', style: TextStyle(color: Stile.grigio, fontSize: 13)),
                  ]),
                ),
                if (totale != null)
                  Text(SchermataProfiloState.euro(totale, t.lingua),
                      style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            _lato(t.t('mittente'), r['mittente'], r['mitt_cap'], r['mitt_citta'], r['mitt_nazione'] ?? r['mitt_codice_nazione']),
            _lato(t.t('destinatario'), r['destinatario'], r['dest_cap'], r['dest_citta'],
                r['dest_nazione'] ?? r['dest_codice_nazione']),
            const SizedBox(height: 4),
            // Nota 373 V17: striscia larga e sfumata, nome del servizio nero; lo stato sotto, a destra
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if ('${r['servizio'] ?? ''}'.trim().isNotEmpty) ...[
                  StrisciaServizio(colore: StrisciaServizio.daTesto(r['colore_servizio']), larghezza: 30, altezza: 18),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      if ('${r['servizio'] ?? ''}'.trim().isNotEmpty)
                        TextSpan(
                            text: '${r['servizio']}'.trim(),
                            style: TextStyle(color: context.colori.testo, fontWeight: FontWeight.w600)),
                      if ('${r['awb'] ?? ''}'.trim().isNotEmpty)
                        TextSpan(
                            text: '${'${r['servizio'] ?? ''}'.trim().isNotEmpty ? ' · ' : ''}${r['awb']}',
                            style: TextStyle(color: Stile.grigio)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            // stato sotto l'AWB, a destra, piu' scuro (nel tema chiaro); se e' lungo va su due righe
            if (!lavorazione && !bozza && '${r['stato'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: _scuro(colore)), borderRadius: Stile.angoli),
                    child: Text('${r['stato']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: _scuro(colore), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
            if (bozza) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(t.t('stato_bozza'),
                    style: TextStyle(color: Stile.grigio, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
            if (lavorazione) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(t.t('in_lavorazione'),
                    style: TextStyle(color: _scuro(_arancio), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
            if (r['da_pagare'] == true && r['pagamento'] != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                if (r['scadenza_link'] != null)
                  Expanded(
                    child: Text('${t.t('paga_entro')} ${Api.dataBreve('${r['scadenza_link']}')}',
                        style: const TextStyle(color: _arancio, fontSize: 12)),
                  )
                else
                  const Spacer(),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(90, 36)),
                    onPressed: () => _paga(r),
                    child: Text(t.t('paga')),
                  ),
                ),
              ]),
            ],
          ],
          )),
          Icon(Icons.chevron_right, color: Stile.grigio),
        ]),
      ),
    );
  }
}
