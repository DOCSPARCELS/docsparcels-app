import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';

/// Collega il tuo account (nota 373 V41, Apple dalla V43): l'account Google o Apple non e'
/// ancora di un cliente (email diversa da quella del gestionale, o nascosta da Apple).
/// Email e password si scrivono una volta sola; poi si entra con Google o Apple.
/// Ritorna true se il collegamento e' riuscito.
class SchermataCollegaAccount extends StatefulWidget {
  const SchermataCollegaAccount({super.key, required this.fornitore, required this.credenziali});

  /// 'google' o 'apple'
  final String fornitore;

  /// Quello che si manda al gestionale: id_token (e per Apple codice e nome)
  final Map<String, dynamic> credenziali;

  @override
  State<SchermataCollegaAccount> createState() => _SchermataCollegaAccountState();
}

class _SchermataCollegaAccountState extends State<SchermataCollegaAccount> {
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

  Future<void> _collega() async {
    final testi = Testi.di(context);
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      await Api.collega(widget.fornitore, widget.credenziali, _login.text, _password.text, testi.lingua);
      if (mounted) Navigator.of(context).pop(true);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = testi.errore(e.codice));
    } catch (_) {
      if (mounted) setState(() => _errore = testi.errore('generico'));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testi = Testi.di(context);
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(testi.t('collega_titolo'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(testi.t(widget.fornitore == 'apple' ? 'collega_spiegazione_apple' : 'collega_spiegazione'),
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.colori.testo)),
                  const SizedBox(height: 24),
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
                    onSubmitted: (_) => _attesa ? null : _collega(),
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
                    onPressed: _attesa ? null : _collega,
                    child: _attesa
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(testi.t('collega_conferma')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
