import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../servizi/biometria.dart';
import '../stile.dart';
import '../widget/barra.dart';
import '../testi.dart';
import 'entrata.dart';
import 'profilo.dart';

/// All'apertura dell'app, se il cliente ha scelto Face ID / impronta: la chiave salvata
/// si usa solo dopo lo sblocco. In alternativa si rientra con email e password.
class SchermataSblocco extends StatefulWidget {
  const SchermataSblocco({super.key});

  @override
  State<SchermataSblocco> createState() => _SchermataSbloccoState();
}

class _SchermataSbloccoState extends State<SchermataSblocco> with WidgetsBindingObserver {
  bool _attesa = false;
  bool _provato = false;
  bool _riprovato = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Nota 373 V11: su iPhone Face ID chiesto mentre l'app si sta ancora aprendo non parte;
    // si chiede appena l'app e' attiva (o al ritorno in primo piano)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted && !_provato) _sblocca();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    if (stato == AppLifecycleState.resumed && !_provato && mounted) _sblocca();
  }

  Future<void> _sblocca() async {
    if (_attesa) return;
    _provato = true;
    setState(() {
      _attesa = true;
      _errore = null;
    });
    var ok = await Biometria.sblocca(Testi.di(context));
    if (!mounted) return;
    // Nota 373 V11: all'apertura su iPhone il sistema puo' non essere ancora pronto: un secondo tentativo
    final errore = Biometria.ultimoErrore ?? '';
    if (!ok && !_riprovato && (errore.contains('systemCanceled') || errore.contains('uiUnavailable'))) {
      _riprovato = true;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      ok = await Biometria.sblocca(Testi.di(context));
      if (!mounted) return;
    }
    setState(() {
      _attesa = false;
      _errore = Biometria.ultimoErrore;
    });
    if (ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SchermataProfilo()));
    }
  }

  Future<void> _conPassword() async {
    await Api.esci();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SchermataEntrata()));
  }

  @override
  Widget build(BuildContext context) {
    final testi = Testi.di(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoApp(altezza: 72)),
                  const SizedBox(height: 40),
                  const Icon(Icons.fingerprint, size: 72, color: Stile.verde),
                  const SizedBox(height: 32),
                  ElevatedButton(onPressed: _attesa ? null : _sblocca, child: Text(testi.t('sblocca'))),
                  if (_errore != null) ...[
                    const SizedBox(height: 12),
                    Text(_errore!, textAlign: TextAlign.center, style: const TextStyle(color: Stile.rosso, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  TextButton(onPressed: _conPassword, child: Text(testi.t('usa_password'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
