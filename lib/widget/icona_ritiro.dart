import 'package:flutter/material.dart';

/// Icona di «Prenota ritiro» (nota 373 V20): omino col portapacchi a due ruote.
/// Prende il colore dal tema come le altre icone; è più fitta di un'icona Material,
/// per questo va usata qualche punto più grande.
class IconaRitiro extends StatelessWidget {
  const IconaRitiro({super.key, required this.size});

  final double size;

  // ImageIcon non ingrandisce l'immagine oltre la sua misura (BoxFit.scaleDown):
  // con BoxFit.contain l'icona cresce davvero quando serve (home scura, 23.11.26)
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Image.asset('assets/immagini/ritiro.png',
            width: size, height: size, fit: BoxFit.contain, color: IconTheme.of(context).color),
      );
}
