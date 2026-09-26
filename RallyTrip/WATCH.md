# RallyTrip auf der Apple Watch

Die Begleitapp benötigt watchOS 10 oder neuer und die gekoppelte RallyTrip-iPhone-App ab iOS 17. GPS, Streckenzähler, Kalibrierung und Prüfungszeit laufen ausschließlich auf dem iPhone. Die Watch dient zur Anzeige und Fernsteuerung.

## Bedienung

1. RallyTrip auf dem iPhone öffnen und genauen Standort erlauben. Alternativ den Demo-Modus in den iPhone-Einstellungen einschalten.
2. RallyTrip auf der gekoppelten Watch öffnen. Auf „iPhone verbunden“ warten.
3. **Fahrt starten** beginnt eine normale Aufzeichnung. **WP starten** startet die vorbereitete Wertungsprüfung und bei Bedarf zugleich eine neue Fahrt. Schnittplan, Kalibrierung und geplante Startzeit werden weiterhin am iPhone eingerichtet.
4. Während der WP zeigt die Watch **+ = zu spät**, **− = zu früh** und **Im Takt** innerhalb ±0,5 Sekunden. Die Anzeige verwendet Zehntelsekunden. Bei GPS-Ausfall oder Messpause wird keine gültige Live-Abweichung vorgetäuscht.
5. Unter **Korrektur** die **Digital Crown drehen**: in 1-Meter-Schritten von −100 bis +100 Metern. Das Wertefeld erhält beim Öffnen den Fokus und lässt sich zum erneuten Fokussieren antippen. Die Vorschau zeigt den korrigierten Total-Wert. Erst **Übernehmen** sendet die Änderung; **Verwerfen** setzt die Auswahl zurück. Nach bestätigter Ausführung springt der Einstellwert auf null. Das wirkt wie die iPhone-Korrektur auch auf die WP-Distanz. Trip, GPS-Rohstrecke und Fahrzeug-Kalibrierfaktor bleiben unverändert.
6. Nach einem Befehl auf die iPhone-Bestätigung warten. Bei fehlender Bestätigung zuerst den Zustand am iPhone prüfen: ein Befehl kann ausgeführt worden sein, obwohl seine Antwort nicht angekommen ist.

Start erfolgt beim Empfang auf dem iPhone, nicht rückwirkend zum Zeitpunkt des Tippens auf der Watch. WatchConnectivity garantiert keine sekundengenaue Übertragung. Für einen vorgegebenen exakten Startzeitpunkt die vorhandene Planung am iPhone verwenden. Die Watch kann einen geplanten Start anzeigen, aber keinen laufenden Countdown durch einen weiteren Start überschreiben.

## Verbindung und Aktualität

- Die aktive Watch fragt ungefähr einmal pro Sekunde den aktuellen iPhone-Zustand ab. Tatsächliche Übertragungszeit und Hintergrundausführung hängen vom System ab; eine permanente Live-Anzeige bei gesenktem Handgelenk wird nicht versprochen.
- Daten älter als drei Sekunden gelten als veraltet. Die Abweichung verschwindet und Start/Korrektur sind gesperrt. Total bleibt ausdrücklich als letzter Stand erkennbar.
- Das iPhone sendet zusätzlich höchstens alle fünf Sekunden einen ersetzbaren Zustands-Cache über `updateApplicationContext`. Er ist keine Warteschlange für Aktionen.
- Steuerbefehle verwenden ausschließlich `sendMessage` mit Antwort. Sie werden nicht über `transferUserInfo` gepuffert und nicht automatisch wiederholt.
- Das iPhone lehnt Befehle älter als fünf Sekunden, unpassende Fahrtkennungen, unbekannte Protokollversionen und nicht erlaubte Zustände ab. Start und Korrektur sind bei laufender Kalibrierung gesperrt; WP-Start auch bei Pause, laufender WP oder geplantem Start.
- Bereits bearbeitete Befehls-IDs behalten ihre Antwort 30 Sekunden, damit eine doppelte Zustellung keine zweite Korrektur auslöst. Beim Starten und Beenden einer Fahrt sowie nach einem App-Neustart wechselt die Fahrtkennung.
- Verbindung und Bestätigung werden durch Text und Haptik sichtbar. Ein manuell erneut getippter Befehl ist eine neue Aktion; bei unklarem Ausgang deshalb zuerst das iPhone prüfen.

## Projekt und Installation

- Neues eigenständiges SwiftUI-Target **RallyWatch**, als Begleitapp in das iPhone-Produkt eingebettet.
- Watch-Bundle-ID: `de.rallytrip.app.watchkitapp`; zugehörige iPhone-ID: `de.rallytrip.app`. Bei eigener Signierung beide IDs einschließlich `WKCompanionAppBundleIdentifier` in `RallyWatch/Info.plist` gemeinsam anpassen.
- In Xcode für beide Targets dasselbe Entwicklungsteam wählen. Zuerst die iPhone-App installieren, dann das Scheme **RallyWatch** mit einer gekoppelten Apple Watch starten. Alternativ die Begleitapp über die Watch-App des iPhones installieren, sobald der signierte Build auf dem iPhone vorhanden ist.
- `node scripts/generate-project.mjs` erzeugt beide Targets und Schemes einschließlich Abhängigkeit und Einbettung reproduzierbar.
- Der Core-Test verwendet `WatchProtocol.swift` über Swift Package Manager; beide App-Targets kompilieren dieselbe Datei direkt. Die Watch bindet keine iPhone-UI oder Core-Location-Services ein.
- Der bestehende CI-Workflow baut künftig zusätzlich das Watch-Scheme. Änderungen an CI-Dateien sind keine Bestätigung eines ausgeführten Builds.

Auf einem Mac:

```sh
swift test
xcodebuild -project RallyTrip.xcodeproj -scheme RallyTrip \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project RallyTrip.xcodeproj -scheme RallyWatch \
  -configuration Debug -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Noch am Gerät prüfen

1. Beide Apps auf gekoppelten Geräten installieren, Verbindung herstellen; normale Fahrt und WP aus Bereitschaft sowie WP aus laufender Fahrt starten.
2. Gegenüber dem iPhone positive/negative Abweichung, GPS-Ausfall, Pause und geplanten Countdown vergleichen.
3. Krone in beide Richtungen drehen, 1-Meter-Schritte sowie die Grenzen −100/+100 prüfen. Drehen allein ändert die iPhone-Strecke nicht. Übernehmen, Verwerfen, Bestätigung und Verbindungsfehler prüfen; bei unbekanntem Ausgang bleibt der Entwurf bestehen. Neue Fahrt verwirft den alten Entwurf. Negative Korrektur nahe null und Auswirkung auf die laufende WP prüfen. Trip bleibt unverändert.
4. Bluetooth/Verbindung unterbrechen, Handgelenk senken, iPhone sperren und Apps erneut öffnen: Werte werden bei Verlust veraltet; keine Korrekturen werden später aus einer Warteschlange nachgeholt.
5. Schnelles Mehrfachtippen, verzögerte Antworten und App-Neustart prüfen. Während ausstehender Bestätigung ist keine weitere Steueraktion verfügbar. Nach Fahrtende darf ein alter Befehl keine neue Fahrt verändern.
6. Kleine Watch, große Systemschrift und VoiceOver testen; Werte und Korrekturknöpfe bleiben scrollbar erreichbar.

## Apple-Quellen

- [Watch-Projekt einrichten](https://developer.apple.com/documentation/watchos-apps/setting-up-a-watchos-project): Watch-Target in bestehendem iPhone-Projekt.
- [Single-target Watch-App](https://developer.apple.com/documentation/watchkit/wkapplication): moderner Aufbau ohne separate WatchKit-Extension.
- [WCSession](https://developer.apple.com/documentation/watchconnectivity/wcsession): Aktivierung, Erreichbarkeit und ersetzbarer Anwendungskontext.
- [Direkte Nachrichten](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)): asynchroner Austausch mit Antwort und Fehlerbehandlung.
- [Digital Crown](https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:from:through:by:sensitivity:iscontinuous:ishapticfeedbackenabled:)): fokussierte Werteingabe mit begrenztem Bereich, Schrittweite und haptischem Feedback.

Stand dieser Umsetzung: 40 Core- und Protokolltests bestanden, ebenso Syntax-/Strukturprüfung. Ein CI-Build des parallel veröffentlichten Zwischenstands scheiterte an einem iPhone-Schriftinitialwert, der lokal korrigiert wurde. Ein erfolgreicher vollständiger Apple-SDK-Build des Abschlussstands sowie Signierung und reale Watch-Kommunikation stehen noch aus; Details in [VALIDATION.md](VALIDATION.md).
