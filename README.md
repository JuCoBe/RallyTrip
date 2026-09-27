# RallyTrip

Native SwiftUI-App für iPhone ab iOS 17: GPS-Tripmaster, Gleichmäßigkeitsprüfungen und automatische Rundstrecken-Zeitnahme. Deutsche Oberfläche, lokale Speicherung, kein Backend und kein App-Account.

**Stand: 27. September 2026 · Gemeinsame LEDs und benannte Referenzen/Startpunkte.**

[Projektseite](https://jucobe.github.io/RallyTrip/) · [Aktuellen Quellcode herunterladen](https://github.com/JuCoBe/RallyTrip/archive/refs/heads/main.zip) · [KI-Kontext](kontext.md) · [Ausführliche Anleitung](RallyTrip/README.md) · [Prüfstand](RallyTrip/VALIDATION.md)

## Das richtige Projekt öffnen

Die aktuelle App liegt im Unterordner **`RallyTrip/`**. Öffne **`RallyTrip/RallyTrip.xcodeproj`** vom Repository-Hauptordner aus. Das gleichnamige Xcode-Projekt und die Quellen direkt im Hauptordner sind ein älterer Stand und werden derzeit nicht für die aktive App verwendet. Eine Bereinigung dieser Doppelstruktur steht noch aus.

```sh
git clone https://github.com/JuCoBe/RallyTrip.git
cd RallyTrip
open RallyTrip/RallyTrip.xcodeproj
```

In Xcode das Scheme **RallyTrip**, einen iPhone-Simulator und **Run (⌘R)** auswählen. Für ein echtes iPhone beide Targets (RallyTrip und RallyWatch) mit dem eigenen Team signieren und den Entwicklermodus auf dem Gerät aktivieren. Persönliche Signierungseinstellungen gehören nicht in allgemeine Änderungen.

## Funktionen

- **Tripmaster:** unabhängige Total-/Trip-Zähler, GPS-Geschwindigkeit, Kalibrierung, Korrekturen, Trip-Reset mit Rückgängig und Fokusansicht.
- **Regularity:** Schnittplan mit mehreren Geschwindigkeiten, geplanter Start, Zeitabweichung mit derselben LED-Komponente wie in der Rundstrecke, akustische Hinweise und Vollbild mit erreichbarem Ausstieg.
- **Rundstrecke:** Start-/Zielkoordinate und Fahrtrichtung festlegen; gerichtete GPS-Überfahrten starten und beenden Runden automatisch. Die erste vollständige Runde setzt die Referenz.
- **LED-Vergleich:** Blau = voraus, Orange = zurück, Grün = innerhalb ±0,5 s. Vergleich nach gleicher gemessener Rundendistanz; kein Vergleich identischer Kartenpositionen. Lampentest im Stillstand.
- **Speicherung:** Startpunkte und Referenzrunden mit optionalen Namen, Auswahl und nachträglichem Umbenennen. Alte Daten ohne Namen bleiben nutzbar. Zielkoordinate, Referenzzeit, Distanz-/Zeitprofil und abgeschlossene Runden bleiben erhalten; ein geänderter Startpunkt setzt nur die aktuellen Runden zurück, gespeicherte Referenzen bleiben auswählbar.
- **Route:** Karte, manuelle Roadbook-Punkte, Fahrtarchiv und GPX-Export.
- **Apple Watch:** Begleit-App für Anzeige und Fernsteuerung; reale Kommunikation und Bedienung müssen noch geprüft werden. Android liegt als Entwicklungsstand bei.

## Ohne Fahrt ausprobieren

**Tripmaster/Regularity:** Unter Einstellungen den Demo-Modus aktivieren. Geschwindigkeit zwischen 0 und 200 km/h einstellen und eine Fahrt oder WP starten.

**Rundstrecke:** Im Tab Rundstrecke die eigene Rundstrecken-Demo aktivieren. Mit 48 km/h und 5× Zeitraffer starten, bis die Referenzrunde abgeschlossen ist. Danach 44 oder 52 km/h einstellen, um Rückstand oder Vorsprung zu sehen. Die simulierte Kreisstrecke ist etwa 628 m lang. Zeitraffer beschleunigt Bewegung und Uhr gemeinsam; Demo- und echte Rundstreckendaten bleiben getrennt.

## Prüfstatus und Grenzen

- Aktuelle Erweiterung: **57 Core-Tests unter WSL erfolgreich**; Apple-SDK-Buildstatus im [Prüfstand](RallyTrip/VALIDATION.md).
- iPhone-Simulator-Build von `7da94bd` erfolgreich; App im iPhone-17-Pro-Simulator gestartet.
- Vorherige GPS-/Demo-Version erfolgreich signiert, auf einem iPhone 13 Pro installiert und gestartet. Die neuesten Vollbild-/Speicheränderungen sind damit noch nicht auf dem echten Gerät abgenommen.
- Offen: visuelle Prüfung, reale Rundstrecken-/GPS-Fahrt, Hintergrundverhalten, Watch-Gerätetest und TestFlight-Bereitstellung.

GPS-Rundenerkennung: 50 m breite Linie quer zur Fahrtrichtung, vor erneutem Auslösen mindestens 75 m Entfernung und 10 Sekunden Abstand. GPS-Lücken machen die laufende Runde ungültig. Die Anzeige ist eine Hilfe, keine offizielle RCN-Zeitnahme; ±0,5 s ist eine Anzeigegrenze, keine zugesicherte GPS-Genauigkeit.

```sh
cd RallyTrip
swift test
xcodebuild -project RallyTrip.xcodeproj -scheme RallyTrip \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Website und KI-Übergabe

GitHub Pages veröffentlicht **`docs/` im Repository-Hauptordner** über `.github/workflows/pages.yml`. Die Projektseite ist eine Informationsseite; die native App läuft nicht im Browser. Der Download verlinkt den aktuellen Branch `main`.

KI-Agenten lesen zuerst **[kontext.md](kontext.md)**. Nach Änderungen Funktionsstand, Prüfbelege und offene Punkte dort und im aktuellen Prüfstand nachführen.
