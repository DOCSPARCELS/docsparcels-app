import 'package:flutter/material.dart';

import '../servizi/api.dart';
import '../servizi/notifiche.dart';
import '../stile.dart';
import '../testi.dart';
import 'entrata.dart';
import 'le_mie_spedizioni.dart';
import 'mio_profilo.dart';
import 'nuova_spedizione.dart';
import 'pagamenti_fatture.dart';
import 'preventivo.dart';

/// Schermata «io»: nome, codice cliente, credito disponibile, uscita.
class SchermataProfilo extends StatefulWidget {
  const SchermataProfilo({super.key});

  @override
  State<SchermataProfilo> createState() => SchermataProfiloState();
}

class SchermataProfiloState extends State<SchermataProfilo> {
  Map<String, dynamic>? _io;
  Map<String, dynamic>? _credito;
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
      if (!mounted) return;
      setState(() {
        _io = io;
        _credito = credito;
      });
      // Notifiche sul telefono: permesso e registrazione (non blocca la schermata)
      Notifiche.attiva(Testi.di(context).lingua);
      // Una notifica toccata ad app chiusa apre ora il dettaglio della spedizione
      Notifiche.profiloPronto();
    } on ErroreApi catch (e) {
      if (e.codice == 'chiave_non_valida') {
        await Api.esci();
        if (!mounted) return;
        _tornaAllEntrata();
        return;
      }
      if (mounted) setState(() => _errore = Testi.di(context).errore(e.codice));
    } finally {
      if (mounted) setState(() => _attesa = false);
    }
  }

  void _tornaAllEntrata() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SchermataEntrata()));
  }

  Future<void> _esci() async {
    final testi = Testi.di(context);
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: Stile.angoli),
        content: Text(testi.t('conferma_uscita'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // I due pulsanti affiancati, larghi uguali
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
              Expanded(
                child: ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(testi.t('si'))),
              ),
            ],
          ),
        ],
      ),
    );
    if (si != true) return;
    await Api.esci();
    if (mounted) _tornaAllEntrata();
  }

  /// € prima dell'importo, separatore delle migliaia: € 1.000,00 (it, es, de) / € 1,000.00 (en) / € 1 000,00 (fr).
  static String euro(num valore, String lingua) {
    final parti = valore.abs().toStringAsFixed(2).split('.');
    final migliaia = lingua == 'en' ? ',' : lingua == 'fr' ? ' ' : '.';
    final decimali = lingua == 'en' ? '.' : ',';
    final intero = parti[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => migliaia);
    return '€ ${valore < 0 ? '-' : ''}$intero$decimali${parti[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final testi = Testi.di(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doc's & Parcels"),
        actions: [
          IconButton(tooltip: testi.t('aggiorna'), icon: const Icon(Icons.refresh), onPressed: _attesa ? null : _carica),
          IconButton(tooltip: testi.t('esci'), icon: const Icon(Icons.logout), onPressed: _esci),
        ],
      ),
      body: SafeArea(
        child: _attesa
            ? const Center(child: CircularProgressIndicator())
            : _errore != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errore!, textAlign: TextAlign.center)))
                : RefreshIndicator(
                    onRefresh: _carica,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        // Toccando il nome si apre il profilo completo (nota 372)
                        InkWell(
                          borderRadius: Stile.angoli,
                          onTap: () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const SchermataMioProfilo()));
                            if (mounted) _carica();
                          },
                          child: Row(children: [
                            Expanded(
                              child: Text('${testi.t('ciao')} ${_io?['nome_completo'] ?? ''}',
                                  style: Theme.of(context).textTheme.titleLarge),
                            ),
                            const Icon(Icons.chevron_right, color: Stile.grigio),
                          ]),
                        ),
                        const SizedBox(height: 24),
                        _riga(testi.t('codice_cliente'), '${_io?['codice'] ?? '-'}'),
                        const SizedBox(height: 12),
                        _riga(
                          testi.t('saldo'),
                          _credito?['attivo'] == true
                              ? euro((_credito?['saldo'] as num?) ?? 0, testi.lingua)
                              : testi.t('saldo_non_attivo'),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.list_alt_outlined),
                          label: Text(testi.t('le_mie_spedizioni')),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const SchermataLeMieSpedizioni())),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(testi.t('pagamenti_fatture')),
                          onPressed: () async {
                            await Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const SchermataPagamentiFatture()));
                            // credito e saldo possono essere cambiati
                            if (mounted) _carica();
                          },
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: Text(testi.t('nuova_spedizione')),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const SchermataNuovaSpedizione())),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calculate_outlined),
                          label: Text(testi.t('preventivo_veloce')),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const SchermataPreventivo())),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _riga(String etichetta, String valore) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Stile.grigio), borderRadius: Stile.angoli),
        child: Row(
          children: [
            Expanded(child: Text(etichetta, style: const TextStyle(color: Stile.grigio))),
            Text(valore, style: const TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
