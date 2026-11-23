import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servizi/api.dart';
import '../servizi/apple.dart';
import '../servizi/biometria.dart';
import '../servizi/google.dart';
import 'collega_account.dart';
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
  /// 'google' o 'apple' mentre si entra con loro
  String? _esterno;
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

  /// Accedi con Google (nota 373 V41) o con Apple (V43, solo iPhone). Se l'account non e'
  /// ancora di un cliente, si collega una volta con email e password (SchermataCollegaAccount).
  Future<void> _entraConEsterno(String fornitore) async {
    final testi = Testi.di(context);
    setState(() {
      _esterno = fornitore;
      _errore = null;
    });
    try {
      Map<String, dynamic>? credenziali;
      if (fornitore == 'apple') {
        final c = await AccessoApple.credenziali();
        if (c != null) credenziali = {'id_token': c.gettone, 'codice': c.codice, 'nome': c.nome};
      } else {
        final gettone = await AccessoGoogle.gettone();
        if (gettone != null) credenziali = {'id_token': gettone};
      }
      if (credenziali == null || !mounted) return;
      try {
        if (fornitore == 'apple') {
          await Api.entraApple(credenziali, testi.lingua);
        } else {
          await Api.entraGoogle(credenziali['id_token'] as String, testi.lingua);
        }
      } on ErroreApi catch (e) {
        if (e.codice != 'da_collegare' || !mounted) rethrow;
        final dati = credenziali;
        final collegato = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => SchermataCollegaAccount(fornitore: fornitore, credenziali: dati)));
        if (collegato != true) return;
      }
      if (!mounted) return;
      await _proponiBiometria(testi);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SchermataProfilo()));
    } on ErroreGoogle catch (e) {
      debugPrint('🔐 Accedi con Google: $e');
      if (mounted) {
        setState(() => _errore =
            testi.t(e.codice == 'non_disponibile' ? 'google_non_disponibile' : 'errore_google_non_valido'));
      }
    } on ErroreApple catch (e) {
      debugPrint('🔐 Accedi con Apple: $e');
      if (mounted) {
        setState(() => _errore =
            testi.t(e.codice == 'non_disponibile' ? 'apple_non_disponibile' : 'errore_apple_non_valido'));
      }
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = testi.errore(e.codice));
    } catch (_) {
      if (mounted) setState(() => _errore = testi.errore('generico'));
    } finally {
      if (mounted) setState(() => _esterno = null);
    }
  }

  /// Pulsante Apple (nota 373 V43): quello ufficiale, nero nel tema chiaro e bianco nel tema scuro
  Widget _pulsanteApple(Testi testi) {
    final occupato = _attesa || _esterno != null;
    if (_esterno == 'apple') {
      return const SizedBox(
          height: 48, child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return IgnorePointer(
      ignoring: occupato,
      child: SignInWithAppleButton(
        text: testi.t('accedi_apple'),
        height: 48,
        borderRadius: Stile.angoli,
        style: context.temaScuro ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black,
        onPressed: () => _entraConEsterno('apple'),
      ),
    );
  }

  /// Pulsante Google: bianco col bordo grigio nel tema chiaro, scuro nel tema scuro (regole di Google)
  Widget _pulsanteGoogle(Testi testi) {
    final scuro = context.temaScuro;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: scuro ? const Color(0xFF131314) : Colors.white,
        foregroundColor: scuro ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
        side: BorderSide(color: scuro ? const Color(0xFF8E918F) : const Color(0xFF747775)),
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: _attesa || _esterno != null ? null : () => _entraConEsterno('google'),
      child: _esterno == 'google'
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset('assets/immagini/google_g.png', width: 20, height: 20),
              const SizedBox(width: 12),
              Text(testi.t('accedi_google'), style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
    );
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
                    onPressed: _attesa || _esterno != null ? null : _entra,
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
                  // Nota 373 V41: oppure, accedi con Google
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Divider(color: Stile.grigio.withValues(alpha: 0.4))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(testi.t('oppure'), style: TextStyle(color: Stile.grigio)),
                    ),
                    Expanded(child: Divider(color: Stile.grigio.withValues(alpha: 0.4))),
                  ]),
                  const SizedBox(height: 16),
                  _pulsanteGoogle(testi),
                  // Nota 373 V43: Apple solo su iPhone
                  if (AccessoApple.previsto) ...[const SizedBox(height: 12), _pulsanteApple(testi)],
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
