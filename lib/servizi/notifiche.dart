import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';

/// Notifiche sul telefono con Firebase: permesso, codice del telefono registrato sul
/// gestionale (POST /app/api/dispositivo) e tolto all'uscita (DELETE).
class Notifiche {
  static String? _codice;
  static String _lingua = 'it';
  static bool _ascolto = false;

  /// Da chiamare con la chiave valida (dopo l'entrata o all'apertura del profilo).
  static Future<void> attiva(String lingua) async {
    _lingua = lingua;
    try {
      final messaggi = FirebaseMessaging.instance;
      final permesso = await messaggi.requestPermission(alert: true, badge: true, sound: true);
      final concesso = permesso.authorizationStatus == AuthorizationStatus.authorized ||
          permesso.authorizationStatus == AuthorizationStatus.provisional;
      final codice = await messaggi.getToken();
      if (codice == null) return;
      _codice = codice;
      await Api.registraTelefono(codice, Platform.isIOS ? 'ios' : 'android', lingua, concesso);
      if (!_ascolto) {
        _ascolto = true;
        // Firebase a volte cambia il codice: il gestionale va aggiornato
        messaggi.onTokenRefresh.listen((nuovo) async {
          _codice = nuovo;
          try {
            await Api.registraTelefono(nuovo, Platform.isIOS ? 'ios' : 'android', _lingua, true);
          } catch (_) {}
        });
      }
    } catch (_) {
      // senza notifiche l'app funziona lo stesso
    }
  }

  /// All'uscita: il telefono non riceve piu' notifiche per questo account.
  static Future<void> disattiva() async {
    final codice = _codice ?? await _codiceAttuale();
    if (codice == null) return;
    try {
      await Api.togliTelefono(codice);
    } catch (_) {}
    _codice = null;
  }

  static Future<String?> _codiceAttuale() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
