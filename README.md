# RallyTrip für iPhone

RallyTrip wurde mit künstlicher Intelligenz (OpenAI Codex) nach den Vorgaben und im Austausch mit dem Projektinhaber programmiert.

Native SwiftUI-App für GPS-Tripmaster und Gleichmäßigkeitsprüfungen, ab iOS 17. Große Instrumente, deutsche Bedienoberfläche und eine dunkle Gestaltung mit limettengrünen Akzenten. Die App benötigt keine Drittanbieter-Pakete, kein Backend und keinen Account.

## Projekt auf dem Mac starten

### Simulator von Windows aus öffnen

Auf dem bereits eingerichteten Windows-PC im Projektordner `Simulator-starten.cmd` doppelklicken oder in PowerShell ` .\Simulator-starten.cmd` ausführen. Der Befehl startet den GitHub-Workflow, wartet auf den Simulator und öffnet die App-Steuerung im Standardbrowser. Der Aufbau kann etwa 10–15 Minuten dauern; danach bleibt die Testsitzung maximal 30 Minuten verfügbar. Ein erneuter Start beendet eine noch laufende Sitzung.

Voraussetzung sind die GitHub-Anmeldung für dieses Repository und der separat lokal hinterlegte Simulator-Zugangsschlüssel, passend zum GitHub Secret `SIMULATOR_ACCESS_TOKEN`. Der Schlüssel ist nicht im Repository enthalten; der Download allein richtet keinen Zugang auf einem anderen PC ein. ` .\Simulator-starten.cmd -CheckOnly` prüft die vorhandene Einrichtung ohne einen Lauf zu starten.

### Lokal mit Xcode

1. Diesen gesamten Ordner auf einen Mac mit Xcode 15 oder neuer kopieren.
2. **RallyTrip.xcodeproj** in Xcode öffnen. Nicht nur die `Package.swift` öffnen: diese enthält ausschließlich den plattformunabhängigen Rechenkern.
3. Das Scheme **RallyTrip** und einen iPhone-Simulator auswählen, dann **⌘R**.
4. In der App unter **Einstellungen → Demo-Modus** die Simulation einschalten. Im **Tripmaster → Fahrt starten** oder unter **Regularity → WP starten** loslegen.
5. Für ein echtes iPhone unter **Signing & Capabilities** dein Team auswählen und gegebenenfalls die Bundle-ID `de.rallytrip.app` durch eine eindeutige ID ersetzen. iPhone als Ziel auswählen und mit **⌘R** installieren.
6. Auf dem iPhone Standortzugriff erlauben und **Genauer Standort** aktivieren.

Ein signiertes Installationspaket ist nicht enthalten. Dieses Projekt wurde auf Windows erstellt; dort stehen weder der Apple-SDK-Build noch der iOS-Simulator zur Verfügung. Der tatsächliche iOS-Build und die Geräteprüfung sind noch offen.

**Für TestFlight:** Seit dem 28. April 2026 verlangt Apple für Uploads Xcode 26 oder neuer mit dem iOS-26-SDK oder neuer. Xcode 26 benötigt mindestens macOS Sequoia 15.6. Die oben genannte Xcode-15-Untergrenze betrifft nur den lokalen Projektaufbau, nicht die heutige TestFlight-Veröffentlichung. Quellen: [Apple-Uploadvorgaben](https://developer.apple.com/news/upcoming-requirements/), [Xcode-Systemanforderungen](https://developer.apple.com/xcode/system-requirements).

## GitHub-Projektseite

`docs/` enthält eine eigenständige, responsive Projektseite mit Funktionsübersicht, Quellcode-Download und Startanleitung. Sie benötigt keine Web-Abhängigkeiten. Die Beispielanzeige ist ausdrücklich als Illustration gekennzeichnet; die native iPhone-App läuft nicht im Browser.

Lokal ansehen: `node scripts/preview-site.mjs`, anschließend `http://127.0.0.1:4173` öffnen.

Zum Veröffentlichen die Projektdateien in das gewünschte GitHub-Repository hochladen und dort unter **Settings → Pages → Build and deployment → Source** die Option **GitHub Actions** auswählen. Der Workflow `.github/workflows/pages.yml` veröffentlicht `docs/` bei Änderungen auf `main` oder `master`; er kann auch manuell gestartet werden. Der tatsächliche Seitenlink erscheint nach erfolgreichem Lauf in der GitHub-Pages-Umgebung des Repositorys.

Die Website verwendet relative Links und funktioniert deshalb auch unter einem Repository-Unterpfad. `pwsh -File scripts/package-project.ps1` erzeugt das aktuelle Downloadpaket und aktualisiert `docs/downloads/RallyTrip-iOS.zip`. Die ZIP enthält sich selbst nicht; nach dem Entpacken kann dieser Befehl den Website-Download wiederherstellen. Eine GitHub-Veröffentlichung ist noch nicht erfolgt.

## Umgesetzter Funktionsumfang

| Bereich | Funktionen |
| --- | --- |
| Tripmaster | TOTAL, separater TRIP, GPS-Geschwindigkeit, Genauigkeit, Start, Messpause, Fortsetzen und Speichern |
| Korrektur | ±1 / ±10 / ±100 Meter; TOTAL mit einer Roadbook-Distanz synchronisieren |
| Regularity | Sofortstart, geplanter Start mit Countdown und Sekundenwahl, mehrere Schnittwechsel, abschnittsweise Sollzeit, Live-Zeitabweichung |
| Signale | Schnittwechsel bei 300 / 200 / 100 / 50 m und beim Wechsel ansagen; Haptik |
| GPS | Core Location, genaue Positionsanforderung, Qualitäts- und Sprungfilter, separate Geschwindigkeitsglättung, Hintergrundaufzeichnung |
| Kalibrierung | Live-Referenzstrecken, gewichtete Messreihen, Rückrechnung bereits kalibrierter Anzeigen, direkter Faktor, Fahrzeugprofile und Kalibrierhistorie |
| Route | MapKit-Karte, getrennte Streckenlinien bei Messlücken und Pausen, manuell angelegte Roadbook-Punkte |
| Fahrten | Lokales JSON-Archiv, Wiederherstellung des letzten Zwischenspeicherstands, GPX-Export und Löschen |
| Darstellung | Hell, Dunkel, Nacht; Bildschirm während der Fahrt wach halten |
| Demo | Simulierte Positionspunkte auf einer Kreisstrecke, explizite Kennzeichnung der Demo-Fahrten |

OBD, externe GNSS-Empfänger, Sensorfusion, Roadbook-Dateiimport und eine errechnete Aufholgeschwindigkeit sind nicht Teil dieser Version. Die `PositionSource`-Schnittstelle ist der Einstiegspunkt für spätere Messquellen. Das Roadbook ist eine manuelle Kilometer-/Hinweisliste, keine Abbiegenavigation.

## Verhalten bei einer Rallye

- **TOTAL** summiert die kalibrierte Strecke; **TRIP** läuft unabhängig vom letzten Trip-Reset. Ein TOTAL-Sync ändert TRIP und rohe GPS-Distanz nicht.
- Beim WP-Start wird die aktuelle TOTAL-Distanz als Prüfungsbeginn festgehalten. Spätere TOTAL-Korrekturen korrigieren auch die Prüfungsdistanz und damit die Sollzeit.
- **Positive Abweichung = zu spät**, negative Abweichung = zu früh. Der grüne Bereich umfasst ±0,5 Sekunden.
- Die Sollzeit wird über alle durchfahrenen Segmente summiert. 8 km mit konstant 48 km/h ergeben 600 Sekunden.
- Die laufende Prüfung verwendet `ContinuousClock`. Eine Änderung der Geräteuhr verändert die Prüfungsdauer nicht. Ein geplanter Wandzeit-Start wird beim Einplanen einmal in die monotone Zeitbasis übersetzt.
- **Pause stoppt die Streckenmessung und die Fahrtzeit, aber nicht die laufende Prüfungszeit.** Beim Fortsetzen wird die ungemessene Strecke nicht nachträglich addiert.
- Einen geplanten Start mit geöffneter App durchführen. iOS garantiert keinen sekundengenauen Timer-Aufruf im suspendierten Zustand. Der nächste GPS-Callback kann einen fälligen Start nachholen; die erste Distanzmessung beginnt dann erst mit neuen Messpunkten.
- Bei Genauigkeit über 20 m, einem mehr als 5 Sekunden alten Messpunkt oder unplausiblen Sprüngen wird der Punkt verworfen. Nach einer Messlücke über 5 Sekunden wird keine Verbindung zur alten Position addiert. Dadurch kann Strecke fehlen; nach GPS-Ausfällen anhand des Roadbooks synchronisieren.
- Bei fehlender oder reduzierter Standortfreigabe wird keine Strecke gemessen. Ohne verwertbare GPS-Geschwindigkeit sowie unter 0,8 m/s wird Positionsdrift nicht als Fahrtstrecke gezählt. Sehr langsames Rollen wird dadurch unterschätzt.
- Die GPS-Geschwindigkeit wird über einen Median der letzten fünf Werte und einen gleitenden Filter beruhigt. Die Streckenmessung verwendet direkt die gültigen Koordinaten.
- Kalibrierung verwendet die Rohstrecke **nach** Qualitätsfilter, **vor** Kalibrierfaktor und manuellen Korrekturen. Ein neuer Faktor gilt ab der nächsten Fahrt. Bei einer laufenden Fahrt sind Profile und Demo-Umschaltung gesperrt.
- Der Demo-Modus ist zum Ausprobieren im Vordergrund gedacht. Die Koordinaten simulieren eine Fahrt; er ersetzt keinen GPS-Gerätetest.
- Die Anzeige von Hundertstelsekunden ist eine Rechenauflösung. Sie ist kein Nachweis entsprechender GPS-Messgenauigkeit.

## Speicherung

### Erweiterte Kalibrierung

Unter **Kalibrierung** stehen drei Wege zur Verfügung:

1. **Referenzstrecke live messen:** Offizielle Länge eingeben, im Stand am Start die Messung beginnen und auf einen gültigen GPS-Punkt warten. Am Ziel erneut im Stand die Messung übernehmen. Die Rohstrecke hängt weder vom alten Faktor noch von TOTAL-Sync oder Trip-Reset ab. Weitere Durchfahrten können direkt ergänzt werden.
2. **Messwerte manuell hinzufügen:** Offizielle Strecke und gemessene Rohstrecke eingeben. Falls nur eine bereits kalibrierte Anzeige vorliegt, den entsprechenden Schalter aktivieren und den damals verwendeten Faktor eintragen. Dabei eine Streckendifferenz ohne manuelle Korrekturen verwenden. Beispiel: 4,950 km Anzeige bei Faktor 1,1 ergeben 4,500 km Rohstrecke; bei 5,000 km Referenz ist der neue Faktor 1,11111.
3. **Faktor direkt setzen:** Beim Fahrzeugprofil den Regler-Button öffnen oder ein neues Profil anlegen. Dort lassen sich Name und Faktor ändern, der Faktor auf 1 zurücksetzen und frühere Werte aus der Historie wiederherstellen. Erst **Speichern** übernimmt die Änderung.

Mehrere eingeschaltete Messungen werden mit **Summe Referenzstrecken / Summe Rohstrecken** kombiniert. Es wird kein einfacher Mittelwert der Einzelfaktoren gebildet. Lange Messstrecken erhalten dadurch mehr Gewicht. Fehlerhafte Messungen können per Schalter ausgeschlossen oder per Wischgeste gelöscht werden.

Die Auswertung zeigt den kombinierten Faktor, die gesamte Referenzstrecke, die Änderung zum aktiven Faktor und die Spannweite der Einzelfaktoren. Referenzen unter 1 km und eine relative Faktor-Spannweite über 1 % erzeugen Hinweise. Diese Schwellen dienen der Plausibilitätsprüfung, nicht als zugesicherte Messgenauigkeit.

Während einer laufenden Live-Kalibrierung sind WP-Starts gesperrt. Eine Pause, ein verworfener GPS-Punkt nach Messbeginn oder eine erkannte GPS-Lücke macht die Messung dauerhaft ungültig; sie muss verworfen und neu begonnen werden. Vor dem ersten gültigen Punkt wartet die Messung auf Empfang. Demo- und echte Messungen dürfen nicht gemeinsam ausgewertet werden.

Die laufende Messung und die Messreihe überstehen den Wechsel zwischen App-Ansichten. Noch nicht gespeicherte Messreihen sind Arbeitsspeicher und gehen beim Beenden der App verloren. Beim Speichern eines Profils werden die verwendeten Messungen mit Datum, vorherigem Faktor und neuem Faktor dauerhaft in dessen Historie übernommen. Bestehende Profile ohne Historie bleiben lesbar. Profile und Faktoren sind während einer Fahrt gesperrt; mindestens ein Profil bleibt erhalten.

Alle Daten liegen im Dokumentenordner der App und sind über **Dateien → Auf meinem iPhone → RallyTrip** erreichbar:

- `rallytrip.json`: Einstellungen, Kalibrierprofile, Schnittplan, Roadbook und beendete Fahrten.
- `active-ride.json`: während einer Fahrt etwa alle zehn Sekunden und bei einem App-Wechsel erzeugter Speicherstand.

Nach einem Abbruch wird der letzte Speicherstand als beendete, **wiederhergestellte** Fahrt archiviert. Eine unterbrochene Wertungsprüfung wird nicht stillschweigend fortgesetzt. Beim normalen Beenden wird zuerst atomar gespeichert und erst danach die Aufzeichnung beendet. Ist das Archiv nicht lesbar, wird die Originaldatei nicht überschrieben.

GPX exportiert die Koordinaten mit Zeitstempel und Höhe, mit getrennten Track-Segmenten für Messlücken. Kalibrierung und Kilometerkorrekturen verändern keine GPS-Koordinaten. Die Kartengrundlage wird durch MapKit geladen; eine Offline-Kartenverwaltung ist nicht enthalten.

## Tests und Build-Prüfung

Auf einem Mac im Projektordner:

```sh
swift test
xcodebuild -project RallyTrip.xcodeproj -scheme RallyTrip \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Die 27 XCTest-Fälle decken einzelne und mehrere Sollschnitte, Segmentgrenzen, ungültige Pläne, gewichtete Kalibrierreihen, Rückrechnung von Anzeigen, ungültige Faktoren, Demo-Trennung, unterbrochene Referenzmessungen, Profilmigration und Historie, Korrektur, Zeitbasis, GPS-Drift, alte und ungenaue Messpunkte, Sprünge, Messlücken, Geschwindigkeitsglättung und Fahrt-Serialisierung ab. Am 8. September 2026 wurden **alle 27 Tests mit Swift 6.3.3 unter Ubuntu/WSL2 erfolgreich ausgeführt**. Der vollständige iOS-Build und die Geräteprüfung bleiben offen. Details und Wiederholungsbefehl stehen in `VALIDATION.md`.

`.github/workflows/ios.yml` enthält einen macOS-Job für dieselben Tests und den Simulator-Build. Er läuft nach einem Push in ein GitHub-Repository mit aktivierten Actions. Es wurde kein Repository veröffentlicht und kein CI-Lauf ausgelöst.

Lokal ausgeführte Strukturprüfung:

```sh
node scripts/verify-project.mjs
```

Diese Prüfung kontrolliert die Projektverweise, Quelldateieinbindung, Ressourcen und das App-Icon; sie ist kein Swift-Compiler. Die XML-Dateien wurden zusätzlich mit dem XML-Parser geprüft.

## Noch auf einem iPhone prüfen

1. GPS-Freigabe erlaubt, verweigert und mit ausgeschaltetem genauen Standort.
2. Stehendes Fahrzeug: keine Distanzzunahme; bekannte Strecke: Kalibrierung und Korrekturen vergleichen.
3. Bildschirm sperren und App wechseln: Streckenaufzeichnung, Ansagen und Rückkehr prüfen.
4. Geplanter Start im Vordergrund, Schnittwechsel, Messpause während einer WP und TOTAL-Sync.
5. Beenden, Neustart, simulierten App-Abbruch und GPX-Export prüfen.
6. Kleine iPhone-Bildschirme, Querformat, große Systemschrift und alle drei Darstellungen prüfen.

## Struktur

```text
RallyTrip.xcodeproj/        Direkt in Xcode zu öffnendes iPhone-Projekt
RallyTrip/
  App/                     SwiftUI-Einstiegspunkt
  Views/                   Bedienoberfläche und GPX-Dateiexport
  Services/                Core Location und aktive Rallye-Sitzung
  Storage/                 Lokales Archiv und Einstellungen
  Assets.xcassets/          App-Icon
Sources/RallyCore/         Modelle, Distanz-, Zeit- und Regularity-Rechenkern
Tests/RallyCoreTests/      Plattformunabhängige XCTest-Fälle
scripts/                   Projektgenerator, Icon-Erzeugung, Strukturprüfung
```

Nach dem Hinzufügen einer Swift-Datei lässt sich das Xcode-Projekt ohne Fremdpakete mit `node scripts/generate-project.mjs` aktualisieren. Der Rechenkern wird direkt in das App-Target kompiliert und für Tests zusätzlich über Swift Package Manager bereitgestellt.

Bei der Umsetzung berücksichtigte Apple-Dokumentation: [Core Location](https://developer.apple.com/documentation/corelocation/cllocationmanager), [Standortfreigaben und Hintergrundbetrieb](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [MapPolyline](https://developer.apple.com/documentation/mapkit/mappolyline) und [automatische Audio-Session für Sprachausgabe](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer/usesapplicationaudiosession).
