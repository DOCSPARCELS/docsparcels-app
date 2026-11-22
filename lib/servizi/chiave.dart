import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// La chiave personale dell'app, nel portachiavi del telefono
/// (Keychain su iPhone, Keystore su Android). Mai in chiaro.
class ArchivioChiave {
  static const _archivio = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  static const _nome = 'chiave_app';

  static Future<String?> leggi() => _archivio.read(key: _nome);

  static Future<void> salva(String chiave) => _archivio.write(key: _nome, value: chiave);

  static Future<void> cancella() => _archivio.delete(key: _nome);

  /// Nota 373 V11: l'ultima email (o nome utente) con cui si e' entrati, per riproporla
  /// all'accesso; resta anche dopo l'uscita.
  static Future<String?> ultimoLogin() => _archivio.read(key: 'ultimo_login');

  static Future<void> salvaLogin(String login) => _archivio.write(key: 'ultimo_login', value: login);
}
