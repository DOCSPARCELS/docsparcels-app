import 'package:flutter/material.dart';

/// Icona di «Prenota ritiro» (nota 373 V20): omino col portapacchi a due ruote.
/// Prende il colore dal tema come le altre icone; è più fitta di un'icona Material,
/// per questo va usata qualche punto più grande.
class IconaRitiro extends StatelessWidget {
  const IconaRitiro({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      ImageIcon(const AssetImage('assets/immagini/ritiro.png'), size: size);
}
