import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'biometria.dart';
import 'chiave.dart';
import 'notifiche.dart';

/// Errore del gestionale: [codice] e' quello che manda il server (es. credenziali_errate),
/// l'app lo traduce con Testi.errore().
class ErroreApi implements Exception {
  ErroreApi(this.codice, [this.stato]);

  final String codice;
  final int? stato;

  @override
  String toString() => 'ErroreApi($codice, $stato)';
}

/// Chiamate al gestionale. La chiave va nell'intestazione X-App-Chiave
/// (sul server Apache toglie «Authorization»).
class Api {
  static const _tempo = Duration(seconds: 20);

  static Uri _url(String percorso) => Uri.parse('${Config.indirizzo}$percorso');

  static Future<Map<String, String>> _intestazioni({bool conChiave = true}) async {
    final intestazioni = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (conChiave) {
      intestazioni['X-App-Chiave'] = await ArchivioChiave.leggi() ?? '';
    }
    return intestazioni;
  }

  static Map<String, dynamic> _risposta(http.Response r) {
    Map<String, dynamic> corpo = {};
    try {
      corpo = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ErroreApi('generico', r.statusCode);
    }
    if (r.statusCode >= 400 || corpo['success'] != true) {
      final codice = (corpo['codice'] as String?) ??
          (r.statusCode == 401 ? 'chiave_non_valida' : r.statusCode == 429 ? 'troppe_richieste' : 'generico');
      throw ErroreApi(codice, r.statusCode);
    }
    return (corpo['data'] as Map<String, dynamic>?) ?? {};
  }

  static Future<http.Response> _manda(Future<http.Response> Function() chiamata) async {
    try {
      return await chiamata().timeout(_tempo);
    } on SocketException {
      throw ErroreApi('rete');
    } on HttpException {
      throw ErroreApi('rete');
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) throw ErroreApi('rete');
      rethrow;
    }
  }

  /// POST /app/api/entra: salva la chiave e ritorna i dati dell'utente.
  static Future<Map<String, dynamic>> entra(String login, String password, String lingua) async {
    final r = await _manda(() async => http.post(
          _url('/app/api/entra'),
          headers: await _intestazioni(conChiave: false),
          body: jsonEncode({
            'login': login.trim(),
            'password': password,
            'lingua': lingua,
            'telefono': Platform.isIOS ? 'iPhone' : 'Android',
            'piattaforma': Platform.isIOS ? 'ios' : 'android',
            'versione': Config.versione,
          }),
        ));
    final dati = _risposta(r);
    await ArchivioChiave.salva(dati['chiave'] as String);
    return (dati['utente'] as Map<String, dynamic>?) ?? {};
  }

  /// GET /app/api/io: chi e' collegato.
  static Future<Map<String, dynamic>> io() async =>
      _risposta(await _manda(() async => http.get(_url('/app/api/io'), headers: await _intestazioni())));

  /// GET /cliente/api/credito: saldo del credito prepagato ({'attivo': false} se non c'e').
  static Future<Map<String, dynamic>> credito() async =>
      _risposta(await _manda(() async => http.get(_url('/cliente/api/credito'), headers: await _intestazioni())));

  /// POST /app/api/dispositivo: il telefono riceve le notifiche di questo account.
  static Future<void> registraTelefono(String codice, String piattaforma, String lingua, bool attive) async {
    _risposta(await _manda(() async => http.post(
          _url('/app/api/dispositivo'),
          headers: await _intestazioni(),
          body: jsonEncode({
            'codice_notifica': codice,
            'piattaforma': piattaforma,
            'lingua': lingua,
            'versione': Config.versione,
            'notifiche_attive': attive,
          }),
        )));
  }

  /// DELETE /app/api/dispositivo: il telefono non riceve piu' notifiche.
  static Future<void> togliTelefono(String codice) async {
    _risposta(await _manda(() async => http.delete(
          _url('/app/api/dispositivo'),
          headers: await _intestazioni(),
          body: jsonEncode({'codice_notifica': codice}),
        )));
  }

  /// POST /app/api/esci: la chiave smette di valere; si cancella comunque dal telefono.
  static Future<void> esci() async {
    await Notifiche.disattiva();
    await Biometria.dimentica();
    try {
      await _manda(() async => http.post(_url('/app/api/esci'), headers: await _intestazioni()));
    } catch (_) {
      // anche senza rete l'uscita dal telefono deve riuscire
    }
    await ArchivioChiave.cancella();
  }
}
