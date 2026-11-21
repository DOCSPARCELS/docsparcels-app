import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';
import 'entrata.dart';
import 'profilo.dart';

/// Dettaglio di una spedizione (nota 368): stato, percorso, colli, totale, passaggi del
/// tracciamento e documenti. Si apre dall'elenco e toccando una notifica.
class SchermataDettaglioSpedizione extends StatefulWidget {
  const SchermataDettaglioSpedizione({super.key, required this.id, this.vecchia = false});

  final int id;

  /// Spedizione del gestionale precedente: niente tracciamento ne' documenti dal nuovo
  final bool vecchia;

  @override
  State<SchermataDettaglioSpedizione> createState() => _SchermataDettaglioSpedizioneState();
}

class _SchermataDettaglioSpedizioneState extends State<SchermataDettaglioSpedizione> {
  Map<String, dynamic>? _sped;
  List<Map<String, String>> _passaggi = [];
  List<Map<String, String>> _documenti = [];
  bool _attesa = true;
  String? _errore;
  String? _scaricando;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Testi get _t => Testi.di(context);

  Future<void> _carica() async {
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      final sped = await Api.spedizione(widget.id, vecchia: widget.vecchia);
      var passaggi = <Map<String, String>>[];
      var documenti = <Map<String, String>>[];
      if (!widget.vecchia) {
        // tracciamento e documenti non devono far sparire il resto se non rispondono
        try {
          passaggi = await Api.tracciamento(widget.id);
        } on ErroreApi catch (e) {
          if (e.codice == 'chiave_non_valida') rethrow;
        }
        try {
          documenti = await Api.documenti(widget.id);
        } on ErroreApi catch (e) {
          if (e.codice == 'chiave_non_valida') rethrow;
        }
      }
      if (passaggi.isEmpty) passaggi = _dalloStorico(sped['storico']);
      if (!mounted) return;
      setState(() {
        _sped = sped;
        _passaggi = passaggi;
        _documenti = documenti;
      });
    } on ErroreApi catch (e) {
      if (e.codice == 'chiave_non_valida') {
        await Api.esci();
        if (!mounted) return;
        Navigator.of(context)
            .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
        return;
      }
      if (mounted) {
        setState(() => _errore = e.stato == 404 ? _t.t('spedizione_non_trovata') : (e.messaggio ?? _t.errore(e.codice)));
      }
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  /// Storico salvato con la spedizione (gestionale precedente), stessa forma dei passaggi
  static List<Map<String, String>> _dalloStorico(dynamic storico) {
    if (storico is! List) return [];
    String testo(dynamic v) => v == null ? '' : '$v'.trim();
    return [
      for (final e in storico.whereType<Map>())
        {
          'data': Api.dataBreve(testo(e['data'] ?? e['date'])),
          'ora': testo(e['ora'] ?? e['time']),
          'testo': Api.frase(testo(
              e['commento_personalizzato'] ?? e['commento'] ?? e['descrizione'] ?? e['description'] ?? e['stato'])),
          'luogo': Api.nomeProprio(testo(e['location'] ?? e['luogo'] ?? e['city'])),
        }
    ];
  }

  Future<void> _apriDocumento(Map<String, String> d) async {
    final url = d['url'] ?? '';
    if (url.isEmpty || _scaricando != null) return;
    setState(() => _scaricando = url);
    try {
      final byte = await Api.scarica(url);
      final cartella = await getTemporaryDirectory();
      var nome = Uri.parse(Api.indirizzo(url)).pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => 'documento');
      if (!nome.contains('.')) nome = '$nome.pdf';
      final file = File('${cartella.path}/${widget.id}_$nome');
      await file.writeAsBytes(byte, flush: true);
      final esito = await OpenFilex.open(file.path);
      if (esito.type != ResultType.done && mounted) _avviso(_t.t('documento_non_apribile'));
    } on ErroreApi catch (e) {
      if (mounted) _avviso(e.codice == 'documento_non_disponibile' ? _t.t('documento_non_disponibile') : _t.errore(e.codice));
    } catch (_) {
      if (mounted) _avviso(_t.t('documento_non_apribile'));
    } finally {
      if (mounted) setState(() => _scaricando = null);
    }
  }

  /// Nota 368 V3: chi paga manda l'etichetta al mittente, per email o con la condivisione del telefono.
  Future<void> _etichettaAlMittente() async {
    final t = _t;
    final scelta = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(t.t('etichetta_mittente_testo'), textAlign: TextAlign.center,
                style: const TextStyle(color: Stile.grigio, fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: Stile.verde),
            title: Text(t.t('invia_per_email')),
            onTap: () => Navigator.pop(c, 'email'),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined, color: Stile.verde),
            title: Text(t.t('condividi_whatsapp')),
            onTap: () => Navigator.pop(c, 'whatsapp'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || scelta == null) return;
    if (scelta == 'email') {
      await _etichettaPerEmail();
    } else {
      await _etichettaCondivisa();
    }
  }

  Future<void> _etichettaPerEmail() async {
    final t = _t;
    final mitt = (_sped?['mitt'] as Map?) ?? {};
    final campo = TextEditingController(text: '${mitt['email'] ?? ''}'.trim().toLowerCase());
    final email = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(t.t('invia_etichetta_mittente'), textAlign: TextAlign.center),
        content: TextField(
          controller: campo,
          keyboardType: TextInputType.emailAddress,
          autofocus: campo.text.isEmpty,
          decoration: InputDecoration(labelText: t.t('email_mittente')),
        ),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: Text(t.t('annulla')))),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(c, campo.text.trim().toLowerCase()), child: Text(t.t('invia')))),
          ]),
        ],
      ),
    );
    campo.dispose();
    if (!mounted || email == null) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _avviso(t.t('email_non_valida'));
      return;
    }
    setState(() => _scaricando = 'etichetta');
    try {
      final r = await Api.etichettaAlMittente(widget.id, 'email', email: email);
      if (mounted) _avviso('${r['messaggio'] ?? t.t('etichetta_inviata')}');
    } on ErroreApi catch (e) {
      if (mounted) _avviso(e.messaggio ?? t.errore(e.codice));
    } finally {
      if (mounted) setState(() => _scaricando = null);
    }
  }

  /// Condivisione del telefono (si sceglie WhatsApp): il PDF dell'etichetta e il testo con il
  /// link firmato; se il PDF non si scarica, solo il testo col link.
  Future<void> _etichettaCondivisa() async {
    setState(() => _scaricando = 'etichetta');
    try {
      final r = await Api.etichettaAlMittente(widget.id, 'whatsapp');
      final testo = '${r['testo'] ?? r['link'] ?? ''}';
      final file = <XFile>[];
      final etichetta = _documenti.where((d) => d['tipo'] == 'awb').firstOrNull;
      if (etichetta != null) {
        try {
          final byte = await Api.scarica(etichetta['url']!);
          final cartella = await getTemporaryDirectory();
          final percorso = '${cartella.path}/Etichetta_MOS_${widget.id}.pdf';
          await File(percorso).writeAsBytes(byte, flush: true);
          file.add(XFile(percorso, mimeType: 'application/pdf'));
        } on ErroreApi {
          // resta il link nel testo
        }
      }
      if (!mounted) return;
      final scatola = context.findRenderObject() as RenderBox?;
      final zona = scatola == null ? null : scatola.localToGlobal(Offset.zero) & scatola.size;
      if (file.isEmpty) {
        await Share.share(testo, sharePositionOrigin: zona);
      } else {
        await Share.shareXFiles(file, text: testo, sharePositionOrigin: zona);
      }
    } on ErroreApi catch (e) {
      if (mounted) _avviso(e.messaggio ?? _t.errore(e.codice));
    } finally {
      if (mounted) setState(() => _scaricando = null);
    }
  }

  void _avviso(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo, textAlign: TextAlign.center)));
  }

  static Color _colore(String? esadecimale) {
    final testo = (esadecimale ?? '').replaceAll('#', '').trim();
    final valore = int.tryParse(testo, radix: 16);
    if (testo.length != 6 || valore == null) return Stile.grigio;
    return Color(0xFF000000 | valore);
  }

  String _nomeDocumento(Map<String, String> d) {
    final nome = (d['nome'] ?? '').trim();
    switch (d['tipo']) {
      case 'awb':
        return _t.t('doc_etichetta');
      case 'proforma':
        return _t.t('doc_proforma');
      case 'reso':
        return _t.t('doc_reso');
      default:
        return nome.isNotEmpty ? nome : _t.t('doc_allegato');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      appBar: AppBar(
        title: Text('MOS ${widget.id}'),
        actions: [
          IconButton(tooltip: t.t('aggiorna'), icon: const Icon(Icons.refresh), onPressed: _attesa ? null : _carica),
        ],
      ),
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
                : RefreshIndicator(onRefresh: _carica, child: _contenuto(t)),
      ),
    );
  }

  Widget _contenuto(Testi t) {
    final s = _sped ?? {};
    final colore = _colore(s['colore_stato'] as String?);
    final totale = s['totale'] as num?;
    final colli = ((s['colli'] as List?) ?? []).whereType<Map>().toList();
    final peso = s['peso_tassato'] as num?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: colore), borderRadius: Stile.angoli),
              child: Text('${s['stato'] ?? ''}', style: TextStyle(color: colore, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (totale != null)
              Text(SchermataProfiloState.euro(totale, t.lingua),
                  style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
        if (s['ruolo'] == 'mittente') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Stile.verde.withValues(alpha: 0.10),
              border: const Border(left: BorderSide(color: Stile.verde, width: 4)),
              borderRadius: Stile.angoli,
            ),
            child: Text(t.t('solo_mittente'), style: const TextStyle(fontSize: 13)),
          ),
        ],
        const SizedBox(height: 16),
        _riga(t.t('data_spedizione'), '${s['data'] ?? ''}'),
        _riga(t.t('servizio'), [s['servizio'], s['vettore']].where((v) => v != null && '$v'.isNotEmpty).join(' · ')),
        _riga('AWB', '${s['awb'] ?? ''}'),
        _riga(t.t('colli_titolo'), [
          if (colli.isNotEmpty) '${colli.length}',
          if (peso != null && peso > 0) '${_numero(peso, t.lingua)} kg',
        ].join(' · ')),
        _persona(t.t('mittente'), s['mitt']),
        _persona(t.t('destinatario'), s['dest']),
        const SizedBox(height: 20),
        _titolo(t.t('tracciamento')),
        if (_passaggi.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(t.t('nessun_passaggio'), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
          ),
        for (var i = 0; i < _passaggi.length; i++) _passaggio(_passaggi[i], i == 0),
        if (!widget.vecchia) ...[
          const SizedBox(height: 20),
          _titolo(t.t('documenti_spedizione')),
          if (_documenti.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t.t('nessun_documento'), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
            ),
          for (final d in _documenti)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Stile.verde,
                  side: const BorderSide(color: Stile.verde),
                  shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                ),
                icon: _scaricando == d['url']
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_nomeDocumento(d), overflow: TextOverflow.ellipsis),
                onPressed: () => _apriDocumento(d),
              ),
            ),
          if (s['invia_etichetta_mittente'] == true) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _scaricando == 'etichetta'
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: Text(t.t('invia_etichetta_mittente')),
              onPressed: _scaricando == null ? _etichettaAlMittente : null,
            ),
          ],
        ],
      ],
    );
  }

  static String _numero(num v, String lingua) {
    final testo = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return lingua == 'en' ? testo : testo.replaceAll('.', ',');
  }

  Widget _titolo(String testo) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(testo, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
      );

  Widget _riga(String etichetta, String valore) {
    if (valore.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(etichetta, style: const TextStyle(color: Stile.grigio, fontSize: 13))),
          Expanded(child: Text(valore, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _persona(String etichetta, dynamic dati) {
    if (dati is! Map) return const SizedBox.shrink();
    String nome(dynamic v) => Api.nomeProprio(v == null ? '' : '$v'.trim());
    final righe = [
      nome(dati['societa']),
      nome(dati['contatto']),
      nome(dati['indirizzo']),
      [nome(dati['citta']), nome(dati['nazione'])].where((v) => v.isNotEmpty).join(' · '),
    ].where((v) => v.isNotEmpty).join('\n');
    return _riga(etichetta, righe);
  }

  Widget _passaggio(Map<String, String> p, bool ultimo) {
    final quando = [p['data'], p['ora']].where((v) => v != null && v.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: Icon(Icons.circle, size: 10, color: ultimo ? Stile.verde : Stile.grigio),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['testo'] ?? '', style: TextStyle(fontSize: 13, color: ultimo ? Stile.verde : null)),
                if ((p['luogo'] ?? '').isNotEmpty)
                  Text(p['luogo']!, style: const TextStyle(color: Stile.grigio, fontSize: 12)),
                if (quando.isNotEmpty) Text(quando, style: const TextStyle(color: Stile.grigio, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
