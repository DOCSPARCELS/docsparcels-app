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
  ErroreApi(this.codice, [this.stato, this.messaggio, this.corpo]);

  final String codice;
  final int? stato;

  /// Testo dell'errore scritto dal server (gia' nella lingua del cliente), se c'e'
  final String? messaggio;

  /// Risposta completa del server, per i casi da gestire a parte (es. prezzo_aggiornato)
  final Map<String, dynamic>? corpo;

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

  /// Corpo intero della risposta; se il server dice errore lancia ErroreApi.
  static Map<String, dynamic> _corpo(http.Response r) {
    Map<String, dynamic> corpo = {};
    try {
      corpo = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ErroreApi(r.statusCode == 401 ? 'chiave_non_valida' : 'generico', r.statusCode);
    }
    if (r.statusCode >= 400 || corpo['success'] != true) {
      final codice = (corpo['codice'] as String?) ??
          (corpo['documenti_oltre_peso'] == true ? 'documenti_oltre_peso' : null) ??
          (r.statusCode == 401 ? 'chiave_non_valida' : r.statusCode == 429 ? 'troppe_richieste' : 'generico');
      final testo = corpo['error'];
      throw ErroreApi(codice, r.statusCode, testo is String && testo.trim().isNotEmpty ? testo : null, corpo);
    }
    return corpo;
  }

  static Map<String, dynamic> _risposta(http.Response r) =>
      (_corpo(r)['data'] as Map<String, dynamic>?) ?? {};

  static Future<http.Response> _manda(Future<http.Response> Function() chiamata, {Duration tempo = _tempo}) async {
    try {
      return await chiamata().timeout(tempo);
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

  /// GET /api/nazioni/elenco: tutte le nazioni con codice, nome, alias e se il CAP e' obbligatorio.
  static Future<List<Map<String, dynamic>>> nazioni() async {
    final corpo = _corpo(await _manda(() async => http.get(_url('/api/nazioni/elenco'), headers: await _intestazioni())));
    return ((corpo['data'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /api/nazioni/ue: codici delle nazioni UE (fuori UE con un pacco serve la dogana).
  static Future<Set<String>> nazioniUe() async {
    final corpo = _corpo(await _manda(() async => http.get(_url('/api/nazioni/ue'), headers: await _intestazioni())));
    return (((corpo['data'] as Map?)?['codici'] as List?) ?? []).map((c) => '$c'.toUpperCase()).toSet();
  }

  /// POST /cliente/api/calcola: le tariffe che il cliente vede nell'area cliente, gia' in ordine
  /// dalla piu' economica. Il calcolo lo fa tutto il server (listini, sconti, carburante, IVA).
  static Future<List<Map<String, dynamic>>> calcola(Map<String, dynamic> dati) async {
    final corpo = _corpo(await _manda(() async => http.post(
          _url('/cliente/api/calcola'),
          headers: await _intestazioni(),
          body: jsonEncode(dati),
        ), tempo: const Duration(seconds: 90)));  // i corrieri esterni a volte rispondono piano
    final servizi = ((corpo['servizi'] as List?) ?? []).cast<Map<String, dynamic>>();
    servizi.sort((a, b) => ((a['totale'] as num?) ?? 0).compareTo((b['totale'] as num?) ?? 0));
    return servizi;
  }

  // ------------------------------------------------------------ nuova spedizione (nota 367)

  static Future<Map<String, dynamic>> _getCorpo(String percorso) async =>
      _corpo(await _manda(() async => http.get(_url(percorso), headers: await _intestazioni())));

  static Future<Map<String, dynamic>> _postCorpo(String percorso, Map<String, dynamic> dati,
          {Duration tempo = _tempo}) async =>
      _corpo(await _manda(() async => http.post(_url(percorso), headers: await _intestazioni(), body: jsonEncode(dati)),
          tempo: tempo));

  /// Mittente dall'anagrafica, tipologie, imballaggi, assicurazione, prima data valida.
  static Future<Map<String, dynamic>> datiNuovaSpedizione() async =>
      ((await _getCorpo('/cliente/api/nuova_spedizione/dati'))['data'] as Map<String, dynamic>?) ?? {};

  /// Rubrica e indirizzi gia' usati del cliente. Il server risponde con una lista semplice.
  static Future<List<Map<String, dynamic>>> rubrica() async {
    final r = await _manda(() async => http.get(_url('/cliente/api/autocomplete_contatti?q=*&storico=1'),
        headers: await _intestazioni()));
    if (r.statusCode == 401) throw ErroreApi('chiave_non_valida', 401);
    if (r.statusCode >= 400) throw ErroreApi('generico', r.statusCode);
    try {
      return ((jsonDecode(utf8.decode(r.bodyBytes)) as List?) ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      throw ErroreApi('generico', r.statusCode);
    }
  }

  /// Salva in rubrica un mittente o destinatario scritto a mano.
  static Future<void> salvaInRubrica(Map<String, dynamic> contatto) async {
    await _postCorpo('/cliente/api/contatti/aggiungi-da-spedizione', contatto);
  }

  /// Punti dei servizi Point vicino al mittente o al destinatario, con la differenza di prezzo.
  static Future<List<Map<String, dynamic>>> puntiServizio(Map<String, dynamic> dati) async {
    final corpo = await _postCorpo('/cliente/api/punti_servizio', dati, tempo: const Duration(seconds: 40));
    return ((corpo['punti'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  /// Crea o aggiorna la bozza: {spedizione_id, mos, prezzo}. Il prezzo lo rifa' il server.
  static Future<Map<String, dynamic>> salvaBozza(Map<String, dynamic> dati) async =>
      _postCorpo('/cliente/api/salva_bozza_spedizione', dati, tempo: const Duration(seconds: 90));

  static Future<Map<String, dynamic>> datiBozza(int id) async =>
      ((await _getCorpo('/cliente/api/bozze/$id/dati'))['data'] as Map<String, dynamic>?) ?? {};

  /// Come paga il cliente: {prepagato, residuo, sufficiente, rimessa, totale, banca}.
  static Future<Map<String, dynamic>> opzioniPagamento(int bozzaId) async =>
      ((await _getCorpo('/cliente/api/opzioni_pagamento/$bozzaId'))['data'] as Map<String, dynamic>?) ?? {};

  /// Invia la richiesta: {nuova_id, pagamento?, ...}.
  static Future<Map<String, dynamic>> inviaSpedizione(int bozzaId, String? metodo) async =>
      _postCorpo('/cliente/api/invia_spedizione', {'spedizione_id': bozzaId, if (metodo != null) 'metodo_pagamento': metodo},
          tempo: const Duration(seconds: 120));

  static Future<void> eliminaBozza(int bozzaId) async {
    await _postCorpo('/cliente/api/elimina_bozze', {'ids': [bozzaId]});
  }

  /// Pagamento con carta non completato: la spedizione torna bozza.
  static Future<void> annullaPagamento(int spedizioneId) async {
    await _postCorpo('/cliente/api/annulla_pagamento_spedizione/$spedizioneId', {});
  }

  /// Indirizzo completo di una pagina del gestionale (pagamento myPOS).
  static String indirizzo(String percorsoOUrl) =>
      percorsoOUrl.startsWith('http') ? percorsoOUrl : '${Config.indirizzo}$percorsoOUrl';

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
