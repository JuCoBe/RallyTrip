# Kontext für KI-Agenten – RallyTrip

Stand: 27. September 2026. Aktuelle Erweiterung: einstellbare Abweichungstöne und Referenz-Zielcountdown in `8f98571`, auf Basis der gemeinsamen LEDs und benannten Einträge aus `63caafa`. Dieses Dokument ist eine Übergabe, kein Ersatz für Codeprüfung oder aktuelle Git-/Test-Ergebnisse.

## Zuerst die richtige Arbeitskopie bestimmen

- Repository: https://github.com/JuCoBe/RallyTrip, Branch `main`.
- **Aktuelle App relativ zum Repository:** `RallyTrip/RallyTrip.xcodeproj`.
- Swift-App: `RallyTrip/RallyTrip/`; Core: `RallyTrip/Sources/RallyCore/`; Tests: `RallyTrip/Tests/RallyCoreTests/`; Watch: `RallyTrip/RallyWatch/`.
- Aktuelle Anleitung/Prüfhistorie: `RallyTrip/README.md` und `RallyTrip/VALIDATION.md`.
- **Website:** `docs/` im Repository-Hauptordner. Pages-Workflow: `.github/workflows/pages.yml`.
- Seit `76798e1` existiert eine verschachtelte Kopie. Das Xcode-Projekt, Package und Quellen im Hauptordner sind älter. Nicht versehentlich dort App-Funktionen bearbeiten. Der Root-iOS-Workflow baut jetzt die aktive App in `RallyTrip/`. Andere Root-Workflows und Paketskripte vor Verwendung auf ihre Arbeitsverzeichnisse prüfen.
- Auf dem eingerichteten Mac liegt die einzige aktive Git-Kopie unter `~/Developer/RallyTrip`; `~/Documents/GitHub/RallyTrip` ist eine Verknüpfung. Weitere Verzeichnisse namens RallyTrip sind Quellordner, keine zusätzlichen Git-Kopien.

## Produktstand

SwiftUI ab iOS 17, Core Location, MapKit; lokale Daten, keine externen Swift-Pakete und kein Backend. Fünf Tabs: Übersicht, Tripmaster, Regularity, Rundstrecke, Route.

Tripmaster: Total/Trip, Korrektur, gewichtete Kalibrierung, Fokus und Reset-Rückgängig. Regularity: segmentierte Sollgeschwindigkeit, monotone Prüfungsuhr, geplanter Start, Abweichung, Vollbild. Demo-Geschwindigkeit 0–200 km/h; während der Fahrt änderbar.

Rundstrecke: GPS-Punkt plus Fahrtrichtung definieren eine 50-m-Startlinie. Überfahrt nur in korrekter Richtung, erneutes Scharfschalten nach 75 m Entfernung, mindestens 10 s zwischen Überfahrten. Überfahrtszeit interpoliert zwischen GPS-Punkten. Erste vollständige Runde setzt Referenz; weitere vergleichen sich damit. GPS-Lücken/ungültige Messungen verwerfen die laufende Runde und blenden LEDs aus. Referenzvergleich erfolgt bei gleicher gemessener Distanz, nicht identischer GPS-Position.

LEDs: eine gemeinsame `PaceLEDs`-Komponente in Components.swift für Regularity und Circuit, gemeinsame Schwellen in `PaceLED`. Regularity nutzt Istzeit minus Schnittplan-Sollzeit an gleicher Distanz; ungültige Daten ergeben nil. Blau voraus, Orange zurück, Grün ±0,5 s. Mehrere Lampen bei größerer Abweichung, dunkler Hintergrund und Lampentest im Stillstand. Vollbild in Regularity/Rundstrecke blendet Navigation, Tabs und Statusleiste aus; Ausstieg bleibt erreichbar.

Koordinate, Referenzzeit, Profil und abgeschlossene Runden werden gespeichert. Identisches Speichern des Ziels erhält die Referenz; geändertes Ziel setzt die aktiven Runden zurück, gespeicherte Referenzen bleiben auswählbar. Unvollständige Runde wird bei App-Neustart verworfen. Rundstrecken-Demo: 628-m-Kreis, gleiche Erkennungslogik, 1×/2×/5×, eigene Speicherung und unabhängige GPS-Quelle. Bei 0 km/h läuft die Uhr weiter.

Namen und Auswahl: `NamedCircuitItem<Value>` verwendet UUID, Nummer und optionalen Namen im bestehenden `CircuitGPSArchive`. Alte aktive Daten werden zu Startpunkt 1 / Referenzrunde 1 migriert. Referenzpayload enthält bestehende CircuitGate/CircuitLap/Trace-Modelle. Umbenennen ändert nur Metadaten. „Neue Referenz aufzeichnen“ erhält gespeicherte Referenzen; Reset/Löschen entfernt nur die betroffene Referenz. Namenseingabe, Auswahl und Rename-Dialog sind gemeinsame UI-Komponenten; `changeCircuit` speichert Änderungen mit Rücknahme bei Speicherfehlern. Demo/Real bleiben getrennt.

Akustik: `RallyAudioFeedback` nutzt dieselbe Sekundenabweichung wie LEDs, Stille bei ±0,5 s, 1,5–0,2 s Tonabstand je nach Abweichung. `RallyTone` erzeugt 90-ms-PCM-Töne (hoch 1.000 Hz, tief 400 Hz). `RallyAudioPreferences` und optionale AppSettings-Felder speichern umkehrbare Zuordnung plus eigene Schalter für Piepen/Countdown. Menü: Einstellungen → Signale → Akustisches Feedback. Referenz-Countdown drei/zwei/eins bei Rundenstart + Referenzzeit, nur gültige Circuit-Runde, keine nachgeholten Zahlen. Bestehender Synthesizer, gemeinsamer Audio-Scheduler, Circuit-Vorrang bei paralleler Messung. Hardware-/Bluetooth-Hörtest offen; Vordergrundtimer ist keine Garantie im suspendierten Zustand.

## Wichtige Implementierungsstellen

- `RallyTrip/Sources/RallyCore/RegularityEngine.swift`: RegularityEngine, CircuitTimer, CircuitGate, GPSCircuitEngine, Archive und Referenzprofil.
- `RallyTrip/Sources/RallyCore/DistanceEngine.swift`: GPS-Qualitäts-/Sprungfilter, Streckenzähler.
- `RallyTrip/RallyTrip/Services/RallySession.swift`: Zustand, Uhren, getrennte Circuit-GPS-Quelle, Demo, Speicherung.
- `RallyTrip/RallyTrip/Views/RegularityView.swift`: Regularity, Rundstrecke und Zieleingabe.
- `RallyTrip/RallyTrip/Views/Components.swift`: gemeinsame LED-/Namens-/Auswahl-/Vollbild-Bausteine.
- `RallyTrip/RallyTrip/Views/HomeView.swift`: Navigation.
- `RallyTrip/RallyTrip/Views/SettingsView.swift`: Einstellungen und Demo-Geschwindigkeit.

## Verifiziert / noch offen

- Akustik-Erweiterung `8f98571`: 63 Core-Tests unter WSL und macOS erfolgreich; Syntax-/Projektstrukturprüfung sowie iPhone- und Watch-Simulator-Build erfolgreich. Beleg: https://github.com/JuCoBe/RallyTrip/actions/runs/36330802246. Hörtest am iPhone/Bluetooth bleibt offen.

- Aktuelle Erweiterung `63caafa`: 57 Core-Tests unter WSL und macOS erfolgreich; Syntax-/Projektstrukturprüfung, iPhone- und Watch-Simulator-Build erfolgreich. Beleg: https://github.com/JuCoBe/RallyTrip/actions/runs/36327997806. Keine neue visuelle oder reale GPS-Abnahme.

- 27.09.: `swift test` in der aktiven App auf dem Mac: 49 Tests bestanden.
- 27.09.: Apple-SDK-Simulator-Build von `7da94bd` erfolgreich und auf iPhone-17-Pro-Simulator gestartet; eingebettetes Watch-Target mitgebaut.
- 26.09.: vorheriger GPS-/Demo-Stand signiert und auf iPhone 13 Pro installiert/gestartet. Dies bestätigt keine Fahrmessung und keine Geräteabnahme der späteren Vollbildänderungen.
- Offen: reale Rundstrecke, GPS-Ausfälle und Empfangsqualität, abweichende Fahrlinien, Hintergrund/Display-Sperre, visuelle Abnahme inkl. großer Schrift/Querformat, WatchConnectivity auf Geräten, Android-Build, TestFlight.
- Simulator-Steuerung war in dieser Sitzung nicht freigegeben. Keine visuelle Prüfung behaupten, nur weil ein Build/Launch erfolgreich war.

## Befehle vom Repository-Hauptordner

```sh
cd RallyTrip
swift test
xcodebuild -project RallyTrip.xcodeproj -scheme RallyTrip -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
# Projektstruktur (falls Node verfügbar):
node scripts/verify-project.mjs
```

## Arbeitsregeln und nächste sinnvolle Schritte

1. Vor Änderungen `git status`, Branch, Remote und aktuelle Anweisungen prüfen. Signierung und andere lokale Änderungen erhalten.
2. Historische doppelte Verzeichnisstruktur bewusst bereinigen und CI/Paketskripte dabei auf die aktive App umstellen; nicht blind einen Ordner löschen.
3. Veraltete ZIP-Dateien nicht als aktuelle App ausgeben. Die Website verlinkt jetzt das GitHub-main-Archiv.
4. GPS-Grenzen und Demo/Real-Trennung erhalten. Anzeigeauflösung und LED-Toleranz sind keine Messgenauigkeitszusage; keine offizielle RCN-Wertung implementiert.
5. Nach Änderungen passende Tests/Builds ausführen und dieses Dokument samt VALIDATION aktualisieren. Ein Push ist erst nach Remote-Verifikation bestätigt.

## Lokale Umgebung und Veröffentlichung

Der Mac besitzt einen LaunchAgent `de.julius.rallytrip.update`, der beim Anmelden fetch + fast-forward ausführt und bei lokalen Änderungen oder lokalen Commits stoppt. Skript: `~/Library/Application Support/RallyTrip/update-at-login.py`; Log: `~/Library/Logs/RallyTrip/update.log`. Das ist eine lokale Einrichtung und wird nicht aus diesem Repository installiert.

Git-HTTPS-Push scheiterte zuletzt an fehlender Terminal-Anmeldung; öffentliche fetch/pull funktionieren. Der Benutzer hat zwischenzeitlich über einen anderen Zugang gepusht. Keine Tokens auslesen, keine lokalen Schlüssel veröffentlichen, keine erfolgreichen Uploads ohne Bestätigung behaupten. Website-Veröffentlichung läuft nach einem Push mit Änderungen in `docs/` über GitHub Actions; Deployment separat prüfen.
