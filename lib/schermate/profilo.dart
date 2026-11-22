import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../servizi/notifiche.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import 'dettaglio_spedizione.dart';
import 'entrata.dart';
import 'le_mie_spedizioni.dart';
import 'mio_profilo.dart';
import 'nuova_spedizione.dart';
import 'pagamenti_fatture.dart';
import 'preventivo.dart';

/// Pagina principale (nota 373 V3): saluto e codice cliente, quattro card (Nuova spedizione,
/// Preventivo veloce, Le mie spedizioni, Fatture e pagamenti), credito solo per i prepagati,
/// ultima spedizione, barra in basso. Il cerchio con le iniziali apre «Il mio profilo».
class SchermataProfilo extends StatefulWidget {
  const SchermataProfilo({super.key});

  @override
  State<SchermataProfilo> createState() => SchermataProfiloState();
}

class SchermataProfiloState extends State<SchermataProfilo> {
  Map<String, dynamic>? _io;
  Map<String, dynamic>? _credito;
  Map<String, dynamic>? _riepilogo;
  Map<String, dynamic>? _ultima;
  String? _errore;
  bool _attesa = true;

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
      final io = await Api.io();
      Map<String, dynamic>? credito;
      try {
        credito = await Api.credito();
      } on ErroreApi {
        credito = {'attivo': false};
      }
      Map<String, dynamic>? ultima;
      Map<String, dynamic>? riepilogo;
      try {
        final r = await Api.leMieSpedizioni();
        final righe = ((r['spedizioni'] as List?) ?? []).cast<Map<String, dynamic>>();
        // le bozze non sono spedizioni partite: si prende la prima vera (nota 373 V8)
        ultima = righe.where((x) => !const {'bozza', 'da_completare'}.contains('${x['tipo']}')).firstOrNull;
        final id = ultima?['id'] as int?;
        if (id != null) {
          try {
            riepilogo = await Api.spedizione(id, vecchia: '${ultima!['tipo']}' == 'vecchia');
          } on ErroreApi catch (e) {
            if (e.codice == 'chiave_non_valida') rethrow;
          }
        }
      } on ErroreApi catch (e) {
        if (e.codice == 'chiave_non_valida') rethrow;
        ultima = null;
      }
      if (!mounted) return;
      setState(() {
        _io = io;
        _credito = credito;
        _ultima = ultima;
        _riepilogo = riepilogo;
      });
      // Notifiche sul telefono: permesso e registrazione (non blocca la schermata)
      Notifiche.attiva(Testi.di(context).lingua);
      // Una notifica toccata ad app chiusa apre ora il dettaglio della spedizione
      Notifiche.profiloPronto();
    } on ErroreApi catch (e) {
      if (e.codice == 'chiave_non_valida') {
        await Api.esci();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SchermataEntrata()));
        return;
      }
      if (mounted) setState(() => _errore = Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  /// € prima dell'importo, separatore delle migliaia: € 1.000,00 (it, es, de) / € 1,000.00 (en) / € 1 000,00 (fr).
  static String euro(num valore, String lingua) {
    final parti = valore.abs().toStringAsFixed(2).split('.');
    final migliaia = lingua == 'en' ? ',' : lingua == 'fr' ? ' ' : '.';
    final decimali = lingua == 'en' ? '.' : ',';
    final intero = parti[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => migliaia);
    return '€ ${valore < 0 ? '-' : ''}$intero$decimali${parti[1]}';
  }

  Future<void> _apri(Widget schermata) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => schermata));
    // credito, ultima spedizione e nome possono essere cambiati
    if (mounted) _carica();
  }

  String get _iniziali {
    final parole = '${_io?['nome_completo'] ?? ''}'.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parole.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return Scaffold(
      appBar: barraApp(context, azioni: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _io == null ? null : () => _apri(const SchermataMioProfilo()),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Stile.verdePulsanti,
              child: Text(_iniziali, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
      body: SafeArea(
        child: _attesa && _io == null
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
      bottomNavigationBar: BarraInBasso(
        attiva: 0,
        apri: (schermata) => _apri(schermata),
      ),
    );
  }

  Widget _contenuto(Testi t) {
    final c = context.colori;
    final nome = '${_io?['nome_completo'] ?? ''}'.trim().split(RegExp(r'\s+')).first;
    final voci = [
      (Icons.public, t.t('nuova_spedizione'), const SchermataNuovaSpedizione() as Widget, false),
      (Icons.calculate_outlined, t.t('preventivo_veloce'), const SchermataPreventivo() as Widget, false),
      (Icons.list_alt_outlined, t.t('le_mie_spedizioni'), const SchermataLeMieSpedizioni() as Widget, false),
      (Icons.receipt_long_outlined, t.t('pagamenti_fatture'), const SchermataPagamentiFatture() as Widget, false),
    ];
    final prepagato = _credito?['attivo'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
      Text('${t.t('ciao')} $nome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.testo)),
      const SizedBox(height: 4),
      Text.rich(TextSpan(children: [
        TextSpan(text: '${t.t('codice_cliente')} ', style: const TextStyle(color: Stile.grigio)),
        TextSpan(text: '${_io?['codice'] ?? '-'}', style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 20),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          for (final (icona, testo, schermata, principale) in voci)
            CardApp(
              onTap: () => _apri(schermata),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: principale ? Stile.verdePulsanti : c.cerchioIcona,
                  child: Icon(icona, size: 28, color: principale || context.temaScuro ? Colors.white : Stile.verdePulsanti),
                ),
                const SizedBox(height: 14),
                // sempre lo spazio di due righe: le quattro icone restano allineate
                SizedBox(
                  height: 44,
                  child: Text(testo,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.testo, height: 1.3)),
                ),
              ]),
            ),
        ],
      ),
      if (prepagato) ...[
        const SizedBox(height: 12),
        CardApp(
          // nota 373 V8: apre direttamente la scheda Credito
          onTap: () => _apri(const SchermataPagamentiFatture(scheda: 1)),
          child: Row(children: [
            Expanded(child: Text(t.t('saldo'), style: const TextStyle(color: Stile.grigio))),
            Text(euro((_credito?['saldo'] as num?) ?? 0, t.lingua),
                style: const TextStyle(color: Stile.verde, fontSize: 22, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
      if (_ultima != null) ...[
        const SizedBox(height: 12),
        _UltimaSpedizione(riga: _ultima!, riepilogo: _riepilogo, apri: _apri),
      ],
    ]);
  }
}

/// Nota 373 V8: in alto «Ultima spedizione» e, a destra, MOS e data; sotto mittente e
/// destinatario con nome, CAP, citta' e nazione; in basso a destra «Apri».
class _UltimaSpedizione extends StatelessWidget {
  const _UltimaSpedizione({required this.riga, required this.riepilogo, required this.apri});

  final Map<String, dynamic> riga;
  final Map<String, dynamic>? riepilogo;
  final Future<void> Function(Widget) apri;

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final c = context.colori;
    final id = riga['id'] as int?;
    final tipo = '${riga['tipo']}';
    final mitt = riepilogo?['mitt'] as Map?;
    final dest = riepilogo?['dest'] as Map? ??
        {'societa': riga['destinatario'], 'citta': riga['dest_citta'], 'nazione': riga['dest_codice_nazione']};
    final data = riga['data'] ?? riepilogo?['data'];
    return CardApp(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(t.t('ultima_spedizione'), style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('MOS ${_mos(riga['mos'] ?? riga['id'])}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.testo)),
            if (data != null) Text('$data', style: const TextStyle(color: Stile.grigio, fontSize: 13)),
          ]),
        ]),
        const SizedBox(height: 10),
        if (mitt != null) _lato(context, t.t('mittente'), mitt),
        _lato(context, t.t('destinatario'), dest),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(96, 38)),
              onPressed: id == null ? null : () => apri(SchermataDettaglioSpedizione(id: id, vecchia: tipo == 'vecchia')),
              child: Text(t.t('apri')),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _lato(BuildContext context, String etichetta, Map dati) {
    String nome(dynamic v) => Api.nomeProprio(v == null ? '' : '$v'.trim());
    final chi = nome(dati['societa']).isNotEmpty ? nome(dati['societa']) : nome(dati['contatto']);
    final dove = [nome(dati['citta']), nome(dati['nazione'])].where((v) => v.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(etichetta, style: const TextStyle(color: Stile.grigio, fontSize: 13))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (chi.isNotEmpty)
              Text(chi, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colori.testo)),
            if (dove.isNotEmpty) Text(dove, style: const TextStyle(color: Stile.grigio, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  /// MOS a gruppi: 5557171 -> 555 7171
  static String _mos(dynamic v) {
    final s = '$v';
    return s.length == 7 ? '${s.substring(0, 3)} ${s.substring(3)}' : s;
  }
}

/// Riquadro con bordo sottile e angoli a 2 px, nei colori del tema.
class CardApp extends StatelessWidget {
  const CardApp({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: Stile.angoli, side: BorderSide(color: c.bordo)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Barra in basso: Home, Spedizioni, Fatture e pagamenti, Profilo.
class BarraInBasso extends StatelessWidget {
  const BarraInBasso({super.key, required this.attiva, required this.apri});

  final int attiva;
  final void Function(Widget schermata) apri;

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return NavigationBar(
      selectedIndex: attiva,
      onDestinationSelected: (i) {
        if (i == attiva) return;
        switch (i) {
          case 1:
            apri(const SchermataLeMieSpedizioni());
          case 2:
            apri(const SchermataPagamentiFatture());
          case 3:
            apri(const SchermataMioProfilo());
        }
      },
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.t('home')),
        NavigationDestination(icon: const Icon(Icons.local_shipping_outlined), label: t.t('spedizioni')),
        // nella barra il nome completo andrebbe su due righe: qui la sola prima parola
        NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), label: t.t('fatture')),
        NavigationDestination(icon: const Icon(Icons.person_outline), label: t.t('profilo')),
      ],
    );
  }
}
