import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servizi/api.dart';
import '../servizi/biometria.dart';
import '../servizi/lingua.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import 'profilo.dart';
import 'recupero_password.dart';
import '../widget/scelta_tema.dart';
import '../widget/scelta_lingua.dart';
import '../servizi/chiave.dart';

/// Schermata di entrata: email (o nome utente) e password.
class SchermataEntrata extends StatefulWidget {
  const SchermataEntrata({super.key});

  @override
  State<SchermataEntrata> createState() => _SchermataEntrataState();
}

class _SchermataEntrataState extends State<SchermataEntrata> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _attesa = false;
  bool _nascosta = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    // Nota 373 V11: l'app ricorda con chi si era entrati l'ultima volta
    ArchivioChiave.ultimoLogin().then((v) {
      if (mounted && v != null && _login.text.isEmpty) setState(() => _login.text = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entra() async {
    final testi = Testi.di(context);
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      await Api.entra(_login.text, _password.text, testi.lingua);
      try {
        await ArchivioChiave.salvaLogin(_login.text.trim());
      } catch (_) {}
      if (!mounted) return;
      await _proponiBiometria(testi);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SchermataProfilo()));
    } on ErroreApi catch (e) {
      setState(() => _errore = testi.errore(e.codice));
    } catch (_) {
      setState(() => _errore = testi.errore('generico'));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  /// Dopo la prima entrata: Face ID / impronta per le prossime aperture, se il telefono li ha.
  Future<void> _proponiBiometria(Testi testi) async {
    if (!await Biometria.disponibile()) return;
    if (!mounted) return;
    final si = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        content: Text(testi.t('domanda_biometria'), textAlign: TextAlign.center),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Stile.verde,
                    side: const BorderSide(color: Stile.verde),
                    shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(testi.t('no')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(testi.t('si')))),
            ],
          ),
        ],
      ),
    );
    // Si conferma subito con lo sblocco: cosi' si sa che funziona su questo telefono
    final usa = si == true && await Biometria.sblocca(testi);
    await Biometria.salvaScelta(usa);
    if (si == true && !usa && Biometria.ultimoErrore != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(Biometria.ultimoErrore!, textAlign: TextAlign.center)));
    }
  }

  static const _email = 'info@docsparcels.com';
  static const _telefono = '+39 06 7720 3074';

  Future<void> _apri(Uri indirizzo) async {
    try {
      if (await launchUrl(indirizzo)) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Testi.di(context).t('non_apribile'), textAlign: TextAlign.center)));
    }
  }

  /// Piè di pagina (nota 373 V4): marchio, email e telefono che si toccano
  Widget _piede(Testi testi) {
    final colore = context.temaScuro ? const Color(0xFFBDBDBD) : const Color(0xFF555555);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ® un po' staccato da «Parcels» (nota 373 V9)
          Text("Doc's & Parcels\u2009®", style: TextStyle(fontWeight: FontWeight.w600, color: colore)),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colore, padding: const EdgeInsets.symmetric(horizontal: 6)),
              onPressed: () => _apri(Uri(scheme: 'mailto', path: _email)),
              child: const Text(_email, style: TextStyle(fontSize: 13)),
            ),
            Text('·', style: TextStyle(color: colore.withValues(alpha: 0.35))),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colore, padding: const EdgeInsets.symmetric(horizontal: 6)),
              onPressed: () => _apri(Uri(scheme: 'tel', path: _telefono.replaceAll(' ', ''))),
              child: const Text(_telefono, style: TextStyle(fontSize: 13)),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testi = Testi.di(context);
    return Scaffold(
      bottomNavigationBar: _piede(testi),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Su tablet e telefoni grandi il modulo non si allarga troppo
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nota 373 V3: logo centrato in alto, poi il saluto
                  const Center(child: LogoApp(altezza: 72)),
                  const SizedBox(height: 36),
                  Text(testi.t('ciao_accesso'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: context.colori.testo)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _login,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: InputDecoration(labelText: testi.t('email')),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: _nascosta,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _attesa ? null : _entra(),
                    decoration: InputDecoration(
                      labelText: testi.t('password'),
                      suffixIcon: IconButton(
                        icon: Icon(_nascosta ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _nascosta = !_nascosta),
                      ),
                    ),
                  ),
                  if (_errore != null) ...[
                    const SizedBox(height: 16),
                    Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _attesa ? null : _entra,
                    child: _attesa
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(testi.t('entra')),
                  ),
                  // Nota 373 V37: stessa procedura della pagina del sito
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Stile.verde),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SchermataRecuperoPassword(email: _login.text))),
                    child: Text(testi.t('password_dimenticata')),
                  ),
                  const SizedBox(height: 24),
                  // Tema (nota 373 V4): la stessa scelta di «Il mio profilo» → «Aspetto»
                  const SceltaTema(),
                  const SizedBox(height: 20),
                  // Lingua dell'app, anche prima di entrare (uguale al profilo)
                  const SceltaLingua(scegli: LinguaApp.imposta),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
