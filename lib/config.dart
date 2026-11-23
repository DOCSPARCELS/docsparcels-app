/// Indirizzo del gestionale e versione dell'app.
class Config {
  /// Per le prove sull'emulatore si compila con --dart-define=SERVER=http://10.0.2.2:5003
  /// (il Flask del PC); senza, l'app parla col gestionale online.
  static const String indirizzo = String.fromEnvironment('SERVER', defaultValue: 'https://my.docsparcels.com');
  static const String versione = '0.1.0';

  /// Accedi con Google (nota 373 V41): ID client OAuth del progetto Google Cloud
  /// silken-airfoil-305903. Sono pubblici; il segreto del client non serve all'app.
  static const String googleClientWeb = '597046259972-rch4e02d5v169nlfagbcmlpk89lkcbuh.apps.googleusercontent.com';
  static const String googleClientIos = '597046259972-lp3jsmugv9dgqmfd7ueq380tehpmfirc.apps.googleusercontent.com';
}
