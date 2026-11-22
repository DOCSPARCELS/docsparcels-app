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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Stile.verde,
          labelColor: Stile.verde,
          unselectedLabelColor: Stile.grigio,
          tabs: [
            Tab(text: t.t('filtro_tutte')),
            Tab(text: t.t('filtro_transito')),
            Tab(text: t.t('filtro_consegnate')),
            Tab(text: t.t('filtro_bozze')),
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
                      style: const TextStyle(color: Stile.grigio)),
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
                      : Text('${_righe.length} / $_totale', style: const TextStyle(color: Stile.grigio, fontSize: 12)),
                ),
              );
            }
            return _riga(t, righe[i]);
          },
        ),
      ),
    );
  }

  /// Bozze, richieste e spedizioni da pagare: «In lavorazione» in arancio a destra (nota 373 V5)
  static bool _inLavorazione(Map<String, dynamic> r) =>
      r['da_pagare'] == true || const {'bozza', 'da_completare', 'richiesta'}.contains('${r['tipo']}');

  Widget _riga(Testi t, Map<String, dynamic> r) {
    final lavorazione = _inLavorazione(r);
    final colore = _colore(r['colore'] as String?);
    final destinatario = Api.nomeProprio('${r['destinatario'] ?? ''}'.trim());
    final arrivo = [Api.nomeProprio('${r['dest_citta'] ?? ''}'.trim()), '${r['dest_codice_nazione'] ?? ''}'.trim()]
        .where((v) => v.isNotEmpty)
        .join(' · ');
    final totale = r['totale'] as num?;
    return InkWell(
      borderRadius: Stile.angoli,
      onTap: () => _apri(r),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: context.colori.card, border: Border.all(color: context.colori.bordo), borderRadius: Stile.angoli),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('MOS ${r['mos'] ?? r['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${r['data'] ?? ''}', style: const TextStyle(color: Stile.grigio, fontSize: 13)),
                const Spacer(),
                if (totale != null)
                  Text(SchermataProfiloState.euro(totale, t.lingua),
                      style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            if (destinatario.isNotEmpty) Text(destinatario, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (arrivo.isNotEmpty)
              Text(arrivo, style: const TextStyle(color: Stile.grigio, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                if (!lavorazione) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: colore), borderRadius: Stile.angoli),
                    child: Text('${r['stato'] ?? ''}', style: TextStyle(color: colore, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    [r['servizio'], r['awb']].where((v) => v != null && '$v'.trim().isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Stile.grigio, fontSize: 12),
                  ),
                ),
                if (lavorazione) ...[
                  const SizedBox(width: 8),
                  Text(t.t('in_lavorazione'), style: const TextStyle(color: _arancio, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
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
        ),
      ),
    );
  }
}
