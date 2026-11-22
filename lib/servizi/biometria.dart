import 'package:flutter/services.dart';
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

  /// Motivo dell'ultimo sblocco non riuscito (nota 373 V11): si mostra, cosi' sull'iPhone si
  /// capisce perche' Face ID non parte invece di fallire in silenzio.
  static String? ultimoErrore;

  /// Il telefono ha Face ID o un'impronta registrata?
  /// Nota 373 V11: su iPhone l'elenco dei tipi puo' arrivare vuoto anche con Face ID attivo
  /// (es. prima della prima richiesta): basta che il telefono sappia fare lo sblocco biometrico.
  static Future<bool> disponibile() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (await _auth.canCheckBiometrics) return true;
      final tipi = await _auth.getAvailableBiometrics();
      return tipi.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> scelta() => _archivio.read(key: _nome);

  static Future<void> salvaScelta(bool usa) => _archivio.write(key: _nome, value: usa ? 'si' : 'no');

  static Future<void> dimentica() => _archivio.delete(key: _nome);

  /// Chiede lo sblocco, con i testi della finestra nella lingua dell'app. Ritorna true se riuscito;
  /// se non riesce per un errore, il motivo resta in [ultimoErrore].
  static Future<bool> sblocca(Testi testi) async {
    ultimoErrore = null;
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
    } on LocalAuthException catch (e) {
      // local_auth 3: anche l'annullamento e il «sistema occupato» arrivano come errore con un codice
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
          ultimoErrore = null;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          ultimoErrore = testi.t('biometria_non_disponibile');
        default:
          ultimoErrore = '${testi.t('biometria_non_riuscita')} (${e.code.name})';
      }
      return false;
    } on PlatformException catch (e) {
      ultimoErrore = '${testi.t('biometria_non_riuscita')} (${e.code})';
      return false;
    } catch (_) {
      ultimoErrore = testi.t('biometria_non_riuscita');
      return false;
    }
  }
}
