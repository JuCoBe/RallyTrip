# RallyTrip für iPhone

**Aktive App im Unterordner `RallyTrip/` · Stand 27. September 2026.** Einstieg und aktuelle Prüfzusammenfassung: [Repository-README](../README.md). Hinweise für KI-Agenten: [kontext.md](../kontext.md).

RallyTrip wurde mit künstlicher Intelligenz (OpenAI Codex) nach den Vorgaben und im Austausch mit dem Projektinhaber programmiert.

Native SwiftUI-App für GPS-Tripmaster und Gleichmäßigkeitsprüfungen, ab iOS 17. Große Instrumente, deutsche Bedienoberfläche, native Tab-Navigation und adaptive helle/dunkle Systemfarben mit grünen Akzenten. Die App benötigt keine Drittanbieter-Pakete, kein Backend und keinen Account.

## Design- und Bedienungsupdate vom 25. September 2026

- **Übersicht, Tripmaster, Regularity, Rundstrecke und Route** sind über native Tabs erreichbar. Kalibrierung und Einstellungen befinden sich in der Übersicht.
- **System** folgt der iPhone-Darstellung und ist der Standard für neue Installationen. Bestehende Einstellungen für Hell, Dunkel und Nacht bleiben erhalten.
- Die Instrumente skalieren mit Dynamic Type; wichtige zweispaltige Bereiche wechseln bei Bedienungshilfen-Schriftgrößen in eine Spalte. Schaltflächen verwenden native Zustände und große Berührungsflächen.
- **Fokus** im Tripmaster blendet Fahrzeugdetails, Durchschnitt und Korrekturen aus. Total, Trip, GPS-Geschwindigkeit, Roadbook-Hinweis und Fahrtsteuerung bleiben erreichbar. **Alle Details** stellt die vollständige Ansicht wieder her.
- **Letzten Reset rückgängig** stellt den vorherigen Trip inklusive der seit dem Reset gefahrenen Strecke wieder her. Total und Rohstrecke bleiben unverändert. Es gibt eine Rückgängig-Stufe; eine neue Fahrt beginnt ohne Reset-Historie.
- **Durchschnitt** berechnet sich aus kalibrierter GPS-Rohstrecke und Fahrtzeit ohne Messpausen. Manuelle Total-Korrekturen ändern ihn nicht; GPS-Lücken können den Wert unterschätzen.
- Ohne gültigen GPS-Empfang zeigt die Geschwindigkeit **—**. Während einer Prüfung ersetzt **GPS prüfen** bzw. **Streckenmessung pausiert** die Live-Abweichung. Die Prüfungsuhr läuft weiter.
- Vorübergehende GPS-Fehler setzen die Standortfreigabe nicht mehr fälschlich auf ungenau. Nach dem Speichern wird keine veraltete GPS-Verlustmeldung mehr erzeugt. Löschen gespeicherter Fahrten erfordert eine Bestätigung.

Recherche, Quellen und Produktentscheidungen: [MARKET-RESEARCH.md](MARKET-RESEARCH.md). Prüfungen und noch offene iPhone-Abnahme: [VALIDATION.md](VALIDATION.md).

## Demo-Geschwindigkeit und Regularity-Fokus

Im Demo-Modus lässt sich die simulierte Geschwindigkeit von 0 bis 200 km/h in 1-km/h-Schritten einstellen. Regler und Plus/Minus-Steuerung stehen in den Einstellungen sowie direkt in Tripmaster und Regularity zur Verfügung, auch während einer Demo-Fahrt. Der Wert bleibt gespeichert und wird nicht automatisch an den Sollschnitt angepasst; die Geschwindigkeitsanzeige verwendet weiterhin die GPS-Glättung.

Regularity und Rundstrecke bieten oben rechts **Vollbild** mit einem erreichbaren Ausstieg. Der Tripmaster behält seine Fokusansicht. Details stehen im folgenden Abschnitt.

## Akustisches Feedback

Unter **Einstellungen → Signale → Akustisches Feedback** lässt sich die Tonzuordnung wählen: standardmäßig **zu langsam = hoch (1.000 Hz)** und **zu schnell = tief (400 Hz)**, auf Wunsch umgekehrt. Abweichungspiepen und Rundstrecken-Countdown lassen sich dort einzeln ausschalten. Der bestehende Hauptschalter **Akustische Hinweise** schaltet alle Ansagen und Töne aus. Die Einstellungen bleiben nach einem Neustart erhalten; alte Einstellungen verwenden die Standardzuordnung.

Beide Modi verwenden dieselbe Zeitabweichung wie ihre LEDs. Innerhalb **±0,5 s** bleibt es ruhig. Außerhalb wird der Tonabstand mit zunehmender Abweichung kürzer: etwa **1,5 s bei 1 s Abweichung**, **0,5 s bei 3 s**, bis minimal **0,2 s ab 7,5 s**. Die Töne dauern 90 ms und werden lokal erzeugt.

Die Rundstrecke spricht **„drei, zwei, eins“** in den letzten drei Sekunden vor **Rundenstart + gespeicherter Referenzzeit**. Gemeint ist die geplante Zielzeit, nicht eine aus der aktuellen Geschwindigkeit geschätzte GPS-Überfahrt. Ohne Referenz oder bei einer ungültigen GPS-Runde gibt es keinen Countdown. Jede Zahl wird pro Runde höchstens einmal angesagt; nach Unterbrechungen werden verpasste Zahlen nicht nachgeholt. Die Demo beschleunigt den Countdown entsprechend ihrem Zeitraffer; die Abweichungspieptöne behalten ihre reale Tonfolge.

Countdown-Ansagen haben Vorrang vor Piepen und Schnittwechselansagen. Bei gleichzeitig laufenden Messungen kommen die Abweichungstöne aus der Rundstrecke. Bei Pause/fehlenden Messdaten verstummt die betroffene Abweichungsanzeige. Die Lautstärke folgt der Medienlautstärke des iPhones; Audio-Unterbrechungen werden beachtet. Für den sekundengenauen Countdown die App im Vordergrund geöffnet lassen: iOS garantiert keine regelmäßigen Timer-Aufrufe bei suspendierter App.

## Gemeinsame LEDs und benannte Startpunkte / Referenzen

Regularity und Rundstrecke verwenden dieselbe LED-Anzeige mit identischen Farben, Grenzen und Lampentest. Im Regularity-Tab ist die Referenz die aus dem Schnittplan errechnete Sollzeit an der aktuellen Prüfungsdistanz: **Istzeit minus Sollzeit**, in Sekunden. Positiv bedeutet zurück / zu spät, negativ voraus / zu früh. Vor dem Start, bei Messpause oder fehlendem GPS bleibt der Livevergleich aus.

- **Startpunkt benennen:** Im vorhandenen Start/Ziel-Formular optional einen Namen eintragen und wie bisher speichern. Ohne Eingabe erscheint „Startpunkt 1“, bei weiteren Punkten die jeweilige Nummer. Unterschiedliche Positionen/Richtungen werden als eigene Startpunkte erhalten.
- **Referenz benennen:** Nach Abschluss der Referenzrunde den optionalen Namen direkt über „Referenzrunde speichern“ eingeben. Ohne Eingabe erscheint „Referenzrunde 1“ usw.; automatische Speicherung bleibt aktiv.
- **Auswählen und umbenennen:** Die Menüs „Startpunkt“ und „Referenzrunde“ zeigen gespeicherte Namen. Im Bereich „Umbenennen“ lässt sich jeder Eintrag direkt ändern, ohne ihn zuerst auszuwählen oder Messwerte zurückzusetzen. Ein leeres Namensfeld stellt den Standardnamen wieder her.
- **Weitere Referenz:** „Neue Referenz aufzeichnen“ behält die bisherige gespeicherte Referenz und wartet auf die nächste Startlinienüberfahrt für eine neue Aufzeichnung. Die Wahl einer gespeicherten Referenz lädt ihre Zeit, ihr GPS-Profil und den passenden Startpunkt. Wechsel sind nur bei gestoppter Messung möglich; aktuelle Vergleichsrunden werden dabei zurückgesetzt.
- **Löschen:** „Aktuelle Referenz / Runden löschen“ betrifft nur die aktive Referenz und Vergleichsrunden. Andere gespeicherte Referenzen sowie die Startpunkte bleiben erhalten. Im Referenzmenü können auch inaktive Referenzen nach Bestätigung gelöscht werden.
- Alte Archive ohne Namen werden automatisch übernommen. Namen und feste Eintrags-IDs liegen im bestehenden Archiv, getrennt für Demo und reale Messung. Identische Namen sind erlaubt; Umbenennen verändert weder GPS-Daten noch Rundenzeiten.

## Vollbild, Zielkoordinate und Referenzrunde (27. September 2026)

- **Vollbild** in Regularity und Rundstrecke blendet Navigation, Tabs und Statusleiste aus. Ein dauerhaft erreichbarer Button beendet die Ansicht. Im Rundstrecken-Vollbild entfallen Demo-Einstellungen, Ergebnisliste und Speicher-/Löschaktionen; Rundenzeit, LEDs, GPS-Status und Messungssteuerung bleiben erreichbar.
- **Zielkoordinate speichern** speichert Start/Ziel mit Fahrtrichtung. Erneutes Speichern unveränderter Werte erhält die Referenz und Rundenliste. Eine geänderte Position oder Richtung setzt die aktiven Runden zurück; gespeicherte Referenzen bleiben auswählbar. Beim Öffnen des Editors bleiben alle gespeicherten Nachkommastellen erhalten.
- **Referenzrunde speichern** bietet eine ausdrückliche Speicheraktion mit Bestätigung. Die automatische Speicherung abgeschlossener Runden bleibt aktiv. Referenzzeit und GPS-Distanz-/Zeitprofil werden beim Neustart wiederverwendet; eine unvollständige Runde wird verworfen. Demo und reale Messungen bleiben getrennt.
- Die **LEDs** stehen auf dunklem Hintergrund und leuchten mit kräftigen Farben, Kontur und Leuchteffekt. Bei größerer Abweichung leuchten mehrere Lampen: Blau = voraus, Orange = zurück, Grün = im Bereich ±0,5 s. Ohne gültigen Vergleich sind die Lampen gedimmt und der fehlende Messwert wird erklärt. Im Stillstand lässt sich über **LED-Lampentest** die gesamte Reihe einschalten; beim Start der Messung endet der Test automatisch.

## Rundstrecke – GPS-Gleichmäßigkeit und Demo

Im Tab **Rundstrecke** zunächst **Start/Ziel festlegen**: aktuelle GPS-Position übernehmen oder Breiten-/Längengrad eingeben; die Fahrtrichtung in Grad festlegen (0 Nord, 90 Ost). Geänderte Zielkoordinaten oder Fahrtrichtung setzen die aktiven Runden zurück; gespeicherte Referenzen bleiben auswählbar, unverändertes Speichern erhält auch die aktuellen Runden. Die Startlinie ist 50 m breit und steht quer zur Fahrtrichtung. **GPS-Rundenerkennung starten** wartet auf eine Überfahrt in dieser Richtung. Zuvor mindestens 75 m vom Punkt entfernen; zwischen Überfahrten liegen mindestens 10 Sekunden. GPS-Punkte benötigen höchstens 20 m gemeldete Ungenauigkeit. Die Überfahrtszeit wird zwischen zwei GPS-Punkten interpoliert.

Die erste vollständige Runde setzt die Referenzzeit samt Distanz-/Zeitprofil. Jede weitere Überfahrt beendet die Runde und startet die nächste. Die LED-Anzeige vergleicht die Zeit bei gleicher gefahrener Rundendistanz: **blau = voraus / zu schnell**, **orange = zurück / zu langsam**, **grün = innerhalb ±0,5 s**. Das ist ein Vergleich nach GPS-Streckenlänge, kein Abgleich identischer Kartenpositionen und keine offizielle Zeitnahme. Abweichende Linien und GPS-Messfehler beeinflussen das Ergebnis.

Bei unbrauchbaren GPS-Daten oder Lücken über fünf Sekunden verschwindet der LED-Vergleich. Die betroffene Runde wird verworfen, die nächste gültige Start-/Zielüberfahrt beginnt eine neue Runde. Rückwärtsüberfahrten und Stillstand lösen keine Runde aus. Die Messung läuft unabhängig von Tripmaster-Pausen. Abgeschlossene Runden, Referenzprofil und Startlinie bleiben gespeichert; eine bei App-Beendigung laufende Runde wird verworfen.

**Rundstrecken-Demo** simuliert eine 628-m-Kreisstrecke durch dieselbe Erkennung. Sie verwendet kein echtes GPS und speichert ihre Ergebnisse getrennt. Moduswechsel sind nur bei gestoppter Messung möglich. Mit 48 km/h und **5×** starten: Nach der Anfahrt entsteht in etwa zehn realen Sekunden die Referenzrunde. Danach beispielsweise 44 oder 52 km/h einstellen, um Rückstand oder Vorsprung auf den LEDs zu sehen. Der Zeitraffer beschleunigt Bewegung und Uhr gemeinsam. Bei 0 km/h steht das Fahrzeug; die Uhr läuft weiter. Im Hintergrund kann die Demo unterbrochen werden; eine solche Runde wird verworfen.

## Weitere Plattformen – Entwicklungsstand

`RallyWatch/` enthält eine Apple-Watch-Begleit-App mit Anzeige und Fernbedienung der iPhone-Sitzung. Das Xcode-Projekt enthält das Watch-Target und bettet die Begleit-App ein. Die eingebettete Watch-App wurde beim erfolgreichen iPhone-Simulator-Build mitgebaut. Tests mit gekoppelten Geräten und eine eigenständige Watch-Abnahme stehen noch aus.

Unter `android/` entsteht eine Android-Version. Die Dateien sind ein Entwicklungsstand; ein lauffähiges, geprüftes Android-Paket wird damit noch nicht zugesichert.

## Projekt auf dem Mac starten

### Apple Watch

Die Begleitapp **RallyWatch** ab watchOS 10 bietet Fahrt-/WP-Start, Live-Zeitabweichung und Total-Korrekturen über die **Digital Crown**: −100 bis +100 Meter in 1-Meter-Schritten, mit Vorschau und Übernehmen. Das iPhone bleibt die Messquelle. Verbindung, bestätigte Aktionen und veraltete Werte werden ausdrücklich angezeigt. Einrichtung, Grenzen und Geräteprüfung: [WATCH.md](WATCH.md).

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

Ein signiertes Installationspaket ist nicht enthalten. Der aktuelle Apple-SDK-Simulator-Build wurde auf dem Mac erfolgreich ausgeführt. Eine vorherige GPS-/Demo-Version wurde auf dem iPhone 13 Pro installiert und gestartet; die reale Fahr- und Geräteabnahme des neuesten Stands bleibt offen.

**Für TestFlight:** Seit dem 28. April 2026 verlangt Apple für Uploads Xcode 26 oder neuer mit dem iOS-26-SDK oder neuer. Xcode 26 benötigt mindestens macOS Sequoia 15.6. Die oben genannte Xcode-15-Untergrenze betrifft nur den lokalen Projektaufbau, nicht die heutige TestFlight-Veröffentlichung. Quellen: [Apple-Uploadvorgaben](https://developer.apple.com/news/upcoming-requirements/), [Xcode-Systemanforderungen](https://developer.apple.com/xcode/system-requirements).

## GitHub-Projektseite

Die veröffentlichte Projektseite kommt aus **`docs/` im Repository-Hauptordner**, nicht aus dem Unterordner neben dieser README. Der Root-Workflow `.github/workflows/pages.yml` veröffentlicht Änderungen daran nach einem Push auf `main`/`master`.

[Projektseite](https://jucobe.github.io/RallyTrip/) · [aktuelles Quellcode-Archiv](https://github.com/JuCoBe/RallyTrip/archive/refs/heads/main.zip). Nach dem Entpacken die aktive App unter `RallyTrip/RallyTrip.xcodeproj` öffnen. Historische ZIP-Dateien im Repository werden nicht mehr als aktueller Download verlinkt.

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
| Darstellung | System, Hell, Dunkel, Nacht; Dynamic Type, Fokusmodus; Bildschirm während der Fahrt wach halten |
| Apple Watch | Begleitapp mit Fahrt-/WP-Start, Zeitabweichung, Total-Korrektur, Verbindungs- und Bestätigungsanzeige |
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
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Am 25. September 2026 wurden **30 XCTest-Fälle mit Swift 6.3.3 unter Ubuntu/WSL2 erfolgreich ausgeführt**. Sie prüfen Regularity, Kalibrierung, GPS-Filter, Streckenkorrekturen, Reset-Rücknahme und Speicherung. Der Apple-SDK-Build und die Geräteprüfung für den aktuellen Stand stehen noch aus. Details und Wiederholungsbefehl stehen in `VALIDATION.md`.

`.github/workflows/ios.yml` enthält einen macOS-Job für dieselben Tests und den Simulator-Build. Er läuft nach einem Push in ein GitHub-Repository mit aktivierten Actions. Das Repository ist veröffentlicht. Frühere erfolgreiche CI-Läufe sind in `VALIDATION.md` dokumentiert; sie bestätigen nicht automatisch den aktuellen Stand.

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
RallyWatch/                Apple-Watch-Begleitapp mit Anzeige und Fernsteuerung
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
