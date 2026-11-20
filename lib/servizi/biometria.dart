import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

import '../testi.dart';

/// Sblocco con Face ID o impronta. La scelta del cliente resta nel portachiavi del telefono:
/// 'si' = la chiave si apre solo con lo sblocco, 'no' = entrata normale, assente = da chiedere.
class Biometria {
  static final _auth = LocalAuthentication();
  static const _archivio = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _nome = 'usa_biometria';

  /// Il telefono ha Face ID o un'impronta registrata?
  static Future<bool> disponibile() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final tipi = await _auth.getAvailableBiometrics();
      return tipi.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> scelta() => _archivio.read(key: _nome);

  static Future<void> salvaScelta(bool usa) => _archivio.write(key: _nome, value: usa ? 'si' : 'no');

  static Future<void> dimentica() => _archivio.delete(key: _nome);

  /// Chiede lo sblocco, con i testi della finestra nella lingua dell'app. Ritorna true se riuscito.
  static Future<bool> sblocca(Testi testi) async {
    try {
      return await _auth.authenticate(
        localizedReason: testi.t('motivo_sblocco'),
        biometricOnly: true,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: testi.t('sblocco_titolo'),
            signInHint: testi.t('sblocco_suggerimento'),
            cancelButton: testi.t('annulla'),
          ),
          IOSAuthMessages(cancelButton: testi.t('annulla')),
        ],
      );
    } catch (_) {
      return false;
    }
  }
}
