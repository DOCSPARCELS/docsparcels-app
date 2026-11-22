import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servizi/api.dart';
import '../servizi/biometria.dart';
import '../servizi/lingua.dart';
import '../stile.dart';
import '../testi.dart';
import '../widget/barra.dart';
import 'profilo.dart';
import '../widget/scelta_tema.dart';

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
  }

  static const _bandiere = {'it': '🇮🇹', 'en': '🇬🇧', 'es': '🇪🇸', 'fr': '🇫🇷', 'de': '🇩🇪'};

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
          Text("Doc's & Parcels®", style: TextStyle(fontWeight: FontWeight.w600, color: colore)),
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
                  const SizedBox(height: 6),
                  Text(testi.t('entra_con_account'),
                      textAlign: TextAlign.center, style: const TextStyle(color: Stile.grigio)),
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
                  const SizedBox(height: 32),
                  // Tema (nota 373 V4): la stessa scelta di «Il mio profilo» → «Aspetto»
                  const SceltaTema(),
                  const SizedBox(height: 20),
                  // Lingua dell'app, anche prima di entrare: nome e sotto la bandierina
                  Wrap(alignment: WrapAlignment.center, spacing: 2, children: [
                    for (final l in Testi.lingue)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: testi.lingua == l ? Stile.verde : Stile.grigio,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => LinguaApp.imposta(l),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(testi.t('lingua_$l'),
                              style: TextStyle(fontWeight: testi.lingua == l ? FontWeight.w700 : FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(_bandiere[l] ?? '', style: const TextStyle(fontSize: 20)),
                        ]),
                      ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
