import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tema dell'app (nota 373 V3): «Automatico» segue il telefono (valore iniziale), oppure
/// sempre chiaro o sempre scuro, scelto in «Il mio profilo». Si salva sul telefono.
class TemaApp {
  static const _archivio = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _nome = 'tema_app';

  static final scelta = ValueNotifier<ThemeMode>(ThemeMode.system);

  static const _valori = {'sistema': ThemeMode.system, 'chiaro': ThemeMode.light, 'scuro': ThemeMode.dark};

  static Future<void> carica() async {
    try {
      scelta.value = _valori[await _archivio.read(key: _nome)] ?? ThemeMode.system;
    } catch (_) {
      // senza scelta salvata segue il telefono
    }
  }

  static Future<void> imposta(ThemeMode modo) async {
    scelta.value = modo;
    try {
      await _archivio.write(key: _nome, value: _valori.entries.firstWhere((e) => e.value == modo).key);
    } catch (_) {}
  }
}
