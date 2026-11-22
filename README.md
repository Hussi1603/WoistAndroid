# Wo ist? 📍

Eine App wie Apples „Wo ist?“, die **auf iPhone und Android** läuft. Ihr könnt euch gegenseitig auf einer Karte sehen, mit Akkustand, Entfernung und der Zeit seit der letzten Aktualisierung. Ein Tipp auf „Route“ öffnet Apple Karten oder Google Maps.

## Funktionen

- Live-Karte (OpenStreetMap) mit allen Personen, die ihren Standort mit dir teilen
- Ortung im Hintergrund (Android: Vordergrund-Dienst mit Benachrichtigung, iOS: Background Location)
- Einladung per 6-stelligem Code
- Wie bei Apple teilt jede Person ihren Standort aktiv und einzeln. Das Teilen lässt sich pausieren oder für einzelne Personen beenden.
- Akkustand und Ladezustand, Entfernung, „vor X Min.“
- Navigation zur Person (Apple Karten / Google Maps)
- Konto löschen (alle Daten werden entfernt)

## So koppelt ihr euch

1. Beide installieren die App und geben ihren Namen ein.
2. Im Tab **„Ich“** steht dein Code, z. B. `K7P 2QX`.
3. **Du** tippst auf „Standort teilen mit …“ und gibst den Code **deiner Freundin** ein. Ab dann sieht sie dich.
4. **Sie** macht dasselbe mit **deinem** Code. Ab dann siehst du sie.

---

## Einrichtung (einmalig, ca. 20 Minuten)

### 1. Werkzeuge

- [Flutter](https://docs.flutter.dev/get-started/install) (stable)
- Für Android: Android Studio
- Für das iPhone: ein Mac mit Xcode (Apple erlaubt das Bauen von iOS-Apps nur auf macOS)
- Firebase-CLI: `npm install -g firebase-tools`, danach `dart pub global activate flutterfire_cli`

### 2. Firebase-Projekt anlegen (kostenlos)

1. Unter <https://console.firebase.google.com> ein neues Projekt anlegen (Google Analytics ist nicht nötig).
2. **Authentication → Anmeldemethode → „Anonym“ aktivieren.**
3. **Firestore Database → Datenbank erstellen** (Region z. B. `eur3`, im Produktionsmodus starten).

Der kostenlose „Spark“-Tarif reicht für zwei Personen locker aus.

### 3. Projekt vorbereiten

```bash
git clone <dieses-repo> && cd WoistAndroid
bash tool/setup_platforms.sh        # erzeugt android/ und ios/ mit allen Berechtigungen
firebase login
flutterfire configure               # Firebase-Projekt wählen, Plattformen: android, ios
firebase deploy --only firestore:rules --project <deine-projekt-id>
```

`flutterfire configure` überschreibt `lib/firebase_options.dart` mit deinen Projektdaten. Diese Datei darf committet werden: Die Schlüssel darin sind keine Geheimnisse, den Zugriff regeln die Firestore-Regeln.

### 4. Auf die Handys bringen

**Android:**

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk aufs Handy kopieren und installieren
# oder direkt per USB: flutter install
```

**iPhone** (am Mac, iPhone per Kabel verbunden):

```bash
open ios/Runner.xcworkspace
```

In Xcode: **Runner → Signing & Capabilities → Team** auswählen. Eine kostenlose Apple-ID reicht. Danach das iPhone als Ziel wählen und auf ▶︎ klicken. Auf dem iPhone unter *Einstellungen → Allgemein → VPN & Geräteverwaltung* dem Entwickler vertrauen.

> Mit einer **kostenlosen** Apple-ID läuft die App nur **7 Tage** und muss dann neu aufgespielt werden. Mit dem Apple Developer Program (99 €/Jahr) läuft sie ein Jahr, und du kannst sie per **TestFlight** verteilen, ganz ohne Kabel.

### 5. Wichtige Einstellungen auf den Handys

- **iPhone:** Einstellungen → Wo ist? → Standort → **„Immer“** und „Genauer Standort“ an. Die App nicht aus dem App-Umschalter wegwischen, sonst stoppt iOS die Ortung bis zum nächsten Öffnen.
- **Android:** Standort → **„Immer zulassen“**. Im Tab „Ich“ auf **„Akku-Optimierung ausschalten“** tippen. Bei Samsung, Xiaomi und Huawei die App zusätzlich in den Akku-Einstellungen von „Schlafen“ ausnehmen.

---

## Technik

| Teil | Lösung |
|---|---|
| App | Flutter (eine Codebasis für iOS und Android) |
| Anmeldung | Firebase Anonymous Auth (kein Passwort nötig) |
| Datenbank | Cloud Firestore, Echtzeit-Updates |
| Karte | `flutter_map` + OpenStreetMap (kein API-Schlüssel nötig) |
| Ortung | `geolocator` mit Hintergrund-Modus |

**Datenschutz:** Die Firestore-Regeln (`firestore.rules`) sorgen dafür, dass nur Personen deinen Standort lesen können, die du selbst per Code freigegeben hast. Gespeichert wird nur der jeweils letzte Standort, es gibt keinen Verlauf.

**CI:** GitHub Actions (`.github/workflows/build.yml`) prüft den Code, baut bei jedem Push eine Android-APK (als Download unter „Actions“) und testet, ob sich die iOS-App kompilieren lässt.

## Grenzen im Vergleich zu Apples „Wo ist?“

- Apples App ist ins System eingebaut. Eine normale App kann ein ausgeschaltetes Gerät nicht finden und keinen Ton abspielen lassen, wenn die App beendet ist.
- Wird die App auf dem iPhone weggewischt, pausiert die Ortung, bis sie wieder geöffnet wird.
- Wird die App neu installiert, entsteht ein neues anonymes Konto. Ihr müsst euch dann neu koppeln.
