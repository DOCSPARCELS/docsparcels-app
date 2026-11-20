# Doc's & Parcels - app per i clienti

App Flutter per iPhone e Android, bundle `com.docsparcels.app`. Parla con il gestionale
(`https://my.docsparcels.com`) attraverso gli indirizzi `/app/api/...` e quelli dell'area
cliente, con la chiave personale nell'intestazione `X-App-Chiave`.

## Primo avvio dopo l'installazione di Flutter

```
cd C:\docsparcels_app
flutter create --org com.docsparcels --project-name docsparcels_app --platforms android,ios .
flutter pub get
```

Il primo comando crea le cartelle `android` e `ios` senza toccare `lib`. Poi:
- in `android/app/build.gradle` l'`applicationId` deve essere `com.docsparcels.app`;
- `google-services.json` va copiato in `android/app/` e `GoogleService-Info.plist` in `ios/Runner/`
  dalla cartella chiavi di Luca: sono esclusi da git (`.gitignore`) e non vanno su Drive.

## Schermate fatte
- Entrata (email o nome utente e password) → `POST /app/api/entra`, chiave nel portachiavi del telefono.
- Profilo: nome, codice cliente, credito disponibile (`/app/api/io` e `/cliente/api/credito`), uscita (`/app/api/esci`).
- Sblocco con Face ID / impronta e notifiche sul telefono (Firebase).

## Lingue
Italiano, inglese, spagnolo, francese e tedesco (`lib/testi.dart`), secondo la lingua del telefono.
La prova automatica controlla che ogni lingua abbia tutti i testi dell'italiano.

## iPhone con Codemagic (`codemagic.yaml`)
Codemagic compila la versione iPhone sui suoi Mac e la manda in TestFlight. Serve:
- il codice in un repository git (i file di Firebase e le chiavi restano fuori, vedi `.gitignore`);
- in Codemagic, Team settings > Integrations > Developer Portal: la chiave App Store Connect chiamata
  esattamente «DocsParcels App Store»;
- nell'app su Codemagic, gruppo di variabili «firebase» con `GOOGLE_SERVICE_INFO_PLIST` = il file
  `GoogleService-Info.plist` in base64 (variabile «Secure»);
- in `codemagic.yaml`, `APP_STORE_APPLE_ID` = il numero dell'app in App Store Connect.
Il progetto iPhone ha già il file Firebase tra le risorse, il permesso per le notifiche push
(`ios/Runner/Runner.entitlements`, aps-environment production) e le notifiche in background.
