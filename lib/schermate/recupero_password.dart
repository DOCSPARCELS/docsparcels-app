import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';

/// Password dimenticata (nota 373 V37): l'email riceve il link per sceglierne una nuova.
/// La procedura e' quella del sito; il messaggio e' lo stesso che l'email sia di un
/// cliente o no, cosi' non si scopre chi e' registrato.
class SchermataRecuperoPassword extends StatefulWidget {
  const SchermataRecuperoPassword({super.key, this.email = ''});

  /// L'email gia' scritta nella schermata di accesso, se e' un'email
  final String email;

  @override
  State<SchermataRecuperoPassword> createState() => _SchermataRecuperoPasswordState();
}

class _SchermataRecuperoPasswordState extends State<SchermataRecuperoPassword> {
  late final _email = TextEditingController(text: widget.email.contains('@') ? widget.email.trim() : '');
  bool _attesa = false;
  bool _inviata = false;
  String? _errore;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invia() async {
    final testi = Testi.di(context);
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _errore = testi.t('recupero_email_non_valida'));
      return;
    }
    setState(() {
      _attesa = true;
      _errore = null;
    });
    try {
      await Api.passwordDimenticata(email, testi.lingua);
      if (mounted) setState(() => _inviata = true);
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
      appBar: AppBar(centerTitle: true, title: Text(testi.t('recupero_titolo'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _inviata ? _fatto(testi) : _modulo(testi),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _modulo(Testi testi) => [
        Text(testi.t('recupero_spiegazione'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.colori.testo)),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _attesa ? null : _invia(),
          decoration: InputDecoration(labelText: testi.t('recupero_email')),
        ),
        if (_errore != null) ...[
          const SizedBox(height: 16),
          Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _attesa ? null : _invia,
          child: _attesa
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(testi.t('recupero_invia')),
        ),
      ];

  List<Widget> _fatto(Testi testi) => [
        const Icon(Icons.mark_email_read_outlined, size: 56, color: Stile.verde),
        const SizedBox(height: 20),
        Text(testi.t('recupero_inviato'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: context.colori.testo)),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(testi.t('recupero_torna')),
        ),
      ];
}
