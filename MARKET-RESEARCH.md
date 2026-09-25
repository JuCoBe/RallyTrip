# Kurze Marktrecherche und Umsetzung

Stand: 25. September 2026. Qualitativer Vergleich öffentlich zugänglicher Herstellerseiten und Store-Beschreibungen. Keine Nutzerinterviews, keine repräsentative Nachfrageanalyse und kein praktischer Genauigkeitsvergleich. Herstellerangaben belegen beworbene Funktionen, nicht die tatsächliche Messleistung.

## Beobachtungen

| Angebot | Beobachtung | Bedeutung für RallyTrip |
| --- | --- | --- |
| [Rally Tripmeter](https://play.google.com/store/apps/details?id=ee.siimplangi.rallytripmeter) | Bewirbt zwei Trips, Durchschnittsgeschwindigkeit, Regularity, anpassbare Anzeigen und Bluetooth-Tasten. | Schneller Zugriff auf Fahrinstrumente und verständliche Fahrtwerte sind zentrale Vergleichsmerkmale. |
| [EZ Rally Tripmeter](https://ezrally.app/tripmeter/) | Stellt zwei Distanzen und Geschwindigkeit in den Mittelpunkt; beschreibt sichtbares Reset-Feedback und Nachtmodus. Die Website kündigt die App noch als „Coming to the App Store“ an. | Eine reduzierte Ansicht lohnt sich auch ohne umfangreichen Layouteditor. Reset-Aktionen sollten verständlich und korrigierbar sein. |
| [Rally Co-Pilot](https://www.rallycopilot.com/en/features) | Bewirbt Live-Abweichung, Durchschnitt, Split-Rechner sowie Erweiterungen für externe Empfänger und Apple Watch. | Verlässliches Live-Feedback ist wichtiger als eine nur scheinbar präzise Anzeige bei fehlenden Messdaten. |
| [Rabbit Rally 2.0](https://play.google.com/store/apps/details?id=com.rabbitrally.nav2droid) | Beschreibt GPS-Odometer, externe Sensoren, gesprochene Schnittwechsel und Auswertung. | Kalibrierung und Ansagen bleiben wichtige Bestandsfunktionen. Zusätzliche Hardware würde einen eigenen Integrations- und Testumfang benötigen. |

## Daraus abgeleitete und implementierte Verbesserungen

1. **Bessere Ablesbarkeit:** Fokusmodus für Total, Trip und Geschwindigkeit; ruhigere Karten; Systemschrift mit Dynamic Type; vertikale Anordnung wichtiger Anzeigen und Aktionen bei Bedienungshilfen-Schriftgrößen. Das ist eine Designentscheidung aus dem Vergleich, kein nachgewiesenes Ergebnis einer Nutzerstudie.
2. **Schneller Bereichswechsel:** native Tabs mit eigener Navigation für Übersicht, Tripmaster, Regularity und Route. Kalibrierung und Einstellungen bleiben in der Übersicht erreichbar.
3. **Fehlbedienungen korrigieren:** ein Trip-Reset bleibt sofort wirksam und lässt sich einmal rückgängig machen. Nach dem Reset weitergefahrene Strecke geht dabei nicht verloren. Ein erneuter Reset bei bereits null Metern überschreibt die Rückgängig-Stufe nicht.
4. **Zusätzlicher Fahrtwert:** Durchschnitt aus kalibrierter GPS-Rohstrecke / Fahrtzeit ohne Messpausen. Total-Sync und manuelle Korrekturen verfälschen diesen Wert nicht. Er ist kein Ersatz für den abschnittsweise berechneten Regularity-Sollschnitt.
5. **Ehrliches GPS-Feedback:** fehlende aktuelle Geschwindigkeit und Live-Abweichung werden mit einem Strich statt einem scheinbar gültigen Wert dargestellt. Status enthält Text und Symbol. Vorübergehende Empfangsfehler ändern die tatsächliche Genauigkeitsfreigabe nicht.
6. **Weitere Bedienprobleme:** Löschbestätigung für gespeicherte Fahrten, verständlicher Roadbook-Abgleich statt „SYNC“, erweiterbare Eingabeansicht und sichtbare Sperre des WP-Starts bei laufender Kalibrierung.

## Bezug zu Apples Human Interface Guidelines

- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): semantische Textstile und skalierende Ziffernanzeigen anstelle fester kleiner Beschriftungen.
- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): native Button-Stile für gedrückte/deaktivierte Zustände und mindestens 44 pt große wesentliche Aktionsflächen; Start und Fortsetzen stärker gewichtet als Beenden.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): Text zusätzlich zu Farbe, zugängliche Beschriftungen, adaptive Anordnung und semantische Vorder-/Hintergrundfarben.
- [HIG](https://developer.apple.com/design/human-interface-guidelines): native Navigation und Systemeinstellungen als Grundlage. Neue Installationen folgen der Systemdarstellung; vorhandene Nutzerpräferenzen bleiben erhalten.

Die Umsetzung ist an den HIG ausgerichtet, keine zertifizierte Konformitäts- oder Barrierefreiheitsprüfung. Der tatsächliche iPhone-Test mit VoiceOver, großer Schrift, Hell/Dunkel/Nacht und Querformat steht für diese Änderungen noch aus.

## Bewusst nicht Bestandteil dieser Iteration

Bluetooth-Tasten, externe GNSS-Empfänger, Apple Watch, Live Activities und Roadbook-OCR werden durch den Vergleich als mögliche spätere Erweiterungen sichtbar. Es wurden keine Hardware-Kompatibilität, künstliche Genauigkeitsversprechen, Abonnements oder Cloud-Dienste hinzugefügt. Diese Erweiterungen brauchen eine eigene Anforderungsklärung und Geräteprüfung.
