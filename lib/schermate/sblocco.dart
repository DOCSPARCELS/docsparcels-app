import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../servizi/biometria.dart';
import '../stile.dart';
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

class _SchermataSbloccoState extends State<SchermataSblocco> {
  bool _attesa = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sblocca());
  }

  Future<void> _sblocca() async {
    if (_attesa) return;
    setState(() => _attesa = true);
    final ok = await Biometria.sblocca(Testi.di(context));
    if (!mounted) return;
    setState(() => _attesa = false);
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
                  Text("Doc's & Parcels",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Stile.verde)),
                  const SizedBox(height: 32),
                  const Icon(Icons.fingerprint, size: 72, color: Stile.verde),
                  const SizedBox(height: 32),
                  ElevatedButton(onPressed: _attesa ? null : _sblocca, child: Text(testi.t('sblocca'))),
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
