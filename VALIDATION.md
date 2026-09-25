# Prüfstand vom 25. September 2026

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
