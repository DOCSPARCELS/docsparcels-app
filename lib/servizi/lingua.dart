import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../testi.dart';

/// Lingua scelta nel profilo (nota 372). Senza scelta l'app segue la lingua del telefono.
/// Si salva sul telefono, accanto alla chiave, e resta anche dopo l'uscita.
class LinguaApp {
  static const _archivio = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _nome = 'lingua_app';

  /// null = lingua del telefono
  static final scelta = ValueNotifier<Locale?>(null);

  static Future<void> carica() async {
    try {
      final lingua = await _archivio.read(key: _nome);
      if (lingua != null && Testi.lingue.contains(lingua)) scelta.value = Locale(lingua);
    } catch (_) {
      // senza la scelta salvata vale la lingua del telefono
    }
  }

  static Future<void> imposta(String lingua) async {
    scelta.value = Locale(lingua);
    try {
      await _archivio.write(key: _nome, value: lingua);
    } catch (_) {}
  }
}
