import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../widget/barra.dart';
import '../testi.dart';
import '../widget/riquadro_bonifico.dart';
import 'dettaglio_spedizione.dart';
import 'entrata.dart';
import 'pagamento_carta.dart';
import 'profilo.dart';

/// Pagamenti e fatture del cliente (nota 369): da pagare, fatture, credito prepagato.
/// Si paga come sul sito: carta nella pagina myPOS dentro l'app, bonifico con IBAN e
/// causale da copiare, credito per le fatture se basta.
class SchermataPagamentiFatture extends StatefulWidget {
  const SchermataPagamentiFatture({super.key});

  @override
  State<SchermataPagamentiFatture> createState() => _SchermataPagamentiFattureState();
}

const _arancio = Color(0xFFFF9800);

String _euro(num? v, Testi t) => SchermataProfiloState.euro(v ?? 0, t.lingua);

String _data(dynamic v) => v == null ? '' : Api.dataBreve('$v');

/// Scelta del metodo, chiamata al server e seguito: carta (myPOS), bonifico (riquadro), credito.
/// Ritorna true se qualcosa e' cambiato e la schermata va riletta.
Future<bool> pagaCon(BuildContext context, List<String> metodi,
    Future<Map<String, dynamic>> Function(String metodo) chiamata) async {
  final t = Testi.di(context);
  final icone = {'credito': Icons.account_balance_wallet_outlined, 'carta': Icons.credit_card, 'bonifico': Icons.account_balance};
  final metodo = metodi.length == 1
      ? metodi.first
      : await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
          builder: (c) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(t.t('come_paghi'), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
              ),
              for (final m in metodi)
                ListTile(
                  leading: Icon(icone[m], color: Stile.verde),
                  title: Text(t.t('metodo_$m')),
                  onTap: () => Navigator.pop(c, m),
                ),
              const SizedBox(height: 8),
            ]),
          ),
        );
  if (metodo == null || !context.mounted) return false;
  try {
    final r = await chiamata(metodo);
    if (!context.mounted) return true;
    if (r['metodo'] == 'carta' || metodo == 'carta') {
      final url = r['url'];
      if (url == null) throw ErroreApi('generico');
      final esito = await SchermataPagamentoCarta.apri(context, '$url');
      if (!context.mounted) return true;
      await _messaggio(context, t.t(esito == EsitoCarta.riuscito
          ? 'pagamento_ok'
          : esito == EsitoCarta.nonRiuscito
              ? 'pagamento_non_riuscito'
              : 'pagamento_non_completato'), riuscito: esito == EsitoCarta.riuscito);
    } else if (metodo == 'bonifico') {
      await RiquadroBonifico.mostra(context, r, titolo: t.t('paga_con_bonifico'));
    } else {
      await _messaggio(context, t.t('pagato_col_credito'), riuscito: true);
    }
    return true;
  } on ErroreApi catch (e) {
    if (context.mounted) await _messaggio(context, e.messaggio ?? t.errore(e.codice), riuscito: false);
    return false;
  }
}

Future<void> _messaggio(BuildContext context, String testo, {required bool riuscito}) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        icon: Icon(riuscito ? Icons.check_circle : Icons.info_outline,
            color: riuscito ? Stile.verde : Stile.grigio, size: 48),
        content: Text(testo, textAlign: TextAlign.center),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: Text(Testi.di(context).t('ok')))],
      ),
    );

Future<void> _uscitaSeChiaveScaduta(BuildContext context, ErroreApi e) async {
  if (e.codice != 'chiave_non_valida') return;
  await Api.esci();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
}

Color _coloreFattura(Map<String, dynamic> f) =>
    f['stato'] == 'pagata' ? Stile.verde : (f['scaduta'] == true ? Stile.rosso : _arancio);

String _statoFattura(Map<String, dynamic> f, Testi t) => f['nota_credito'] == true
    ? t.t('nota_credito')
    : f['stato'] == 'pagata'
        ? t.t('fattura_pagata')
        : (f['scaduta'] == true ? t.t('fattura_scaduta') : t.t('fattura_da_pagare'));

class _SchermataPagamentiFattureState extends State<SchermataPagamentiFatture> with SingleTickerProviderStateMixin {
  late final TabController _schede = TabController(length: 3, vsync: this);
  final _chiaveDaPagare = GlobalKey<_DaPagareState>();
  final _chiaveFatture = GlobalKey<_FattureState>();
  final _chiaveCredito = GlobalKey<_CreditoState>();

  @override
  void dispose() {
    _schede.dispose();
    super.dispose();
  }

  /// Dopo un pagamento tutte e tre le schede si rileggono
  void _rileggiTutto() {
    _chiaveDaPagare.currentState?.carica();
    _chiaveFatture.currentState?.ricarica();
    _chiaveCredito.currentState?.carica();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return Scaffold(
      appBar: barraApp(
        context,
        titolo: t.t('pagamenti_fatture'),
        sotto: TabBar(
          controller: _schede,
          indicatorColor: Stile.verde,
          labelColor: Stile.verde,
          unselectedLabelColor: Stile.grigio,
          tabs: [Tab(text: t.t('da_pagare')), Tab(text: t.t('fatture')), Tab(text: t.t('credito'))],
        ),
      ),
      body: SafeArea(
        child: TabBarView(controller: _schede, children: [
          _DaPagare(key: _chiaveDaPagare, cambiato: _rileggiTutto),
          _Fatture(key: _chiaveFatture, cambiato: _rileggiTutto),
          _Credito(key: _chiaveCredito, cambiato: _rileggiTutto),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------- da pagare

class _DaPagare extends StatefulWidget {
  const _DaPagare({super.key, required this.cambiato});

  final VoidCallback cambiato;

  @override
  State<_DaPagare> createState() => _DaPagareState();
}

class _DaPagareState extends State<_DaPagare> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _spedizioni = [];
  List<Map<String, dynamic>> _fatture = [];
  final Set<int> _scelte = {};
  Map<String, dynamic> _credito = {};
  bool _attesa = true;
  String? _errore;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    carica();
  }

  Future<void> carica() async {
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      final r = await Future.wait([
        Api.pagamentiAperti(),
        Api.fatture(stato: 'da_pagare', perPagina: 100),
        Api.credito().catchError((_) => <String, dynamic>{'attivo': false}),
      ]);
      if (!mounted) return;
      setState(() {
        _spedizioni = ((r[0]['spedizioni'] as List?) ?? []).cast<Map<String, dynamic>>();
        _fatture = ((r[1]['fatture'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .where((f) => f['nota_credito'] != true && ((f['da_pagare'] as num?) ?? 0) > 0)
            .toList();
        _scelte.removeWhere((id) => !_fatture.any((f) => f['id'] == id));
        _credito = r[2];
      });
    } on ErroreApi catch (e) {
      if (!mounted) return;
      await _uscitaSeChiaveScaduta(context, e);
      if (mounted) setState(() => _errore = e.messaggio ?? Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  double get _totaleScelte =>
      _fatture.where((f) => _scelte.contains(f['id'])).fold(0.0, (s, f) => s + ((f['da_pagare'] as num?) ?? 0));

  Future<void> _pagaFatture() async {
    final totale = _totaleScelte;
    final metodi = [
      if (_credito['attivo'] == true && ((_credito['saldo'] as num?) ?? 0) >= totale) 'credito',
      'carta',
      'bonifico',
    ];
    final cambiato = await pagaCon(context, metodi, (m) => Api.pagaFatture(_scelte.toList(), m));
    if (cambiato) widget.cambiato();
  }

  Future<void> _pagaSpedizione(Map<String, dynamic> s) async {
    final metodi = (((s['pagamento'] as Map?)?['metodi'] as List?) ?? ['carta', 'bonifico']).cast<String>();
    final cambiato = await pagaCon(context, metodi, (m) => Api.pagaSpedizione(s['id'] as int, m));
    if (cambiato) widget.cambiato();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Testi.di(context);
    if (_attesa && _spedizioni.isEmpty && _fatture.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_errore != null) return _Errore(testo: _errore!, riprova: carica);
    return RefreshIndicator(
      onRefresh: carica,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_spedizioni.isEmpty && _fatture.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(t.t('niente_da_pagare'), textAlign: TextAlign.center, style: const TextStyle(color: Stile.grigio)),
            ),
          if (_spedizioni.isNotEmpty) ...[
            _Titolo(t.t('spedizioni_da_pagare')),
            for (final s in _spedizioni)
              _Riquadro(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => SchermataDettaglioSpedizione(id: s['id'] as int))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('MOS ${s['id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text([Api.nomeProprio('${s['destinatario'] ?? ''}'), Api.nomeProprio('${s['dest_citta'] ?? ''}')]
                              .where((v) => v.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(color: Stile.grigio, fontSize: 13)),
                      if (s['scadenza_link'] != null)
                        Text('${t.t('paga_entro')} ${_data(s['scadenza_link'])}',
                            style: const TextStyle(color: _arancio, fontSize: 12)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_euro(s['importo'] as num?, t),
                        style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (s['pagamento'] != null)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(90, 36)),
                          onPressed: () => _pagaSpedizione(s),
                          child: Text(t.t('paga')),
                        ),
                      ),
                  ]),
                ]),
              ),
            const SizedBox(height: 16),
          ],
          if (_fatture.isNotEmpty) ...[
            _Titolo(t.t('fatture_da_pagare')),
            for (final f in _fatture)
              _Riquadro(
                onTap: () => setState(() => _scelte.contains(f['id']) ? _scelte.remove(f['id']) : _scelte.add(f['id'] as int)),
                child: Row(children: [
                  Checkbox(
                    value: _scelte.contains(f['id']),
                    activeColor: Stile.verde,
                    onChanged: (v) => setState(() => v == true ? _scelte.add(f['id'] as int) : _scelte.remove(f['id'])),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t.t('fattura')} ${f['numero']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_data(f['data'])}${f['scadenza'] != null ? ' · ${t.t('scadenza')} ${_data(f['scadenza'])}' : ''}',
                          style: TextStyle(color: f['scaduta'] == true ? Stile.rosso : Stile.grigio, fontSize: 12)),
                    ]),
                  ),
                  Text(_euro(f['da_pagare'] as num?, t), style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _scelte.isEmpty ? null : _pagaFatture,
              child: Text(_scelte.isEmpty
                  ? t.t('scegli_fatture')
                  : '${t.t('paga')} ${_scelte.length} · ${_euro(_totaleScelte, t)}'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- fatture

class _Fatture extends StatefulWidget {
  const _Fatture({super.key, required this.cambiato});

  final VoidCallback cambiato;

  @override
  State<_Fatture> createState() => _FattureState();
}

class _FattureState extends State<_Fatture> with AutomaticKeepAliveClientMixin {
  static const _filtri = ['', 'da_pagare', 'pagate'];
  String _filtro = '';
  final List<Map<String, dynamic>> _righe = [];
  int _pagina = 0;
  int _pagine = 1;
  bool _attesa = false;
  String? _errore;
  int _giro = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    ricarica();
  }

  Future<void> ricarica() async {
    _giro++;
    setState(() {
      _righe.clear();
      _pagina = 0;
      _pagine = 1;
      _errore = null;
    });
    await _altre();
  }

  Future<void> _altre() async {
    if ((_attesa && _pagina > 0) || _pagina >= _pagine) return;
    final giro = _giro;
    setState(() => _attesa = true);
    try {
      final r = await Api.fatture(stato: _filtro, pagina: _pagina + 1);
      if (!mounted || giro != _giro) return;
      setState(() {
        _righe.addAll(((r['fatture'] as List?) ?? []).cast<Map<String, dynamic>>());
        _pagina = (r['pagina'] as int?) ?? _pagina + 1;
        _pagine = (r['pagine'] as int?) ?? _pagina;
      });
    } on ErroreApi catch (e) {
      if (!mounted) return;
      await _uscitaSeChiaveScaduta(context, e);
      if (mounted && giro == _giro) setState(() => _errore = e.messaggio ?? Testi.di(context).errore(e.codice));
    } finally {
      if (mounted && giro == _giro) setState(() => _attesa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Testi.di(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Wrap(spacing: 8, children: [
          for (final f in _filtri)
            ChoiceChip(
              label: Text(t.t('filtro_fatture_${f.isEmpty ? 'tutte' : f}')),
              selected: _filtro == f,
              selectedColor: Stile.verde.withValues(alpha: 0.25),
              shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
              onSelected: (_) {
                _filtro = f;
                ricarica();
              },
            ),
        ]),
      ),
      Expanded(
        child: _errore != null && _righe.isEmpty
            ? _Errore(testo: _errore!, riprova: ricarica)
            : _righe.isEmpty
                ? (_attesa
                    ? const Center(child: CircularProgressIndicator())
                    : Center(child: Text(t.t('nessuna_fattura'), style: const TextStyle(color: Stile.grigio))))
                : RefreshIndicator(
                    onRefresh: ricarica,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _altre();
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _righe.length + (_attesa ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _righe.length) {
                            return const Padding(
                                padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
                          }
                          final f = _righe[i];
                          final colore = _coloreFattura(f);
                          return _Riquadro(
                            onTap: () async {
                              final cambiato = await Navigator.of(context).push<bool>(
                                  MaterialPageRoute(builder: (_) => SchermataFattura(id: f['id'] as int)));
                              if (cambiato == true) widget.cambiato();
                            },
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${t.t('fattura')} ${f['numero']}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                      '${_data(f['data'])}${f['scadenza'] != null && f['stato'] != 'pagata' ? ' · ${t.t('scadenza')} ${_data(f['scadenza'])}' : ''}',
                                      style: const TextStyle(color: Stile.grigio, fontSize: 12)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(_euro(f['totale'] as num?, t), style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(_statoFattura(f, t), style: TextStyle(color: colore, fontSize: 12)),
                              ]),
                            ]),
                          );
                        },
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

/// Dettaglio di una fattura: righe, totali, PDF e «Paga» se e' da pagare.
class SchermataFattura extends StatefulWidget {
  const SchermataFattura({super.key, required this.id});

  final int id;

  @override
  State<SchermataFattura> createState() => _SchermataFatturaState();
}

class _SchermataFatturaState extends State<SchermataFattura> {
  Map<String, dynamic>? _f;
  Map<String, dynamic> _credito = {};
  bool _attesa = true;
  bool _pdf = false;
  bool _cambiato = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      final r = await Future.wait(
          [Api.fattura(widget.id), Api.credito().catchError((_) => <String, dynamic>{'attivo': false})]);
      if (mounted) {
        setState(() {
          _f = r[0];
          _credito = r[1];
        });
      }
    } on ErroreApi catch (e) {
      if (!mounted) return;
      await _uscitaSeChiaveScaduta(context, e);
      if (mounted) setState(() => _errore = e.messaggio ?? Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  Future<void> _apriPdf() async {
    final t = Testi.di(context);
    setState(() => _pdf = true);
    try {
      final byte = await Api.scarica('${_f!['pdf']}');
      // Se la fattura non e' del cliente il sito rimanda all'elenco: arriva una pagina, non un PDF
      if (byte.length < 4 || String.fromCharCodes(byte.take(4)) != '%PDF') throw ErroreApi('documento_non_disponibile');
      final cartella = await getTemporaryDirectory();
      final file = File('${cartella.path}/Fattura_${'${_f!['numero']}'.replaceAll(RegExp(r'[^\w]+'), '_')}.pdf');
      await file.writeAsBytes(byte, flush: true);
      final esito = await OpenFilex.open(file.path);
      if (esito.type != ResultType.done && mounted) _avviso(t.t('documento_non_apribile'));
    } on ErroreApi {
      if (mounted) _avviso(t.t('documento_non_disponibile'));
    } catch (_) {
      if (mounted) _avviso(t.t('documento_non_apribile'));
    } finally {
      if (mounted) setState(() => _pdf = false);
    }
  }

  void _avviso(String testo) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo, textAlign: TextAlign.center)));

  Future<void> _paga() async {
    final f = _f!;
    final daPagare = (f['da_pagare'] as num?) ?? 0;
    final metodi = [
      if (_credito['attivo'] == true && ((_credito['saldo'] as num?) ?? 0) >= daPagare) 'credito',
      'carta',
      'bonifico',
    ];
    if (await pagaCon(context, metodi, (m) => Api.pagaFatture([widget.id], m))) {
      _cambiato = true;
      await _carica();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final f = _f;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) Navigator.of(context).pop(_cambiato);
      },
      child: Scaffold(
        appBar: barraApp(context, titolo: f == null ? t.t('fattura') : '${t.t('fattura')} ${f['numero']}'),
        body: SafeArea(
          child: _attesa && f == null
              ? const Center(child: CircularProgressIndicator())
              : _errore != null
                  ? _Errore(testo: _errore!, riprova: _carica)
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: _coloreFattura(f!)), borderRadius: Stile.angoli),
                          child: Text(_statoFattura(f, t), style: TextStyle(color: _coloreFattura(f))),
                        ),
                        const Spacer(),
                        Text(_euro(f['totale'] as num?, t),
                            style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
                      ]),
                      const SizedBox(height: 16),
                      _Riga(t.t('data'), _data(f['data'])),
                      if (f['stato'] != 'pagata') _Riga(t.t('scadenza'), _data(f['scadenza'])),
                      if (f['pagata_il'] != null) _Riga(t.t('pagata_il'), _data(f['pagata_il'])),
                      if (((f['acconti'] as num?) ?? 0) > 0) _Riga(t.t('acconti'), _euro(f['acconti'] as num?, t)),
                      if (((f['da_pagare'] as num?) ?? 0) > 0) _Riga(t.t('da_pagare'), _euro(f['da_pagare'] as num?, t)),
                      if (f['causale'] != null) _Riga(t.t('causale'), '${f['causale']}'),
                      const SizedBox(height: 16),
                      _Titolo(t.t('righe_fattura')),
                      for (final r in ((f['righe'] as List?) ?? []).cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(
                              child: Text(
                                  '${r['descrizione'] ?? ''}${(r['spedizioni'] ?? 0) is num && (r['spedizioni'] as num) > 0 ? ' (${r['spedizioni']})' : ''}',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text(_euro(r['importo'] as num?, t), style: const TextStyle(fontSize: 13)),
                          ]),
                        ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        icon: _pdf
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(t.t('apri_pdf')),
                        onPressed: _pdf ? null : _apriPdf,
                      ),
                      if (f['pagamento'] != null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _paga, child: Text('${t.t('paga')} ${_euro(f['da_pagare'] as num?, t)}')),
                      ],
                    ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------- credito

class _Credito extends StatefulWidget {
  const _Credito({super.key, required this.cambiato});

  final VoidCallback cambiato;

  @override
  State<_Credito> createState() => _CreditoState();
}

class _CreditoState extends State<_Credito> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _c;
  bool _attesa = true;
  String? _errore;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    carica();
  }

  Future<void> carica() async {
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      final c = await Api.credito();
      if (mounted) setState(() => _c = c);
    } on ErroreApi catch (e) {
      if (!mounted) return;
      await _uscitaSeChiaveScaduta(context, e);
      if (mounted) setState(() => _errore = e.messaggio ?? Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  Future<double?> _chiediImporto(String titolo, String etichetta, {double? iniziale}) async {
    final t = Testi.di(context);
    final campo = TextEditingController(
        text: iniziale == null ? '' : iniziale.toStringAsFixed(2).replaceAll('.', t.lingua == 'en' ? '.' : ','));
    final valore = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(titolo, textAlign: TextAlign.center),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: etichetta, prefixText: '€ '),
        ),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: Text(t.t('annulla')))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(c, double.tryParse(campo.text.trim().replaceAll(',', '.'))),
                child: Text(t.t('ok')),
              ),
            ),
          ]),
        ],
      ),
    );
    // il campo si libera solo a finestra chiusa del tutto (durante l'animazione di uscita e' ancora in uso)
    Future.delayed(const Duration(seconds: 1), campo.dispose);
    return valore;
  }

  Future<void> _ricarica() async {
    final t = Testi.di(context);
    final importo = await _chiediImporto(t.t('ricarica_credito'), t.t('importo'));
    if (!mounted || importo == null) return;
    if (importo < 10) {
      await _messaggio(context, t.t('ricarica_minima'), riuscito: false);
      return;
    }
    if (await pagaCon(context, ['carta', 'bonifico'], (m) => Api.richiediRicarica(importo, m))) {
      if (mounted) await _messaggio(context, t.t('ricarica_in_attesa'), riuscito: true);
      widget.cambiato();
    }
  }

  Future<void> _soglia() async {
    final t = Testi.di(context);
    final valore = await _chiediImporto(t.t('soglia_credito'), t.t('soglia_credito'),
        iniziale: (_c?['soglia'] as num?)?.toDouble());
    if (!mounted || valore == null || valore < 0) return;
    try {
      await Api.salvaSoglia(valore);
      await carica();
    } on ErroreApi catch (e) {
      if (mounted) await _messaggio(context, e.messaggio ?? t.errore(e.codice), riuscito: false);
    }
  }

  String _descrizione(Map<String, dynamic> m, Testi t) {
    final tipo = '${m['tipo'] ?? ''}';
    final spedizione = m['spedizione_id'] is num && (m['spedizione_id'] as num) > 0;
    final base = switch (tipo) {
      'ricarica' => t.t('mov_ricarica'),
      'storno' => t.t('mov_storno'),
      'impegno' => t.t('mov_impegno'),
      _ => spedizione ? t.t('mov_spedizione') : t.t('mov_addebito'),
    };
    final dettagli = [
      if (spedizione) 'MOS ${(m['spedizione_id'] as num).toInt()}',
      if ('${m['dest_citta'] ?? ''}'.trim().isNotEmpty) Api.nomeProprio('${m['dest_citta']}'.trim()),
      if (!spedizione && '${m['note'] ?? ''}'.trim().isNotEmpty) '${m['note']}'.trim(),
    ];
    return [base, ...dettagli].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Testi.di(context);
    if (_attesa && _c == null) return const Center(child: CircularProgressIndicator());
    if (_errore != null) return _Errore(testo: _errore!, riprova: carica);
    final c = _c ?? {};
    if (c['attivo'] != true) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t.t('saldo_non_attivo'), textAlign: TextAlign.center, style: const TextStyle(color: Stile.grigio)),
        ),
      );
    }
    final movimenti = ((c['movimenti'] as List?) ?? []).cast<Map<String, dynamic>>();
    return RefreshIndicator(
      onRefresh: carica,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _Riquadro(
          child: Row(children: [
            Expanded(child: Text(t.t('saldo'), style: const TextStyle(color: Stile.grigio))),
            Text(_euro(c['saldo'] as num?, t),
                style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 18)),
          ]),
        ),
        _Riquadro(
          onTap: _soglia,
          child: Row(children: [
            Expanded(child: Text(t.t('soglia_credito'), style: const TextStyle(color: Stile.grigio))),
            Text(_euro(c['soglia'] as num?, t)),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 18, color: Stile.verde),
          ]),
        ),
        const SizedBox(height: 4),
        ElevatedButton.icon(icon: const Icon(Icons.add), label: Text(t.t('ricarica_credito')), onPressed: _ricarica),
        const SizedBox(height: 20),
        _Titolo(t.t('movimenti')),
        if (movimenti.isEmpty)
          Text(t.t('nessun_movimento'), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
        for (final m in movimenti)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 64,
                child: Text(_data(m['data_movimento'] ?? m['creato_il']),
                    style: const TextStyle(color: Stile.grigio, fontSize: 12)),
              ),
              Expanded(
                child: Text(_descrizione(m, t),
                    style: TextStyle(
                        fontSize: 13,
                        color: m['annullato'] == 1 || m['annullato'] == 1.0 ? Stile.grigio : null)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  // segno davanti al simbolo: +€ 4,03 / -€ 4,03
                  '${((m['importo'] as num?) ?? 0) > 0 ? '+' : ((m['importo'] as num?) ?? 0) < 0 ? '-' : ''}'
                  '${_euro(((m['importo'] as num?) ?? 0).abs(), t)}',
                  style: TextStyle(fontSize: 13, color: ((m['importo'] as num?) ?? 0) > 0 ? Stile.verde : null),
                ),
                if (m['saldo'] != null)
                  Text(_euro(m['saldo'] as num?, t), style: const TextStyle(color: Stile.grigio, fontSize: 11)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------- pezzi comuni

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(testo, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
      );
}

class _Riquadro extends StatelessWidget {
  const _Riquadro({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: Stile.angoli,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: context.colori.card, border: Border.all(color: context.colori.bordo), borderRadius: Stile.angoli),
            child: child,
          ),
        ),
      );
}

class _Riga extends StatelessWidget {
  const _Riga(this.etichetta, this.valore);

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    if (valore.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(etichetta, style: const TextStyle(color: Stile.grigio, fontSize: 13))),
        Expanded(child: Text(valore, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

class _Errore extends StatelessWidget {
  const _Errore({required this.testo, required this.riprova});

  final String testo;
  final Future<void> Function() riprova;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(testo, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: riprova, child: Text(Testi.di(context).t('riprova'))),
          ]),
        ),
      );
}
