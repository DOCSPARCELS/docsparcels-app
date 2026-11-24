import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../servizi/api.dart';
import '../servizi/notifiche.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import '../widget/icona_ritiro.dart';
import 'dettaglio_spedizione.dart';
import 'entrata.dart';
import 'le_mie_spedizioni.dart';
import 'mio_profilo.dart';
import 'nuova_spedizione.dart';
import 'pagamenti_fatture.dart';
import 'prenota_ritiro.dart';
import 'ritiri.dart';
import 'preventivo.dart';
import '../widget/striscia_servizio.dart';

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
  /// Nota 373 V18: le ultime 5 spedizioni, quante fatture ci sono e quante sono da pagare
  List<Map<String, dynamic>> _ultime = [];
  int _fattureTotali = 0;
  int _fattureDaPagare = 0;
  double _totaleDaPagare = 0;
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
      var ultime = <Map<String, dynamic>>[];
      try {
        final r = await Api.leMieSpedizioni();
        final righe = ((r['spedizioni'] as List?) ?? []).cast<Map<String, dynamic>>();
        // le bozze non sono spedizioni partite (nota 373 V8)
        ultime = righe.where((x) => !const {'bozza', 'da_completare'}.contains('${x['tipo']}')).take(5).toList();
      } on ErroreApi catch (e) {
        if (e.codice == 'chiave_non_valida') rethrow;
      }
      // Nota 373 V22: le due letture sono separate, una che non riesce non fa sparire la card Fatture
      var fattureTotali = _fattureTotali;
      var daPagare = _fattureDaPagare;
      var totaleDaPagare = _totaleDaPagare;
      try {
        fattureTotali = ((await Api.fatture(perPagina: 1))['totale_fatture'] as num?)?.toInt() ?? 0;
      } on ErroreApi catch (e) {
        if (e.codice == 'chiave_non_valida') rethrow;
      }
      try {
        final f = ((await Api.pagamentiAperti())['fatture'] as Map?) ?? {};
        daPagare = (f['quante'] as num?)?.toInt() ?? 0;
        totaleDaPagare = (f['totale'] as num?)?.toDouble() ?? 0;
      } on ErroreApi catch (e) {
        if (e.codice == 'chiave_non_valida') rethrow;
      }
      if (!mounted) return;
      setState(() {
        _io = io;
        _credito = credito;
        _ultime = ultime;
        _fattureTotali = fattureTotali;
        _fattureDaPagare = daPagare;
        _totaleDaPagare = totaleDaPagare;
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

  /// Regola di Luca (nota 373 V22): chi ha almeno una fattura, anche pagata, le vede tutte
  bool get _haFatture => _fattureTotali > 0 || _fattureDaPagare > 0;

  /// Nota 373 V18: la sezione mostra solo le schede che il cliente ha (fatture, credito)
  Widget _sezionePagamenti({int scheda = 0}) => SchermataPagamentiFatture(
      scheda: scheda, conFatture: _haFatture, conCredito: _credito?['attivo'] == true);

  String get _iniziali {
    final parole = '${_io?['nome_completo'] ?? ''}'.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parole.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return Scaffold(
      // Nota 390: nel tema chiaro lo sfondo della home e' un po' piu' scuro del bianco
      backgroundColor: context.temaScuro ? null : Stile.sfondoHomeChiaro,
      appBar: barraApp(context,
          fondo: context.temaScuro ? context.colori.fondo : Stile.sfondoHomeChiaro, azioni: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _io == null ? null : () => _apri(const SchermataMioProfilo()),
            // 23.11.26: cerchio dell'avatar col bordo sfumato, come i cerchi delle voci
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    for (final a in const [1.0, 1.0, 0.7, 0.3, 0.0]) Stile.verdePulsanti.withValues(alpha: a),
                  ],
                  stops: const [0.0, 0.72, 0.84, 0.93, 1.0],
                ),
              ),
              alignment: Alignment.center,
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
        codiceCliente: '${_io?['codice'] ?? ''}',
        apri: (schermata) => _apri(schermata),
      ),
    );
  }

  /// Nota 390 (V4): le quattro voci non hanno riquadro ne' angoli, in tutti e due i temi:
  /// una zona chiara che sfuma fino a sparire prima dei bordi e si fonde con lo sfondo.
  /// Margine ai lati dei quattro quadrati e del riquadro del credito (24.11.26)
  /// 24.11.26 (2): rientro oltre i 16 della pagina, cosi' il margine esterno (16+8) e' uguale
  /// allo spazio fra i quadrati e sotto di loro (_spazioVoci)
  static const double _margineVoci = 8;
  static const double _spazioVoci = 24;

  Color get _fondoVoce => context.temaScuro ? context.colori.card : Stile.voceHomeChiaro;

  /// 24.11.26: le quattro voci tornano quadrati, pieni, senza bordo ne' sfumatura
  Widget _voceHome({required VoidCallback onTap, required Widget child}) => Material(
        color: _fondoVoce,
        borderRadius: Stile.angoli,
        child: InkWell(borderRadius: Stile.angoli, onTap: onTap, child: child),
      );

  /// 23.11.26: le icone della home con la stessa sfumatura del globo del logo
  /// (verde acqua chiaro in alto a sinistra, verde smeraldo scuro in basso a destra)
  /// Piene e con il bordo d'ombra scuro in basso a destra, come i continenti del globo:
  /// sembrano immagini, non disegni a linee.
  static Widget _comeIlGlobo(Widget icona) => Stack(clipBehavior: Clip.none, children: [
        Transform.translate(
          offset: const Offset(1.6, 1.6),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Color(0xFF002E25), BlendMode.srcIn),
            child: icona,
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (area) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1BE3BA), Color(0xFF0FC9A4), Color(0xFF008369), Color(0xFF00624F)],
            stops: [0.0, 0.35, 0.75, 1.0],
          ).createShader(area),
          child: icona,
        ),
      ]);

  /// Sfuma solo gli ultimi [larghezza] pixel di ogni lato: il riquadro resta rettangolare
  static Widget _bordiSfumati(Widget figlio, {double larghezza = 10}) {
    Shader bordo(Rect area, bool orizzontale) {
      final lato = orizzontale ? area.width : area.height;
      final f = lato <= 0 ? 0.0 : (larghezza / lato).clamp(0.0, 0.5);
      return LinearGradient(
        begin: orizzontale ? Alignment.centerLeft : Alignment.topCenter,
        end: orizzontale ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, f, 1 - f, 1.0],
      ).createShader(area);
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (area) => bordo(area, true),
      child: ShaderMask(blendMode: BlendMode.dstIn, shaderCallback: (area) => bordo(area, false), child: figlio),
    );
  }

  Widget _contenuto(Testi t) {
    final c = context.colori;
    final nome = '${_io?['nome_completo'] ?? ''}'.trim().split(RegExp(r'\s+')).first;
    // Nota 373 V18: in basso a sinistra «Prenota ritiro», a destra «Le mie spedizioni»
    final voci = [
      // 23.11.26: Nuova spedizione col globo del logo (nei suoi colori); le altre Material Symbols
      // col tratto sottile (le icone Material ingrandite sembravano in grassetto)
      (Image.asset('assets/immagini/globo_avvio_android12.png', width: 80, height: 80) as Widget,
          t.t('home_spedizione'), const SchermataNuovaSpedizione() as Widget),
      (_comeIlGlobo(const Icon(Symbols.calculate, fill: 1, weight: 500)), t.t('home_preventivo'), const SchermataPreventivo() as Widget),
      (_comeIlGlobo(const IconaRitiro(size: 48)), t.t('prenota_ritiro'), const SchermataPrenotaRitiro() as Widget),
      (_comeIlGlobo(const Icon(Symbols.list_alt, fill: 1, weight: 500)), t.t('le_mie_spedizioni'), const SchermataLeMieSpedizioni() as Widget),
    ];
    final prepagato = _credito?['attivo'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 24), children: [
      // 23.11.26: saluto e codice cliente centrati
      Text('${t.t('ciao')} $nome',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.testo)),
      const SizedBox(height: 4),
      Text.rich(TextSpan(children: [
        TextSpan(text: '${t.t('codice_cliente')} ', style: TextStyle(color: Stile.grigio)),
        TextSpan(text: '${_io?['codice'] ?? '-'}', style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
      ]), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      // 24.11.26: quadrati piu' piccoli di una volta, con un po' di margine ai lati
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: _margineVoci),
        child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: _spazioVoci,
        crossAxisSpacing: _spazioVoci,
        childAspectRatio: 1.15,
        children: [
          for (final (icona, testo, schermata) in voci)
            _voceHome(
              onTap: () => _apri(schermata),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // 24.11.26: niente sfere dietro le icone, solo l'icona
                SizedBox(
                  height: 64,
                  child: Center(
                    child: IconTheme.merge(
                  data: IconThemeData(
                      size: 44, weight: 250, color: context.temaScuro ? Stile.verde : Stile.verdePulsanti),
                  child: icona,
                ),
                  ),
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
      ),
      if (prepagato) ...[
        const SizedBox(height: _spazioVoci),
        // 23.11.26: riquadro del credito coi bordi leggermente sfumati (solo il fondo, le scritte no),
        // largo quanto i quattro quadrati (stesso margine ai lati)
        LayoutBuilder(builder: (context, spazio) {
          const rientro = _margineVoci;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: rientro),
            // 24.11.26: fondo pieno come i quattro quadrati, senza sfumatura
            child: Stack(children: [
          Material(
            color: _fondoVoce,
            borderRadius: Stile.angoli,
            child: InkWell(
              borderRadius: Stile.angoli,
              // nota 373 V8: apre direttamente la scheda Credito
              onTap: () => _apri(_sezionePagamenti(scheda: 1)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // 23.11.26: stessa grandezza delle scritte delle quattro voci (16), colori di prima
                  Expanded(child: Text(t.t('saldo'), style: TextStyle(color: Stile.grigio, fontSize: 16))),
                  Text(euro((_credito?['saldo'] as num?) ?? 0, t.lingua),
                      style: const TextStyle(color: Stile.verde, fontSize: 16, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ]),
          );
        }),
      ],
      // Nota 373 V22: sempre, se il cliente ha fatture; con quante e quanto se ce ne sono da pagare
      if (_haFatture) ...[
        const SizedBox(height: 12),
        CardApp(
          onTap: () => _apri(_sezionePagamenti()),
          child: Row(children: [
            Expanded(
              child: Text(
                  _fattureDaPagare > 0
                      ? '${t.t('fatture')} · $_fattureDaPagare ${t.t('da_pagare').toLowerCase()}'
                      : t.t('fatture'),
                  style: TextStyle(color: Stile.grigio)),
            ),
            if (_fattureDaPagare > 0)
              Text(euro(_totaleDaPagare, t.lingua),
                  style: const TextStyle(color: Stile.rosso, fontSize: 22, fontWeight: FontWeight.w700))
            else
              Icon(Icons.chevron_right, color: Stile.grigio),
          ]),
        ),
      ],
      if (_ultime.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(t.t('ultime_spedizioni'), style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final riga in _ultime)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _UltimaSpedizione(riga: riga, apri: _apri),
          ),
      ],
    ]);
  }
}

/// Nota 373 V18: una delle ultime spedizioni. MOS e data, mittente e destinatario, servizio
/// con la sua striscia e lo stato; una freccina a destra, si apre toccando la card.
class _UltimaSpedizione extends StatelessWidget {
  const _UltimaSpedizione({required this.riga, required this.apri});

  final Map<String, dynamic> riga;
  final Future<void> Function(Widget) apri;

  static const _arancio = Color(0xFFFF9800);

  static Color _colore(String? esadecimale) {
    final testo = (esadecimale ?? '').replaceAll('#', '').trim();
    final valore = int.tryParse(testo, radix: 16);
    if (testo.length != 6 || valore == null) return Stile.grigio;
    return Color(0xFF000000 | valore);
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final c = context.colori;
    final id = riga['id'] as int?;
    final tipo = '${riga['tipo']}';
    final lavorazione = riga['da_pagare'] == true || tipo == 'richiesta';
    final colore = lavorazione ? _arancio : _colore(riga['colore'] as String?);
    final scuro = context.temaScuro ? colore : (Color.lerp(colore, Colors.black, 0.35) ?? colore);
    final stato = lavorazione ? t.t('in_lavorazione') : '${riga['stato'] ?? ''}'.trim();
    final servizio = '${riga['servizio'] ?? ''}'.trim();
    return CardApp(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      onTap: id == null ? null : () => apri(SchermataDettaglioSpedizione(id: id, vecchia: tipo == 'vecchia')),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'MOS ', style: TextStyle(color: c.grigioLeggero, fontWeight: FontWeight.w500)),
                      TextSpan(text: _mos(riga['mos'] ?? riga['id'])),
                    ]),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.testo)),
              ),
              if (riga['data'] != null) Text('${riga['data']}', style: TextStyle(color: Stile.grigio, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            _lato(context, t.t('mittente'), riga['mittente'], riga['mitt_cap'], riga['mitt_citta'],
                riga['mitt_nazione'] ?? riga['mitt_codice_nazione']),
            _lato(context, t.t('destinatario'), riga['destinatario'], riga['dest_cap'], riga['dest_citta'],
                riga['dest_nazione'] ?? riga['dest_codice_nazione']),
            const SizedBox(height: 2),
            Row(children: [
              if (servizio.isNotEmpty) ...[
                StrisciaServizio(colore: StrisciaServizio.daTesto(riga['colore_servizio']), larghezza: 24, altezza: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(servizio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.testo)),
                ),
              ] else
                const Spacer(),
              // lo stato sempre a destra (fino a mezza riga, poi va a capo)
              if (stato.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.42),
                  child: Text(stato,
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scuro, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          ]),
        ),
        Icon(Icons.chevron_right, color: Stile.grigio),
      ]),
    );
  }

  Widget _lato(BuildContext context, String etichetta, dynamic nome, dynamic cap, dynamic citta, dynamic nazione) {
    String pulito(dynamic v) => Api.nomeProprio(v == null ? '' : '$v'.trim());
    final chi = pulito(nome);
    final luogo = [cap == null ? '' : '$cap'.trim(), pulito(citta)].where((v) => v.isNotEmpty).join(' ');
    final dove = [luogo, pulito(nazione)].where((v) => v.isNotEmpty).join(' · ');
    if (chi.isEmpty && dove.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(etichetta, style: TextStyle(color: Stile.grigio, fontSize: 12))),
        Expanded(
          child: Text([chi, dove].where((v) => v.isNotEmpty).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.colori.testo)),
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
  const CardApp({super.key, required this.child, this.onTap, this.bordo = true, this.padding = const EdgeInsets.all(16)});

  final bool bordo;

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
          borderRadius: Stile.angoli, side: bordo ? BorderSide(color: c.bordo) : BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Barra in basso: Home, Spedizioni, Ritiri, Contatti (24.11.26: al posto di Profilo, che resta nell'avatar).
class BarraInBasso extends StatelessWidget {
  const BarraInBasso({super.key, required this.attiva, required this.apri, this.codiceCliente = ''});

  /// Per togliere dalla rubrica la propria scheda
  final String codiceCliente;

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
            apri(const SchermataRitiri());
          case 3:
            apri(SchermataRubrica(codiceCliente: codiceCliente));
        }
      },
      destinations: [
        NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.t('home')),
        NavigationDestination(icon: const Icon(Icons.public), label: t.t('spedizioni')),
        // nella barra il nome completo andrebbe su due righe: qui la sola prima parola
        // nota 373 V23: «Ritiri», apre l'elenco
        NavigationDestination(icon: const IconaRitiro(size: 28), label: t.t('ritiri')),
        NavigationDestination(
            icon: const Icon(Icons.contacts_outlined), selectedIcon: const Icon(Icons.contacts), label: t.t('contatti')),
      ],
    );
  }
}
