import 'package:flutter/material.dart';

import '../stile.dart';
import '../testi.dart';

/// «Pulisci campi» (nota 373 V23): solo la scritta, in basso a destra nella sua sezione.
class PulisciCampi extends StatelessWidget {
  const PulisciCampi({super.key, required this.pulisci});

  final VoidCallback pulisci;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: Stile.grigio, padding: const EdgeInsets.symmetric(horizontal: 4)),
          onPressed: pulisci,
          child: Text(Testi.di(context).t('pulisci_campi')),
        ),
      );
}
