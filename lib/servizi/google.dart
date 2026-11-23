import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';

/// Accedi con Google (nota 373 V41): chiede a Google chi e' la persona e ritorna il
/// gettone firmato (id_token) da mandare al gestionale, che lo controlla.
class AccessoGoogle {
  static bool _pronto = false;

  static Future<void> _prepara() async {
    if (_pronto) return;
    await GoogleSignIn.instance.initialize(
      // Su iPhone serve l'ID client iOS; su Android basta quello del gestionale
      clientId: Platform.isIOS ? Config.googleClientIos : null,
      serverClientId: Config.googleClientWeb,
    );
    _pronto = true;
  }

  /// Gettone Google, oppure null se la persona ha chiuso la finestra di Google.
  /// Lancia [ErroreGoogle] se l'accesso non e' possibile su questo telefono.
  static Future<String?> gettone() async {
    try {
      await _prepara();
      if (!GoogleSignIn.instance.supportsAuthenticate()) throw ErroreGoogle('non_disponibile');
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email']);
      final gettone = account.authentication.idToken;
      if (gettone == null || gettone.isEmpty) throw ErroreGoogle('senza_gettone');
      return gettone;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ErroreGoogle(e.code.name, e.description);
    }
  }

  /// All'uscita dall'app: la prossima volta Google richiede quale account usare.
  static Future<void> esci() async {
    try {
      await _prepara();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

class ErroreGoogle implements Exception {
  ErroreGoogle(this.codice, [this.dettaglio]);

  final String codice;
  final String? dettaglio;

  @override
  String toString() => 'ErroreGoogle($codice${dettaglio == null ? '' : ': $dettaglio'})';
}
