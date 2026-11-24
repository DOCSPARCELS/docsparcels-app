import 'dart:io';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../schermate/dettaglio_spedizione.dart';
import 'api.dart';

/// Notifiche sul telefono con Firebase: permesso, codice del telefono registrato sul
/// gestionale (POST /app/api/dispositivo) e tolto all'uscita (DELETE).
/// Toccando una notifica di spedizione si apre il suo dettaglio (nota 368), anche ad app chiusa.
class Notifiche {
  static String? _codice;
  static String _lingua = 'it';
  static bool _ascolto = false;

  /// Navigatore dell'app, per aprire il dettaglio da una notifica
  static final navigatore = GlobalKey<NavigatorState>();

  /// Spedizione della notifica toccata, aperta appena il profilo e' pronto (dopo lo sblocco)
  static int? _daAprire;
  static bool _profiloPronto = false;

  /// All'avvio: la notifica che ha aperto l'app e quelle toccate con l'app in secondo piano.
  static Future<void> ascoltaTocchi() async {
    try {
      final iniziale = await FirebaseMessaging.instance.getInitialMessage();
      _daAprire = _spedizioneDi(iniziale) ?? _daAprire;
      // una notifica arrivata con l'app aperta: la campanella si aggiorna (nota 392 V2)
      FirebaseMessaging.onMessage.listen((_) => aggiornaNumero());
      FirebaseMessaging.onMessageOpenedApp.listen((messaggio) {
        final id = _spedizioneDi(messaggio);
        if (id == null) return;
        _daAprire = id;
        apriInAttesa();
      });
    } catch (_) {
      // senza Firebase niente notifiche da aprire
    }
  }

  /// Non lette degli ultimi 30 giorni: campanella della home e numero sull'icona (nota 392 V2).
  static final nonLette = ValueNotifier<int>(0);

  /// Rilegge il numero dal gestionale e lo rimette sull'icona dell'app.
  static Future<void> aggiornaNumero() async {
    try {
      final r = await Api.notifiche();
      mostraNumero((r['non_lette_recenti'] as num?)?.toInt() ?? 0);
    } catch (_) {
      // senza rete resta il numero di prima
    }
  }

  static void mostraNumero(int numero) {
    nonLette.value = numero;
    // su alcuni telefoni Android il numero non si puo' mostrare: si ignora
    AppBadgePlus.updateBadge(numero).catchError((_) {});
  }

  /// Segna lette (una, quelle di una spedizione o tutte) e aggiorna il numero.
  static Future<void> segnaLette({int? id, int? spedizioneId}) async {
    try {
      await Api.segnaNotificheLette(id: id, spedizioneId: spedizioneId);
    } catch (_) {}
    await aggiornaNumero();
  }

  /// Solo le notifiche che portano alla scheda di una spedizione (non eliminate o annullate).
  static int? _spedizioneDi(RemoteMessage? messaggio) {
    final dati = messaggio?.data ?? const {};
    if (!'${dati['url'] ?? ''}'.startsWith('/cliente/spedizione/')) return null;
    return int.tryParse('${dati['spedizione_id'] ?? ''}');
  }

  /// Il profilo ha letto l'utente con la chiave valida: da qui si puo' aprire il dettaglio.
  static void profiloPronto() {
    _profiloPronto = true;
    apriInAttesa();
  }

  static void apriInAttesa() {
    final id = _daAprire;
    final nav = navigatore.currentState;
    if (id == null || nav == null || !_profiloPronto) return;
    _daAprire = null;
    nav.push(MaterialPageRoute(builder: (_) => SchermataDettaglioSpedizione(id: id)));
  }

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
    _profiloPronto = false;
    _daAprire = null;
    mostraNumero(0);
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
