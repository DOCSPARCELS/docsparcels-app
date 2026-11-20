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
}
