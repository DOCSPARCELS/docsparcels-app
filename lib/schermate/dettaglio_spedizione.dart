import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../widget/barra.dart';
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

  /// Nota 373 V8: «Invia etichetta» per chiunque veda la spedizione (se l'etichetta c'e').
  /// Si sceglie WhatsApp o email; numero ed email sono quelli del mittente, modificabili.
  /// Stesse funzioni della nota 368 (link all'etichetta che non scade).
  Future<void> _inviaEtichetta() async {
    final t = _t;
    final scelta = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(t.t('invia_etichetta_testo'), textAlign: TextAlign.center,
                style: const TextStyle(color: Stile.grigio, fontSize: 13)),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined, color: Stile.verde),
            title: Text(t.t('whatsapp')),
            onTap: () => Navigator.pop(c, 'whatsapp'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: Stile.verde),
            title: Text(t.t('invia_per_email')),
            onTap: () => Navigator.pop(c, 'email'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted || scelta == null) return;
    final mitt = (_sped?['mitt'] as Map?) ?? {};
    final perEmail = scelta == 'email';
    final iniziale = perEmail
        ? '${mitt['email'] ?? ''}'.trim().toLowerCase()
        : (_sped?['whatsapp_mittente'] != null ? '+${_sped!['whatsapp_mittente']}' : '${mitt['telefono'] ?? ''}'.trim());
    final valore = await _chiediRecapito(
      titolo: t.t('invia_etichetta'),
      etichetta: perEmail ? t.t('email_mittente') : t.t('numero_whatsapp'),
      iniziale: iniziale,
      tastiera: perEmail ? TextInputType.emailAddress : TextInputType.phone,
      pulsante: perEmail ? t.t('invia') : t.t('apri_whatsapp'),
    );
    if (!mounted || valore == null) return;
    if (perEmail) {
      final email = valore.toLowerCase();
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
      return;
    }
    setState(() => _scaricando = 'etichetta');
    try {
      final r = await Api.etichettaAlMittente(widget.id, 'whatsapp', telefono: valore.isEmpty ? null : valore);
      final indirizzo = '${r['whatsapp'] ?? ''}';
      var aperto = false;
      if (indirizzo.isNotEmpty) {
        try {
          aperto = await launchUrl(Uri.parse(indirizzo), mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
      if (!aperto && mounted) {
        // senza numero valido (o senza WhatsApp): testo con il link condiviso dal telefono
        final scatola = context.findRenderObject() as RenderBox?;
        final zona = scatola == null ? null : scatola.localToGlobal(Offset.zero) & scatola.size;
        await Share.share('${r['testo'] ?? r['link'] ?? ''}', sharePositionOrigin: zona);
      }
    } on ErroreApi catch (e) {
      if (mounted) _avviso(e.messaggio ?? t.errore(e.codice));
    } finally {
      if (mounted) setState(() => _scaricando = null);
    }
  }

  Future<String?> _chiediRecapito(
      {required String titolo,
      required String etichetta,
      required String iniziale,
      required TextInputType tastiera,
      required String pulsante}) async {
    final t = _t;
    final campo = TextEditingController(text: iniziale);
    final valore = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(titolo, textAlign: TextAlign.center),
        content: TextField(
          controller: campo,
          keyboardType: tastiera,
          autofocus: campo.text.isEmpty,
          decoration: InputDecoration(labelText: etichetta),
        ),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), child: Text(t.t('annulla')))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, campo.text.trim()), child: Text(pulsante))),
          ]),
        ],
      ),
    );
    // il campo si libera solo a finestra chiusa del tutto (durante l'animazione di uscita e' ancora in uso)
    Future.delayed(const Duration(seconds: 1), campo.dispose);
    return valore;
  }

  void _avviso(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo, textAlign: TextAlign.center)));
  }

  /// MOS a gruppi: 5557171 -> 555 7171
  static String _mosGruppi(int mos) {
    final s = '$mos';
    return s.length == 7 ? '${s.substring(0, 3)} ${s.substring(3)}' : s;
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
      appBar: barraApp(context, titolo: 'MOS ${_mosGruppi(widget.id)}', azioni: [
        IconButton(tooltip: t.t('aggiorna'), icon: const Icon(Icons.refresh), onPressed: _attesa ? null : _carica),
      ]),
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
    final totale = s['totale'] as num?;
    final colli = ((s['colli'] as List?) ?? []).whereType<Map>().toList();
    final peso = s['peso_tassato'] as num?;
    final etichetta = _documenti.where((d) => d['tipo'] == 'awb').firstOrNull;
    final invia = s['invia_etichetta_mittente'] == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nota 373 V13: i pulsanti sopra il costo, come nel gestionale: «Invia» viola, «Etichetta» bianco
        if (!widget.vecchia && (invia || etichetta != null)) ...[
          Row(children: [
            if (invia)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: _scaricando == 'etichetta'
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 18),
                  label: Text(t.t('invia')),
                  onPressed: _scaricando == null ? _inviaEtichetta : null,
                ),
              ),
            if (invia && etichetta != null) const SizedBox(width: 10),
            if (etichetta != null)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E1E1E),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: _scaricando == etichetta['url']
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf, size: 20, color: Color(0xFFFA0F00)),
                  label: Text(t.t('doc_etichetta_breve')),
                  onPressed: _scaricando == null ? () => _apriDocumento(etichetta) : null,
                ),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        // Nota 373 V8: niente stato qui (c'e' il tracciamento sotto); importo a destra con la sua scritta
        if (totale != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(t.t('costo_spedizione'), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
              const SizedBox(width: 10),
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
                    : const Icon(Icons.picture_as_pdf_outlined, color: Stile.rossoLeggero),
                label: Text(_nomeDocumento(d), overflow: TextOverflow.ellipsis),
                onPressed: () => _apriDocumento(d),
              ),
            ),
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
      '${dati['email'] ?? ''}'.trim().toLowerCase(),
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
