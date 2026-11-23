import 'dart:io';

import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Credenziali di Apple da mandare al gestionale (nota 373 V43).
class CredenzialiApple {
  CredenzialiApple(this.gettone, this.codice, this.nome);

  /// identity_token firmato da Apple: il gestionale lo controlla
  final String gettone;

  /// authorization_code: il gestionale lo scambia con Apple per poter revocare l'accesso
  final String codice;

  /// Nome e cognome: Apple li da' solo al primo accesso
  final String nome;
}

/// Accedi con Apple (nota 373 V43): solo iPhone.
class AccessoApple {
  /// Il pulsante si mostra solo su iPhone ([perProve] lo forza nelle prove automatiche)
  static bool? perProve;
  static bool get previsto => perProve ?? Platform.isIOS;

  /// Credenziali di Apple, oppure null se la persona ha chiuso la finestra di Apple.
  /// Lancia [ErroreApple] se l'accesso non e' possibile.
  static Future<CredenzialiApple?> credenziali() async {
    try {
      if (!await SignInWithApple.isAvailable()) throw ErroreApple('non_disponibile');
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final gettone = c.identityToken;
      if (gettone == null || gettone.isEmpty) throw ErroreApple('senza_gettone');
      final nome = [c.givenName, c.familyName].where((v) => v != null && v.trim().isNotEmpty).join(' ');
      return CredenzialiApple(gettone, c.authorizationCode, nome);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw ErroreApple(e.code.name, e.message);
    }
  }
}

class ErroreApple implements Exception {
  ErroreApple(this.codice, [this.dettaglio]);

  final String codice;
  final String? dettaglio;

  @override
  String toString() => 'ErroreApple($codice${dettaglio == null ? '' : ': $dettaglio'})';
}
