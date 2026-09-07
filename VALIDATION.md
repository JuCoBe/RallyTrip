# Prüfstand vom 8. September 2026

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

- Vollständiger Build mit Xcode und Apple-SDK, einschließlich SwiftUI-Typprüfung.
- Bedienung und Layout im iPhone-Simulator bzw. auf einem iPhone.
- Reale Kalibrierfahrt mit GPS, Hintergrundbetrieb und Empfangsausfällen.
- GitHub-Veröffentlichung und TestFlight-Bereitstellung; dafür fehlen weiterhin die entsprechenden Anmeldungen.
