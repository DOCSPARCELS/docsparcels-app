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

  // ------------------------------------------------------------ le mie spedizioni (nota 368)

  /// Elenco come nel sito: stato '' (tutte), 'transito', 'consegnate', 'bozze'.
  /// {spedizioni: [...], pagina, pagine, totale}
  static Future<Map<String, dynamic>> leMieSpedizioni({String stato = '', String cerca = '', int pagina = 1}) async {
    final parametri = Uri(queryParameters: {
      'stato': stato,
      'search': cerca,
      'page': '$pagina',
      'page_size': '25',
    }).query;
    return ((await _getCorpo('/cliente/api/le_mie_spedizioni?$parametri'))['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Riepilogo della spedizione (stato, servizio, colli, mittente, destinatario, totale).
  /// [vecchia] = spedizione del gestionale precedente.
  static Future<Map<String, dynamic>> spedizione(int id, {bool vecchia = false}) async =>
      ((await _getCorpo(vecchia ? '/cliente/api/anteprima-vecchia/$id' : '/cliente/api/anteprima/$id'))['data']
          as Map<String, dynamic>?) ??
      {};

  /// Passaggi del tracciamento, dal piu' recente: {data, ora, testo, luogo}.
  /// Il server li manda in due forme (dai corrieri o dalla cache): qui diventano una sola.
  static Future<List<Map<String, String>>> tracciamento(int id) async {
    final corpo = await _getCorpo('/api/tracking/tracking/spedizioni/$id/events');
    String testo(dynamic v) => v == null ? '' : '$v'.trim();
    return [
      for (final e in ((corpo['events'] as List?) ?? []).cast<Map<String, dynamic>>())
        {
          'data': dataBreve(testo(e['data'] ?? e['date'])),
          'ora': testo(e['ora'] ?? e['time']),
          'testo': frase(testo(e['commento_personalizzato']).isNotEmpty
              ? testo(e['commento_personalizzato'])
              : testo(e['commento'] ?? e['description'])),
          'luogo': nomeProprio(testo(e['location']).isNotEmpty ? testo(e['location']) : testo(e['city'])),
        }
    ];
  }

  /// AAAA-MM-GG (o GG/MM/AAAA) -> gg.mm.aa; il resto com'e'.
  static String dataBreve(String v) {
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v);
    if (iso != null) return '${iso[3]}.${iso[2]}.${iso[1]!.substring(2)}';
    final barre = RegExp(r'^(\d{2})/(\d{2})/(\d{2,4})$').firstMatch(v);
    if (barre != null) return '${barre[1]}.${barre[2]}.${barre[3]!.substring(barre[3]!.length - 2)}';
    return v;
  }

  static bool _stampatello(String v) => v.contains(RegExp(r'[A-Z]')) && v == v.toUpperCase();

  /// Testo dei corrieri in stampatello: solo la prima lettera maiuscola.
  static String frase(String v) {
    if (!_stampatello(v)) return v;
    final minuscolo = v.toLowerCase();
    return minuscolo.isEmpty ? v : minuscolo[0].toUpperCase() + minuscolo.substring(1);
  }

  static const _piccole = {'di', 'de', 'del', 'della', 'dei', 'da', 'il', 'lo', 'la', 'e', 'o'};

  /// Luoghi in stampatello: maiuscola a ogni parola, sigle fra parentesi e nazioni di due lettere intatte.
  static String nomeProprio(String v) {
    if (!_stampatello(v)) return v;
    var primo = true;
    return v.split(' ').map((p) {
      final parola = p;
      final e = primo;
      primo = false;
      if (RegExp(r'^\(?[A-Z]{2}\)?,?$').hasMatch(parola) && !e) return parola;
      final m = parola.toLowerCase();
      if (!e && _piccole.contains(m)) return m;
      return m.split('-').map((x) => x.isEmpty ? x : x[0].toUpperCase() + x.substring(1)).join('-');
    }).join(' ');
  }

  /// Documenti scaricabili: [{tipo: awb|proforma|allegato|dogana|reso, nome, url}].
  static Future<List<Map<String, String>>> documenti(int id) async {
    final d = ((await _getCorpo('/api/spedizioni/$id/documenti'))['documenti'] as Map<String, dynamic>?) ?? {};
    final voci = <Map<String, String>>[];
    if (d['awb_url'] != null) voci.add({'tipo': 'awb', 'nome': '', 'url': '${d['awb_url']}'});
    if (d['proforma_url'] != null) voci.add({'tipo': 'proforma', 'nome': '', 'url': '${d['proforma_url']}'});
    for (final a in ((d['ddt_allegati'] as List?) ?? []).cast<Map<String, dynamic>>()) {
      voci.add({'tipo': 'allegato', 'nome': '${a['nome_originale'] ?? ''}', 'url': '${a['url']}'});
    }
    for (final a in ((d['documenti_doganali_manuali'] as List?) ?? []).cast<Map<String, dynamic>>()) {
      voci.add({'tipo': 'dogana', 'nome': '${a['nome'] ?? a['tipo'] ?? ''}', 'url': '${a['url']}'});
    }
    if (d['reverse_qr_url'] != null) voci.add({'tipo': 'reso', 'nome': '', 'url': '${d['reverse_qr_url']}'});
    return voci;
  }

  /// Chi paga manda l'etichetta al mittente (nota 368 V3). canale 'email': {messaggio};
  /// canale 'whatsapp': {testo, link, whatsapp} con il link firmato all'etichetta (7 giorni).
  static Future<Map<String, dynamic>> etichettaAlMittente(int id, String canale, {String? email, String? telefono}) async =>
      ((await _postCorpo('/cliente/api/spedizione/$id/etichetta_al_mittente',
              {'canale': canale, if (email != null) 'email': email, if (telefono != null) 'telefono': telefono},
              tempo: const Duration(seconds: 60)))['data']
          as Map<String, dynamic>?) ??
      {};

  /// Scarica un documento con la chiave dell'app (i PDF non si aprono senza).
  static Future<List<int>> scarica(String percorsoOUrl) async {
    final r = await _manda(() async => http.get(Uri.parse(indirizzo(percorsoOUrl)), headers: await _intestazioni()),
        tempo: const Duration(seconds: 60));
    if (r.statusCode == 401) throw ErroreApi('chiave_non_valida', 401);
    if (r.statusCode >= 400 || r.bodyBytes.isEmpty) throw ErroreApi('documento_non_disponibile', r.statusCode);
    return r.bodyBytes;
  }

  // ------------------------------------------------------------ pagamenti e fatture (nota 369)

  /// {spedizioni: [{id, data, destinatario, dest_citta, servizio, importo, scadenza_link, pagamento}],
  ///  fatture: {quante, totale, scadute}}
  static Future<Map<String, dynamic>> pagamentiAperti() async =>
      ((await _getCorpo('/cliente/api/pagamenti_aperti'))['data'] as Map<String, dynamic>?) ?? {};

  /// stato: '' (tutte), 'da_pagare', 'pagate'. {fatture, pagina, pagine, totale_fatture}
  static Future<Map<String, dynamic>> fatture({String stato = '', int pagina = 1, int perPagina = 25}) async {
    final q = Uri(queryParameters: {'stato': stato, 'pagina': '$pagina', 'per_pagina': '$perPagina'}).query;
    return ((await _getCorpo('/cliente/api/fatture?$q'))['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Fattura con le righe.
  static Future<Map<String, dynamic>> fattura(int id) async =>
      ((await _getCorpo('/cliente/api/fatture/$id'))['data'] as Map<String, dynamic>?) ?? {};

  /// Paga una o piu' fatture: metodo 'credito' | 'carta' | 'bonifico'.
  /// Risposta: {metodo, importo, causale, url (carta), banca (bonifico)}.
  static Future<Map<String, dynamic>> pagaFatture(List<int> ids, String metodo) async =>
      _postCorpo('/cliente/api/paga_fatture', {'ids': ids, 'metodo': metodo}, tempo: const Duration(seconds: 60));

  /// Paga una spedizione in attesa di pagamento: metodo 'carta' | 'bonifico'.
  static Future<Map<String, dynamic>> pagaSpedizione(int id, String metodo) async =>
      _postCorpo('/cliente/api/paga_spedizione/$id', {'metodo': metodo}, tempo: const Duration(seconds: 60));

  /// Richiesta di ricarica del credito (minimo € 10): metodo 'carta' | 'bonifico'.
  static Future<Map<String, dynamic>> richiediRicarica(double importo, String metodo) async =>
      _postCorpo('/cliente/api/richiedi_ricarica', {'importo': importo, 'metodo': metodo},
          tempo: const Duration(seconds: 60));

  /// Soglia sotto la quale il gestionale avvisa che il credito sta finendo.
  static Future<void> salvaSoglia(double soglia) async {
    await _postCorpo('/cliente/api/soglia_credito', {'soglia': soglia});
  }

  // ------------------------------------------------------------ profilo (nota 372)

  /// {nome, cognome, email, nome_utente, codice, registrato_il, ultimo_accesso, societa, foto}
  static Future<Map<String, dynamic>> mioAccount() async =>
      ((await _getCorpo('/cliente/api/mio_account'))['data'] as Map<String, dynamic>?) ?? {};

  static Future<Map<String, dynamic>> salvaAccount(String nome, String cognome, String email) async =>
      ((await _postCorpo('/profile/dati', {'nome': nome, 'cognome': cognome, 'email': email}))['data']
          as Map<String, dynamic>?) ??
      {};

  static Future<void> cambiaPassword(String attuale, String nuova, String conferma) async {
    await _postCorpo('/profile/password', {'attuale': attuale, 'nuova': nuova, 'conferma': conferma});
  }

  /// Foto del profilo (JPG, PNG o WebP, massimo 5 MB): il server la ritaglia quadrata.
  static Future<String?> caricaFoto(List<int> byte, String nomeFile) async {
    final richiesta = http.MultipartRequest('POST', _url('/profile/avatar'))
      ..headers['X-App-Chiave'] = await ArchivioChiave.leggi() ?? ''
      ..headers['Accept'] = 'application/json'
      ..files.add(http.MultipartFile.fromBytes('immagine', byte, filename: nomeFile));
    final r = await _manda(() async => http.Response.fromStream(await richiesta.send()),
        tempo: const Duration(seconds: 60));
    return (_risposta(r)['url'] as String?);
  }

  static Future<void> togliFoto() async {
    _corpo(await _manda(() async => http.delete(_url('/profile/avatar'), headers: await _intestazioni())));
  }

  /// Intestazioni per leggere la foto del profilo (serve la chiave).
  static Future<Map<String, String>> intestazioniImmagine() async =>
      {'X-App-Chiave': await ArchivioChiave.leggi() ?? ''};

  /// {id, modificabili: {...}, solo_lettura: {...}, condizioni: {...}}
  static Future<Map<String, dynamic>> miaScheda() async =>
      ((await _getCorpo('/cliente/api/mia_scheda'))['data'] as Map<String, dynamic>?) ?? {};

  /// Salva campi di un contatto della rubrica o della propria scheda (solo quelli cambiati).
  static Future<void> aggiornaContatto(int id, Map<String, dynamic> campi) async {
    await _postCorpo('/cliente/api/contatti/$id/aggiorna', campi);
  }

  /// Nuovo contatto in rubrica: {contatto_id, codice}.
  static Future<Map<String, dynamic>> nuovoContatto(Map<String, dynamic> campi) async =>
      _postCorpo('/cliente/api/contatti/salva', campi);

  static Future<void> eliminaContatto(int id) async {
    await _postCorpo('/cliente/api/contatti/$id/elimina', {});
  }

  /// Lingua dei testi del server e delle notifiche (it, en, es, fr, de).
  static Future<void> cambiaLingua(String lingua) async {
    await _postCorpo('/app/api/lingua', {'lingua': lingua});
  }

  /// Elimina l'account (serve la password). L'account viene disattivato subito.
  static Future<void> eliminaAccount(String password) async {
    await _postCorpo('/app/api/elimina_account', {'password': password});
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
