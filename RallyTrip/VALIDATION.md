## Akustisches Feedback und Einstellungsmenü, 27. September 2026

- 63 Core-Tests unter Swift 6.3.3 / WSL erfolgreich. Sechs neue Tests prüfen Tonkadenz und Grünbereich, Stummschaltung/fehlende Daten, Countdown-Priorität und Rundenwechsel, übersprungene Sekunden, Einstellungsdefaults/-persistenz/-umkehrung sowie PCM-Dateiaufbau, Frequenzen und Ausblendung der Töne.
- Projektstrukturprüfung und Swift-Syntaxprüfung erfolgreich. [CI-Lauf 36330802246](https://github.com/JuCoBe/RallyTrip/actions/runs/36330802246) für `8f98571` erfolgreich: alle 63 Tests unter macOS, iPhone-Simulator-Build und eigenständiger Watch-Simulator-Build.
- Bestehender AVSpeechSynthesizer wird für drei/zwei/eins wiederverwendet; kurze PCM-Töne kommen aus AVAudioPlayer. Beide Modi teilen sich denselben Scheduler und dieselben Ton-/Einstellungsmodelle. Neue App-Einstellungen sind optional, sodass Archive ohne diese Felder lesbar bleiben.
- Noch auf iPhone testen: tatsächliche Lautstärke/Verständlichkeit, Lautsprecher und Bluetooth, Audio-Unterbrechungen, Master-Schalter und Tonumkehrung, Countdown in normaler Fahrt und beschleunigter Demo. Kein Hörtest oder visuelle Menü-Abnahme allein aus dem Build ableiten.

## Gemeinsame LEDs und benannte Einträge, 27. September 2026

- 57 Core-Tests unter Swift 6.3.3 / WSL erfolgreich, darunter acht neue Tests für LED-Grenzen, Regularity-Zuordnung, alte Archive ohne Namensfelder, dauerhafte Namen/IDs, Umbenennen ohne Messwertverlust, Standardnamen, Mehrfachauswahl und isoliertes Löschen. Alle bisherigen Rundstrecken-/GPS-Tests bestehen unverändert.
- Ein erster Testlauf deckte einen instabilen Testvergleich von JSON-Bytes auf (Reihenfolge von Objektschlüsseln). Der Test vergleicht jetzt die tatsächlichen Zeit-/Distanzwerte; es war kein Fehler der Messdaten.
- Projektstrukturprüfung erfolgreich (74 Objekte, 17 iPhone-/4 Watch-Quellen); Swift-Syntaxprüfung der geänderten App-Dateien erfolgreich.
- Der aktive Root-Workflow `.github/workflows/ios.yml` verwendet nun `RallyTrip/` als Arbeitsverzeichnis und prüft somit die aktuelle App. [CI-Lauf 36327997806](https://github.com/JuCoBe/RallyTrip/actions/runs/36327997806) für Commit `63caafa` erfolgreich: Strukturprüfung, alle 57 Core-Tests unter macOS, iPhone-Simulator-Build und eigenständiger Watch-Simulator-Build.
- Visuelle iPhone-/Simulator-Abnahme und reale GPS-Fahrt bleiben offen. Prüfen: LEDs in beiden Tabs vor/während WP und bei Pause/GPS-Verlust; Namen speichern/ändern/leeren, App neu starten, Einträge auswählen, Demo/Real wechseln, selektiv löschen; große Schrift und Vollbild.

## Lokale Prüfung und Dokumentationsabgleich, 27. September 2026

- Aktive App `RallyTrip/`, Funktionsstand `7da94bd`: 49 Core-Tests auf macOS bestanden.
- Apple-SDK-Build für iPhone 17 Pro / iOS 26.5 Simulator erfolgreich; App gestartet, Watch-Begleitapp mitgebaut.
- Die zuvor als offen geführte Apple-SDK-Simulator-Kompilierung ist damit bestätigt. Visuelle Abnahme und reale Fahrprüfung bleiben offen.
- Root-README, GitHub-Pages-Seite und `kontext.md` dokumentieren die aktive Unterordnerstruktur. Website-Download zeigt auf das aktuelle main-Archiv statt auf die historische ZIP.

## Vollbild und Rundstrecken-Speicherung, 27. September 2026

- `swift test` mit Swift 6.3.3 unter WSL: **49 Tests erfolgreich, 0 Fehler**.
- Neuer Regressionstest: unverändertes Start/Ziel erhält Referenz und Vergleichsprofil; JSON-Rundlauf erhält Koordinate, Zeit und Profil; nach Wiederherstellung entstehen erneut Live-Abweichungen; Rundenreset erhält die Zielkoordinate.
- Swift-Syntaxprüfung der geänderten App-Dateien erfolgreich. Dies ersetzt keinen SwiftUI-Typcheck mit Apple-SDK.
- `node RallyTrip/scripts/verify-project.mjs` vom Repository-Hauptordner: erfolgreich, 74 Projektobjekte, 17 iPhone- und 4 Watch-Quelldateien. Die Prüfung akzeptiert nun auch von Xcode ergänzte Kommentare und Formatierung.
- Die aktuelle App liegt seit dem importierten Commit `76798e1` im Unterordner `RallyTrip/`; das zugehörige Xcode-Projekt ist `RallyTrip/RallyTrip.xcodeproj`. Das ältere Projekt im Repository-Hauptordner gehört nicht zu diesem geprüften Stand.
- Noch offen: Apple-SDK-Build und visuelle Prüfung auf iPhone/Simulator für Hoch-/Querformat, große Schrift, Vollbild-Ein-/Ausstieg und LED-Kontrast. Keine Veröffentlichung oder Geräteinstallation im Rahmen dieser Änderung.

## GPS-Rundstrecke und Rundstrecken-Demo, 26. September 2026

- 48 Core-Tests erfolgreich. Neue Prüfungen: gerichtete/interpolierte Startlinienüberfahrt, Rückwärtsfahrt und Stillstand, GPS-Lücken, ungenaue Punkte, Wiederherstellung ohne laufende Uhr sowie schnellerer/langsamerer Vergleich und beschleunigte Demo an der simulierten Streckenposition.
- GPS-Livevergleich verwendet gleiche gemessene Rundendistanz. LED-Grenze ±0,5 s ist eine Darstellungsgrenze, keine zugesicherte GPS-Genauigkeit.
- Noch offen: echte Rundstreckenfahrt mit Startlinie, GPS-Ausfällen, Hintergrundbetrieb und abweichenden Fahrlinien.

## Ergänzungen vom 26. September 2026: Demo und Rundstrecke

- Einstellbare Demo-Geschwindigkeit (0–200 km/h), Regularity-Fokus und manueller Rundstrecken-Gleichmäßigkeitsmodus implementiert.
- `swift test` auf dem Mac: 43 Tests bestanden, 0 Fehler. Drei neue Rundstreckentests prüfen Referenz/Abweichung, Doppeltipp-Schutz, ungültige Zeitstempel, Stop/Weiterstart, Speicherung und Reset.
- Signierter iPhone-Gerätebuild mit `xcodebuild`, Scheme RallyTrip, Debug, generic/platform=iOS: erfolgreich.
- Noch offen: visuelle Abnahme auf dem iPhone, reale Start-/Zielbedienung, Verhalten bei Gerätesperre und großen Bedienungshilfen-Schriftgrößen.

# Prüfstand vom 25. September 2026

## Apple-Watch-Erweiterung

- Crown-Nachtrag: Streckenkorrektur mit Fokus und haptischen 1-Meter-Schritten im Bereich −100 bis +100 Meter, Vorschau und explizitem Übernehmen. Protokolltests prüfen zusätzlich Zwischenwerte wie −37/+43 Meter und lehnen Bruchteile sowie Werte außerhalb der Grenzen ab. Die tatsächliche Crown-Bedienung und Fokusübergabe müssen noch am Gerät geprüft werden.

- **40 XCTest-Fälle bestanden, 0 Fehler**, einschließlich 10 neuer Watch-Protokolltests unter Swift 6.3.3 / WSL.
- Geprüft: Serialisierung, gültige Startzustände, Kalibrier-/Pausensperren, erlaubte Korrekturen, Befehlsalter, Fahrtwechsel, veraltete Anzeigen, Protokollversionen und doppelte Befehlszustellung.
- Swift-Syntaxprüfung über iPhone, Watch, Rechenkern und Tests bestanden. Dies ersetzt keine SwiftUI-/WatchConnectivity-Typprüfung gegen das Apple-SDK.
- Projektstruktur: 17 iPhone-Quelldateien, 4 Watch-Quelldateien (einschließlich gemeinsamem Protokoll), beide Schemes, Begleitapp-Kennung, Target-Abhängigkeit, Einbettung und Icons geprüft.
- Projektgenerator zweimal ausgeführt: identische Projektdatei. Watch-Plist und beide Schemes als XML geprüft.
- Ein parallel veröffentlichter Zwischenstand (`3851f8c`) hat [CI-Lauf 36189439456](https://github.com/JuCoBe/RallyTrip/actions/runs/36189439456) ausgelöst. Die bisherigen Core-Tests bestanden; der iPhone-Build scheiterte an einem fehlenden Initialwert für `@ScaledMetric` in `Components.swift`. Der Initialwert ist im lokalen Abschlussstand korrigiert. Der getrennte Watch-Build-Schritt wurde nach dem Fehler übersprungen.
- **Noch nicht bestätigt:** erfolgreicher vollständiger Apple-SDK-Build des Abschlussstands, Installation, visuelle Watch-Abnahme und echte WatchConnectivity-Kommunikation. Geräteszenarien stehen in [WATCH.md](WATCH.md).

## HIG- und Bedienungsupdate

Für das HIG- und Bedienungsupdate tatsächlich ausgeführt:

- `wsl -d Ubuntu -- bash scripts/test-core-wsl.sh`: **30 XCTest-Fälle bestanden, 0 Fehler**, Swift 6.3.3.
- Drei neue Regressionstests: Reset rückgängig während weiterer Streckenmessung und nach Total-Korrektur; Doppeltippen auf Reset und neue Fahrt; ausschließlich den letzten Reset wiederherstellen.
- `swiftc -frontend -parse` über alle Swift-Dateien in App, Rechenkern und Tests: bestanden. Prüft Syntax, nicht SwiftUI-/CoreLocation-Typen gegen das Apple-SDK.
- `node scripts/verify-project.mjs`: Projektverweise, 17 eingebundene iPhone-/Core-Swift-Quelldateien, Ressourcen und 30 vorhandene Tests geprüft.
- `git diff --check`: keine Whitespace-Fehler.

**Für diesen Änderungsstand nicht ausgeführt:** Xcode-Build, Simulator-Screenshots, VoiceOver-Prüfung und reale GPS-Fahrt. Der historische erfolgreiche CI-Build unten bezieht sich auf einen früheren Stand.

## Prüfung vor dem GitHub-Push

Am 25. September erneut ausgeführt: Core-Tests unter WSL (30 Tests erfolgreich) und Projektstrukturprüfung erfolgreich. Das Projekt wurde einschließlich Watch-Target neu erzeugt. Die neuen Watch-Dateien und der Android-Entwicklungsstand sind noch nicht durch einen Plattform-Build bestätigt.

## Manuelle Abnahme für diesen Stand

1. Kleine und große iPhones, Hoch-/Querformat, System/Hell/Dunkel/Nacht; große Bedienungshilfen-Schriftgrößen. Alle Inhalte müssen scrollbar bleiben; Zahlen, Einheiten und Aktionsbeschriftungen dürfen nicht abgeschnitten sein.
2. Zwischen allen vier Tabs während einer Fahrt wechseln; Messung läuft weiter, Navigation und Eingabezustände bleiben erhalten. Kalibrierung und Einstellungen in der Übersicht öffnen.
3. Fokusmodus ein-/ausschalten; danach App neu öffnen und gespeicherte Auswahl prüfen. Total, Trip, Geschwindigkeit und Fahrtsteuerung müssen erreichbar bleiben.
4. Trip zurücksetzen, weiterfahren, rückgängig machen: Trip enthält beide Strecken; Total und Rohstrecke bleiben unverändert. Nach einem neuen Reset kann nur dieser letzte Reset aufgehoben werden.
5. Temporären Core-Location-Fehler auslösen und danach gültige Punkte liefern: Messung erholt sich ohne erneute Freigabe; kein Streckensprung über die unterbrochene Verbindung. Entzug der genauen Standortfreigabe stoppt weiterhin die Messung.
6. GPS-Verlust, Messpause und Speichern: keine alte Geschwindigkeit, keine falsche „Im Takt“-Anzeige und keine GPS-Verlustmeldung nach abgeschlossener Fahrt. Prüfungszeit läuft bei Messpause weiter.
7. Gespeicherte Fahrt löschen: Abbrechen erhält die Fahrt; Bestätigen löscht nur die gewählten IDs einschließlich ihrer Strecken.
8. VoiceOver: Tabs, Reset, Rückgängig, Korrekturen, Fokus und GPS-Status sinnvoll beschriftet; Information nicht nur durch Farbe vermittelt.

## Historischer Prüfstand vom 8. September 2026

## Tatsächlich ausgeführt

- Swift 6.3.3, offizielles Ubuntu-24.04-Toolchain-Paket, unter Ubuntu 26.04 in WSL2.
- `swift test --scratch-path ~/.cache/rallytrip-build`: **27 XCTest-Fälle bestanden, 0 Fehler**.
- Davon 11 neue Tests für gewichtete Kalibrierreihen, Ausschluss von Messungen, Rückrechnung angezeigter Strecken, Faktorgrenzen, Demo-Trennung, Faktor-Spannweite, Live-Messungen, Pausen/GPS-Lücken, alte Profile und Historien-Serialisierung.
- `swiftc -frontend -parse` für die Swift-Quelldateien: Syntaxprüfung bestanden. Das ist keine Prüfung gegen das iOS-SDK.
- `node scripts/verify-project.mjs`: Projektverweise, Einbindung der 15 Swift-Quelldateien, Ressourcen und App-Icon geprüft.

Den Rechenkern auf diesem Rechner erneut prüfen:

```powershell
wsl -d Ubuntu -- bash scripts/test-core-wsl.sh
```

Swiftly liegt im Benutzerverzeichnis von Ubuntu. Die für das Ubuntu-24.04-Toolchain-Paket erforderlichen Bibliotheken `libxml2.so.2` und ICU 74 wurden aus Paketen des offiziellen Ubuntu-Archivs ausschließlich nach `~/.cache/rallytrip-swift-compat` extrahiert. Die Systembibliotheken wurden dadurch nicht ersetzt. Die benötigten C/C++-Entwicklungspakete wurden über Ubuntu installiert.

## Noch offen

- Vollständiger Simulator-Build mit Xcode und Apple-SDK einschließlich SwiftUI-Typprüfung: inzwischen bestanden, ebenso alle 27 Tests auf dem GitHub-Mac. Lauf: https://github.com/JuCoBe/RallyTrip/actions/runs/34208375144
- Bedienung und Layout im iPhone-Simulator bzw. auf einem iPhone.
- Reale Kalibrierfahrt mit GPS, Hintergrundbetrieb und Empfangsausfällen.
- GitHub-Projekt und Projektseite sind veröffentlicht. TestFlight-Bereitstellung bleibt offen; Apple-Developer-Zugang und Signierung fehlen.
