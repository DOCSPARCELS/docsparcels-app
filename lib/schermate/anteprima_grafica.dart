import 'package:flutter/material.dart';

import '../stile.dart';
import '../testi.dart';

/// Nota 373 V2: prova a video della nuova grafica, da far scegliere a Luca. Si vede solo con la
/// build di prova (--dart-define=ANTEPRIMA_GRAFICA=true); l'app normale non la mostra.
/// Si scorre: avvio A (scuro con fascia bianca), avvio B (bianco), accesso, pagina principale.
class AnteprimaGrafica extends StatefulWidget {
  const AnteprimaGrafica({super.key});

  @override
  State<AnteprimaGrafica> createState() => _AnteprimaGraficaState();
}

class _AnteprimaGraficaState extends State<AnteprimaGrafica> {
  final _pagine = PageController();
  int _pagina = 0;

  static const _titoli = ['A · avvio scuro con fascia bianca', 'B · avvio tutto bianco', 'Accesso', 'Pagina principale'];

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        PageView(
          controller: _pagine,
          onPageChanged: (p) => setState(() => _pagina = p),
          children: const [_AvvioScuro(), _AvvioBianco(), _Accesso(), _Principale()],
        ),
        // Etichetta della prova (non fa parte della grafica)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: Stile.angoli),
              child: Text('${_pagina + 1}/4 · ${_titoli[_pagina]}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.larghezza = 300});

  final double larghezza;

  @override
  Widget build(BuildContext context) => Image.asset('assets/immagini/logo.png', width: larghezza);
}

/// Il logo su una fascia bianca: sul fondo scuro le scritte grigie del logo non si leggerebbero
class _FasciaLogo extends StatelessWidget {
  const _FasciaLogo({this.larghezza = 280});

  final double larghezza;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: Stile.angoli),
        child: _Logo(larghezza: larghezza),
      );
}

class _AvvioScuro extends StatelessWidget {
  const _AvvioScuro();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Stile.sfondo, child: Center(child: _FasciaLogo()));
}

class _AvvioBianco extends StatelessWidget {
  const _AvvioBianco();

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.white, child: Center(child: _Logo(larghezza: 300)));
}

class _Accesso extends StatelessWidget {
  const _Accesso();

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    return ColoredBox(
      color: Stile.sfondo,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 72, 24, 24), children: [
          const Center(child: _FasciaLogo(larghezza: 250)),
          const SizedBox(height: 36),
          const Text('Bentornato',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          const Text("Entra con il tuo account Doc's & Parcels",
              textAlign: TextAlign.center, style: TextStyle(color: Stile.grigio)),
          const SizedBox(height: 28),
          TextField(decoration: InputDecoration(labelText: t.t('email'))),
          const SizedBox(height: 16),
          TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: t.t('password'), suffixIcon: const Icon(Icons.visibility)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () {}, child: Text(t.t('entra'))),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () {},
            icon: const Icon(Icons.fingerprint),
            label: const Text('Entra con Face ID'),
          ),
          const SizedBox(height: 40),
          const Text('Italiano · English · Español · Français · Deutsch',
              textAlign: TextAlign.center, style: TextStyle(color: Stile.grigio, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _Principale extends StatelessWidget {
  const _Principale();

  @override
  Widget build(BuildContext context) {
    final t = Testi.di(context);
    final voci = [
      (Icons.add, t.t('nuova_spedizione'), true),
      (Icons.list_alt_outlined, t.t('le_mie_spedizioni'), false),
      (Icons.receipt_long_outlined, t.t('pagamenti_fatture'), false),
      (Icons.calculate_outlined, t.t('preventivo_veloce'), false),
    ];
    return Scaffold(
      backgroundColor: Stile.sfondo,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: const Color(0xFF141418),
        titleSpacing: 16,
        title: const _FasciaLogo(larghezza: 150),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
                backgroundColor: Stile.verdePulsanti,
                child: Text('LA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), children: [
        const Text('Ciao Luca', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('${t.t('codice_cliente')} AVE', style: const TextStyle(color: Stile.grigio)),
        const SizedBox(height: 16),
        _Card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.t('saldo'), style: const TextStyle(color: Stile.grigio)),
            const SizedBox(height: 4),
            const Text('€ 1.000,00', style: TextStyle(color: Stile.verde, fontSize: 30, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final (icona, testo, principale) in voci)
              _Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: principale ? Stile.verdePulsanti : const Color(0xFF23462D),
                    child: Icon(icona, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(testo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ultima spedizione', style: TextStyle(color: Stile.verde, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('MOS 555 7171 · 20.11.26', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF8BC34A)), borderRadius: Stile.angoli),
              child: const Text('In transito', style: TextStyle(color: Color(0xFF8BC34A), fontSize: 13)),
            ),
          ]),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF141418),
        indicatorColor: Stile.verde.withValues(alpha: 0.2),
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: Stile.verde), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Spedizioni'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Pagamenti'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profilo'),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          border: Border.all(color: const Color(0xFF444444)),
          borderRadius: Stile.angoli,
        ),
        child: child,
      );
}
