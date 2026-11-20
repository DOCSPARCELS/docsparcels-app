import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../servizi/api.dart';
import '../stile.dart';
import '../testi.dart';

/// Esito del pagamento con carta nella pagina myPOS aperta dentro l'app.
enum EsitoCarta { riuscito, nonRiuscito, chiuso }

/// Pagina di pagamento myPOS dentro l'app (nota 367 V2). Il ritorno si riconosce
/// dall'indirizzo su cui myPOS rimanda il cliente: /api/mypos/callback/success
/// (pagato) o /api/mypos/callback/error (annullato o rifiutato). La pagina di
/// ritorno si lascia caricare, perché è lì che il gestionale registra l'esito.
class SchermataPagamentoCarta extends StatefulWidget {
  const SchermataPagamentoCarta({super.key, required this.url});

  final String url;

  static Future<EsitoCarta> apri(BuildContext context, String url) async {
    final esito = await Navigator.of(context).push<EsitoCarta>(
        MaterialPageRoute(builder: (_) => SchermataPagamentoCarta(url: Api.indirizzo(url))));
    return esito ?? EsitoCarta.chiuso;
  }

  @override
  State<SchermataPagamentoCarta> createState() => _SchermataPagamentoCartaState();
}

class _SchermataPagamentoCartaState extends State<SchermataPagamentoCarta> {
  late final WebViewController _controller;
  bool _caricamento = true;
  bool _chiuso = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Stile.sfondo)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _caricamento = true),
        onPageFinished: (url) {
          if (mounted) setState(() => _caricamento = false);
          _controllaRitorno(url);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  void _controllaRitorno(String url) {
    if (_chiuso) return;
    EsitoCarta? esito;
    if (url.contains('/api/mypos/callback/success')) esito = EsitoCarta.riuscito;
    if (url.contains('/api/mypos/callback/error')) esito = EsitoCarta.nonRiuscito;
    if (esito == null) return;
    _chiuso = true;
    // Un attimo per far vedere la pagina di esito del gestionale, poi si torna all'app
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pop(esito);
    });
  }

  @override
  Widget build(BuildContext context) {
    final testi = Testi.di(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(testi.t('pagamento_carta')),
        leading: IconButton(
          tooltip: testi.t('annulla'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(EsitoCarta.chiuso),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_caricamento) const LinearProgressIndicator(color: Stile.verde),
        ],
      ),
    );
  }
}
