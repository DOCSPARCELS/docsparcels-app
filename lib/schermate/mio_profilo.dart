import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../servizi/api.dart';
import '../servizi/lingua.dart';
import '../stile.dart';
import '../widget/barra.dart';
import '../testi.dart';
import '../widget/scelta_nazione.dart';
import 'entrata.dart';
import 'profilo.dart';
import '../widget/scelta_tema.dart';

/// Il mio profilo (nota 372): account, la mia scheda, rubrica, lingua. Come «Il mio profilo» e
/// «La mia scheda» del sito; i dati fiscali nell'app sono solo da vedere.
class SchermataMioProfilo extends StatefulWidget {
  const SchermataMioProfilo({super.key});

  @override
  State<SchermataMioProfilo> createState() => _SchermataMioProfiloState();
}

String _testo(dynamic v) => v == null ? '' : '$v'.trim();

Future<void> _esitoErrore(BuildContext context, ErroreApi e) async {
  if (e.codice == 'chiave_non_valida') {
    await Api.esci();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
    return;
  }
  if (!context.mounted) return;
  _avviso(context, e.messaggio ?? Testi.di(context).errore(e.codice));
}

void _avviso(BuildContext context, String testo) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo, textAlign: TextAlign.center)));

class _SchermataMioProfiloState extends State<SchermataMioProfilo> {
  Map<String, dynamic>? _account;
  Map<String, dynamic>? _scheda;
  Map<String, String> _intestazioni = {};
  bool _attesa = true;
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
      final r = await Future.wait([Api.mioAccount(), Api.miaScheda(), Api.intestazioniImmagine()]);
      if (!mounted) return;
      setState(() {
        _account = r[0];
        _scheda = r[1];
        _intestazioni = r[2].cast<String, String>();
      });
    } on ErroreApi catch (e) {
      if (!mounted) return;
      await _esitoErrore(context, e);
      if (mounted) setState(() => _errore = e.messaggio ?? Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  // ------------------------------------------------------------------ account

  Future<void> _modificaAccount() async {
    final t = Testi.di(context);
    final a = _account ?? {};
    final nome = TextEditingController(text: _testo(a['nome']));
    final cognome = TextEditingController(text: _testo(a['cognome']));
    final email = TextEditingController(text: _testo(a['email']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(t.t('il_mio_account'), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nome, decoration: InputDecoration(labelText: t.t('nome'))),
            const SizedBox(height: 12),
            TextField(controller: cognome, decoration: InputDecoration(labelText: t.t('cognome'))),
            const SizedBox(height: 12),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: t.t('email_campo'))),
          ]),
        ),
        actions: [_dueBottoni(c, t.t('annulla'), t.t('salva'))],
      ),
    );
    final valori = [nome.text.trim(), cognome.text.trim(), email.text.trim().toLowerCase()];
    Future.delayed(const Duration(seconds: 1), () {
      nome.dispose();
      cognome.dispose();
      email.dispose();
    });
    if (ok != true || !mounted) return;
    try {
      await Api.salvaAccount(valori[0], valori[1], valori[2]);
      _cambiato = true;
      if (mounted) _avviso(context, t.t('salvato'));
      await _carica();
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    }
  }

  Future<void> _cambiaPassword() async {
    final t = Testi.di(context);
    final campi = [TextEditingController(), TextEditingController(), TextEditingController()];
    final etichette = [t.t('password_attuale'), t.t('password_nuova'), t.t('password_conferma')];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(t.t('cambia_password'), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++) ...[
              TextField(controller: campi[i], obscureText: true, decoration: InputDecoration(labelText: etichette[i])),
              if (i < 2) const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(t.t('password_regola'), style: const TextStyle(color: Stile.grigio, fontSize: 12)),
          ]),
        ),
        actions: [_dueBottoni(c, t.t('annulla'), t.t('salva'))],
      ),
    );
    final valori = campi.map((c) => c.text).toList();
    Future.delayed(const Duration(seconds: 1), () {
      for (final c in campi) {
        c.dispose();
      }
    });
    if (ok != true || !mounted) return;
    try {
      await Api.cambiaPassword(valori[0], valori[1], valori[2]);
      if (mounted) _avviso(context, t.t('password_cambiata'));
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    }
  }

  Future<void> _foto() async {
    final t = Testi.di(context);
    final haFoto = _account?['foto'] != null;
    final scelta = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Stile.verde),
              title: Text(t.t('scegli_foto')),
              onTap: () => Navigator.pop(c, 'galleria')),
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Stile.verde),
              title: Text(t.t('scatta_foto')),
              onTap: () => Navigator.pop(c, 'fotocamera')),
          if (haFoto)
            ListTile(
                leading: const Icon(Icons.delete_outline, color: Stile.rosso),
                title: Text(t.t('togli_foto')),
                onTap: () => Navigator.pop(c, 'togli')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (scelta == null || !mounted) return;
    try {
      if (scelta == 'togli') {
        await Api.togliFoto();
      } else {
        final file = await ImagePicker().pickImage(
            source: scelta == 'galleria' ? ImageSource.gallery : ImageSource.camera,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 88);
        if (file == null) return;
        await Api.caricaFoto(await file.readAsBytes(), file.name);
      }
      _cambiato = true;
      await _carica();
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    } catch (_) {
      if (mounted) _avviso(context, t.t('foto_non_caricata'));
    }
  }

  Future<void> _eliminaAccount() async {
    final t = Testi.di(context);
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        title: Text(t.t('elimina_account'), textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t.t('elimina_account_testo'), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: t.t('password'))),
        ]),
        actions: [_dueBottoni(c, t.t('annulla'), t.t('elimina'), rosso: true)],
      ),
    );
    final valore = password.text;
    Future.delayed(const Duration(seconds: 1), password.dispose);
    if (ok != true || !mounted) return;
    try {
      await Api.eliminaAccount(valore);
      await Api.esci();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    }
  }

  // ------------------------------------------------------------------ lingua

  /// Esci da questo telefono (prima era nella pagina principale)
  Future<void> _esci() async {
    final t = Testi.di(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        content: Text(t.t('conferma_uscita'), textAlign: TextAlign.center),
        actions: [_dueBottoni(c, t.t('no'), t.t('si'))],
      ),
    );
    if (si != true || !mounted) return;
    await Api.esci();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SchermataEntrata()), (_) => false);
  }

  Future<void> _lingua(String lingua) async {
    await LinguaApp.imposta(lingua);
    try {
      await Api.cambiaLingua(lingua);
    } on ErroreApi catch (_) {
      // l'app cambia lo stesso: le notifiche restano nella lingua di prima
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fatto, _) {
        if (!fatto) Navigator.of(context).pop(_cambiato);
      },
      child: Scaffold(
        appBar: barraApp(context, titolo: t.t('il_mio_profilo')),
        body: SafeArea(
          child: _attesa && _account == null
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
      ),
    );
  }

  Widget _contenuto(Testi t) {
    final a = _account ?? {};
    final s = _scheda ?? {};
    final mod = (s['modificabili'] as Map?)?.cast<String, dynamic>() ?? {};
    final fisc = (s['solo_lettura'] as Map?)?.cast<String, dynamic>() ?? {};
    final cond = (s['condizioni'] as Map?)?.cast<String, dynamic>() ?? {};
    final foto = a['foto'] as String?;
    final iniziali = [a['nome'], a['cognome']]
        .map((v) => _testo(v))
        .where((v) => v.isNotEmpty)
        .map((v) => v[0].toUpperCase())
        .join();
    return ListView(padding: const EdgeInsets.all(16), children: [
      // --------------------------------------------------------- account
      _Titolo(t.t('il_mio_account')),
      Row(children: [
        GestureDetector(
          onTap: _foto,
          child: Stack(children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Stile.verdePulsanti,
              foregroundImage: foto == null ? null : NetworkImage('${Config.indirizzo}$foto', headers: _intestazioni),
              child: Text(iniziali.isEmpty ? '?' : iniziali, style: const TextStyle(color: Colors.white, fontSize: 22)),
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(radius: 12, backgroundColor: Stile.verde, child: Icon(Icons.edit, size: 14, color: Colors.white)),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_testo(a['nome'])} ${_testo(a['cognome'])}'.trim(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(_testo(a['email']), style: const TextStyle(color: Stile.grigio, fontSize: 13)),
          ]),
        ),
        IconButton(tooltip: t.t('modifica'), icon: const Icon(Icons.edit_outlined, color: Stile.verde), onPressed: _modificaAccount),
      ]),
      const SizedBox(height: 12),
      _Riga(t.t('nome_utente'), _testo(a['nome_utente'])),
      _Riga(t.t('codice_cliente'), _testo(a['codice'])),
      _Riga(t.t('registrato_il'), _testo(a['registrato_il']).split(' - ').first),
      _Riga(t.t('ultimo_accesso'), _testo(a['ultimo_accesso']).replaceAll(' - ', ' · ')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        icon: const Icon(Icons.lock_outline),
        label: Text(t.t('cambia_password')),
        onPressed: _cambiaPassword,
      ),
      const SizedBox(height: 28),

      // --------------------------------------------------------- la mia scheda
      Row(children: [
        Expanded(child: _Titolo(t.t('la_mia_scheda'))),
        IconButton(
          tooltip: t.t('modifica'),
          icon: const Icon(Icons.edit_outlined, color: Stile.verde),
          onPressed: s['id'] == null
              ? null
              : () async {
                  final salvato = await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => SchermataContatto(id: s['id'] as int, iniziale: mod, propria: true)));
                  if (salvato == true) _carica();
                },
        ),
      ]),
      _Sottotitolo(t.t('indirizzo_operativo')),
      _Riga(t.t('societa'), _testo(mod['societa_op'])),
      _Riga(t.t('referente'), _testo(mod['resp_settore_op'])),
      _Riga(t.t('indirizzo'), [mod['indirizzo_op'], mod['indirizzo2_op']].map(_testo).where((v) => v.isNotEmpty).join(', ')),
      _Riga(t.t('localita'),
          [mod['cap_op'], mod['citta_op'], mod['provincia_op']].map(_testo).where((v) => v.isNotEmpty).join(' · ')),
      _Riga(t.t('nazione'), _testo(mod['nazione_op'])),
      _Riga(t.t('telefono'), _testo(mod['telefono_op'])),
      _Riga(t.t('email_campo'), _testo(mod['email_op'])),
      _Sottotitolo(t.t('ritiro_abituale')),
      _Riga(t.t('mattino'), _fascia(mod['ritiro_ora_mattino_dalle'], mod['ritiro_ora_mattino_alle'])),
      _Riga(t.t('pomeriggio'), _fascia(mod['ritiro_ora_pomeriggio_dalle'], mod['ritiro_ora_pomeriggio_alle'])),
      _Riga(t.t('pronti_dalle'), _testo(mod['ritiro_ora_pronti_dalle'])),
      _Riga(t.t('punto_ritiro'), _testo(mod['ritiro_punto'])),
      _Riga(t.t('note_ritiro'), _testo(mod['ritiro_istruzioni_note'])),
      _Sottotitolo(t.t('dati_fiscali')),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.t('dati_fiscali_dal_sito'), style: const TextStyle(color: Stile.grigio, fontSize: 12)),
      ),
      _Riga(t.t('sede_legale'), [
        fisc['societa_leg'],
        [fisc['indirizzo_leg'], fisc['indirizzo2_leg']].map(_testo).where((v) => v.isNotEmpty).join(', '),
        [fisc['cap_leg'], fisc['citta_leg'], fisc['provincia_leg']].map(_testo).where((v) => v.isNotEmpty).join(' · '),
        fisc['nazione_leg'],
      ].map(_testo).where((v) => v.isNotEmpty).join('\n')),
      _Riga(t.t('partita_iva'), _testo(fisc['partita_iva'])),
      _Riga(t.t('codice_fiscale'), _testo(fisc['codice_fiscale'])),
      _Riga('PEC', _testo(fisc['pec']).toLowerCase()),
      _Riga('SDI', _testo(fisc['codice_univoco'])),
      _Riga('EORI', _testo(fisc['codice_eori'])),
      _Sottotitolo(t.t('condizioni')),
      _Riga(t.t('termini_pagamento'), _testo(cond['termini'])),
      _Riga(t.t('assicurazione'), _percentuale(cond['assicurazione'], t)),
      _Riga(t.t('contrassegno'), _percentuale(cond['contrassegno'], t)),
      _Riga(t.t('supplemento_residenziale'),
          cond['residenziale'] is num && (cond['residenziale'] as num) > 0 ? SchermataProfiloState.euro(cond['residenziale'] as num, t.lingua) : ''),
      _Riga(t.t('supplemento_carburante'), cond['carburante'] is num ? '${_numero(cond['carburante'] as num, t)}%' : ''),
      const SizedBox(height: 28),

      // --------------------------------------------------------- rubrica
      _Titolo(t.t('rubrica')),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        icon: const Icon(Icons.contacts_outlined),
        label: Text(t.t('apri_rubrica')),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => SchermataRubrica(codiceCliente: _testo(a['codice'])))),
      ),
      const SizedBox(height: 28),

      // --------------------------------------------------------- lingua
      _Titolo(t.t('lingua')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in Testi.lingue)
          ChoiceChip(
            label: Text(t.t('lingua_$l')),
            selected: t.lingua == l,
            selectedColor: Stile.verde.withValues(alpha: 0.25),
            shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
            onSelected: (_) => _lingua(l),
          ),
      ]),
      const SizedBox(height: 28),

      // --------------------------------------------------------- aspetto (nota 373 V3)
      _Titolo(t.t('aspetto')),
      const SceltaTema(),
      const SizedBox(height: 36),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        icon: const Icon(Icons.logout),
        label: Text(t.t('esci')),
        onPressed: _esci,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Stile.rosso,
          side: const BorderSide(color: Stile.rosso),
          minimumSize: const Size.fromHeight(44),
        ),
        onPressed: _eliminaAccount,
        child: Text(t.t('elimina_account')),
      ),
    ]);
  }

  static String _fascia(dynamic dalle, dynamic alle) {
    final a = _testo(dalle);
    final b = _testo(alle);
    if (a.isEmpty && b.isEmpty) return '';
    return '$a – $b';
  }

  static String _numero(num v, Testi t) {
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return t.lingua == 'en' ? s : s.replaceAll('.', ',');
  }

  static String _percentuale(dynamic dati, Testi t) {
    if (dati is! Map || dati['percentuale'] is! num || (dati['percentuale'] as num) <= 0) return '';
    final minimo = dati['minimo'] is num ? ' · ${t.t('minimo')} ${SchermataProfiloState.euro(dati['minimo'] as num, t.lingua)}' : '';
    return '${_numero(dati['percentuale'] as num, t)}%$minimo';
  }
}

Widget _dueBottoni(BuildContext c, String no, String si, {bool rosso = false}) => Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(no))),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton(
          style: rosso ? ElevatedButton.styleFrom(backgroundColor: Stile.rosso) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(si),
        ),
      ),
    ]);

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(testo, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600, fontSize: 16)),
      );
}

class _Sottotitolo extends StatelessWidget {
  const _Sottotitolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(testo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _Riga extends StatelessWidget {
  const _Riga(this.etichetta, this.valore);

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(etichetta, style: const TextStyle(color: Stile.grigio, fontSize: 13))),
          Expanded(child: Text(valore.isEmpty ? '-' : valore, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

// ---------------------------------------------------------------------- rubrica

class SchermataRubrica extends StatefulWidget {
  const SchermataRubrica({super.key, required this.codiceCliente});

  /// La propria scheda sta in «La mia scheda»: qui non compare
  final String codiceCliente;

  @override
  State<SchermataRubrica> createState() => _SchermataRubricaState();
}

class _SchermataRubricaState extends State<SchermataRubrica> {
  List<Map<String, dynamic>> _contatti = [];
  String _cerca = '';
  bool _attesa = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _attesa = true);
    try {
      final r = await Api.rubrica();
      if (!mounted) return;
      setState(() => _contatti = r
          .where((c) => c['tipo'] != 'indirizzo' && _testo(c['codice']).toUpperCase() != widget.codiceCliente.toUpperCase())
          .toList());
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  Future<void> _apri({Map<String, dynamic>? contatto}) async {
    final cambiato = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SchermataContatto(id: contatto?['id'] as int?, iniziale: contatto ?? const {}, propria: false)));
    if (cambiato == true) _carica();
  }

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final q = _cerca.toLowerCase();
    final elenco = _contatti
        .where((c) =>
            q.isEmpty ||
            [c['societa_op'], c['contatto'], c['citta_op'], c['indirizzo_op']].any((v) => _testo(v).toLowerCase().contains(q)))
        .toList();
    return Scaffold(
      appBar: barraApp(context, titolo: t.t('rubrica')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Stile.verdePulsanti,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        tooltip: t.t('nuovo_contatto'),
        onPressed: () => _apri(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search), hintText: t.t('cerca_rubrica')),
              onChanged: (v) => setState(() => _cerca = v.trim()),
            ),
          ),
          Expanded(
            child: _attesa
                ? const Center(child: CircularProgressIndicator())
                : elenco.isEmpty
                    ? Center(child: Text(t.t('rubrica_vuota'), style: const TextStyle(color: Stile.grigio)))
                    : RefreshIndicator(
                        onRefresh: _carica,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: elenco.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: context.colori.bordo),
                          itemBuilder: (_, i) {
                            final c = elenco[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(Api.nomeProprio(_testo(c['societa_op']))),
                              subtitle: Text(
                                [Api.nomeProprio(_testo(c['contatto'])), Api.nomeProprio(_testo(c['citta_op'])), _testo(c['codice_nazione_op'])]
                                    .where((v) => v.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(color: Stile.grigio, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Stile.grigio),
                              onTap: () => _apri(contatto: c),
                            );
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------- modulo contatto

/// Indirizzo e ritiro di un contatto: la propria scheda o una voce della rubrica (nuova o esistente).
/// Si salvano solo i campi cambiati, come sul sito; il server fa gli stessi controlli.
class SchermataContatto extends StatefulWidget {
  const SchermataContatto({super.key, this.id, required this.iniziale, required this.propria});

  final int? id;
  final Map<String, dynamic> iniziale;
  final bool propria;

  @override
  State<SchermataContatto> createState() => _SchermataContattoState();
}

const _campiTesto = [
  'societa_op', 'resp_settore_op', 'indirizzo_op', 'indirizzo2_op', 'cap_op', 'citta_op', 'provincia_op',
  'telefono_op', 'email_op', 'ritiro_ora_mattino_dalle', 'ritiro_ora_mattino_alle', 'ritiro_ora_pomeriggio_dalle',
  'ritiro_ora_pomeriggio_alle', 'ritiro_ora_pronti_dalle', 'ritiro_punto', 'ritiro_istruzioni_note',
];

class _SchermataContattoState extends State<SchermataContatto> {
  late final Map<String, TextEditingController> _campi = {
    for (final k in _campiTesto)
      // la rubrica chiama il referente «contatto»
      k: TextEditingController(text: _testo(widget.iniziale[k] ?? (k == 'resp_settore_op' ? widget.iniziale['contatto'] : null))),
  };
  late String _nazione = _testo(widget.iniziale['nazione_op']);
  late String _codiceNazione = _testo(widget.iniziale['codice_nazione_op']).toUpperCase();
  List<Map<String, dynamic>>? _nazioni;
  bool _attesa = false;

  @override
  void dispose() {
    for (final c in _campi.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scegliNazione() async {
    try {
      _nazioni ??= await Api.nazioni();
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
      return;
    }
    if (!mounted) return;
    final n = await SceltaNazione.apri(context, _nazioni!);
    if (n == null) return;
    setState(() {
      _nazione = '${n['nome']}';
      _codiceNazione = '${n['codice']}'.toUpperCase();
    });
  }

  Future<void> _salva() async {
    final t = Testi.di(context);
    FocusScope.of(context).unfocus();
    final valori = {for (final e in _campi.entries) e.key: e.value.text.trim()}
      ..['email_op'] = _campi['email_op']!.text.trim().toLowerCase()
      ..['provincia_op'] = _campi['provincia_op']!.text.trim().toUpperCase()
      ..['nazione_op'] = _nazione
      ..['codice_nazione_op'] = _codiceNazione;
    setState(() => _attesa = true);
    try {
      if (widget.id == null) {
        final r = await Api.nuovoContatto(valori);
        if (r['exists'] == true) throw ErroreApi('contatto_esistente', 400, r['error'] as String?);
      } else {
        final cambiati = {
          for (final e in valori.entries)
            if (e.value != _testo(widget.iniziale[e.key] ?? (e.key == 'resp_settore_op' ? widget.iniziale['contatto'] : null)))
              e.key: e.value
        };
        if (cambiati.isEmpty) {
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
        await Api.aggiornaContatto(widget.id!, cambiati);
      }
      if (!mounted) return;
      _avviso(context, t.t('salvato'));
      Navigator.of(context).pop(true);
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  Future<void> _elimina() async {
    final t = Testi.di(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        content: Text(t.t('conferma_elimina_contatto'), textAlign: TextAlign.center),
        actions: [_dueBottoni(c, t.t('annulla'), t.t('elimina'), rosso: true)],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.eliminaContatto(widget.id!);
      if (mounted) Navigator.of(context).pop(true);
    } on ErroreApi catch (e) {
      if (mounted) await _esitoErrore(context, e);
    }
  }

  Widget _campo(String chiave, String etichetta, {TextInputType? tastiera, bool ora = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _campi[chiave],
          keyboardType: tastiera,
          decoration: InputDecoration(labelText: etichetta, hintText: ora ? 'hh:mm' : null),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return Scaffold(
      appBar: barraApp(
        context,
        titolo: widget.propria
            ? t.t('la_mia_scheda')
            : widget.id == null
                ? t.t('nuovo_contatto')
                : t.t('contatto'),
        azioni: [
          if (!widget.propria && widget.id != null)
            IconButton(tooltip: t.t('elimina'), icon: const Icon(Icons.delete_outline), onPressed: _elimina),
        ],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _campo('societa_op', t.t('societa')),
          _campo('resp_settore_op', t.t('referente')),
          _campo('indirizzo_op', t.t('indirizzo')),
          _campo('indirizzo2_op', t.t('indirizzo_2')),
          Row(children: [
            Expanded(flex: 2, child: _campo('cap_op', t.t('cap'))),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _campo('citta_op', t.t('citta'))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _campo('provincia_op', t.t('prov'))),
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _scegliNazione,
              child: InputDecorator(
                decoration: InputDecoration(labelText: t.t('nazione'), suffixIcon: const Icon(Icons.arrow_drop_down)),
                child: Text(_nazione.isEmpty ? '' : '$_nazione${_codiceNazione.isEmpty ? '' : ' ($_codiceNazione)'}'),
              ),
            ),
          ),
          _campo('telefono_op', t.t('telefono'), tastiera: TextInputType.phone),
          _campo('email_op', t.t('email_campo'), tastiera: TextInputType.emailAddress),
          const SizedBox(height: 8),
          Text(t.t('ritiro_abituale'), style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _campo('ritiro_ora_mattino_dalle', '${t.t('mattino')} ${t.t('dalle')}', ora: true)),
            const SizedBox(width: 12),
            Expanded(child: _campo('ritiro_ora_mattino_alle', t.t('alle'), ora: true)),
          ]),
          Row(children: [
            Expanded(child: _campo('ritiro_ora_pomeriggio_dalle', '${t.t('pomeriggio')} ${t.t('dalle')}', ora: true)),
            const SizedBox(width: 12),
            Expanded(child: _campo('ritiro_ora_pomeriggio_alle', t.t('alle'), ora: true)),
          ]),
          _campo('ritiro_ora_pronti_dalle', t.t('pronti_dalle'), ora: true),
          _campo('ritiro_punto', t.t('punto_ritiro')),
          _campo('ritiro_istruzioni_note', t.t('note_ritiro')),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _attesa ? null : _salva,
            child: _attesa
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(t.t('salva')),
          ),
        ]),
      ),
    );
  }
}
