# LandkreisApp für Geocacher

LandkreisApp ist eine iPhone-App für Geocacher, die in jedem Landkreis und jeder kreisfreien Stadt Deutschlands mindestens einen Cache finden wollen, sei es für eine Landkreis-Challenge oder einfach als persönliches Sammelziel.

Die App zeigt auf einer Karte, in welchen der rund 400 Kreise du schon einen Cache gefunden hast und welche noch fehlen. Unterwegs meldet sie sich, sobald du einen Kreis ohne Fund betrittst, und sie zeigt dir die nächsten offenen Kreise in deiner Umgebung. Deine Funde liest sie aus der Pocket Query „My Finds“ von geocaching.com. Alles bleibt auf dem Gerät, es gibt kein Konto und keinen Server.

## Was die App kann
- **Karte** mit allen rund 400 Kreisen (Landkreise + kreisfreie Städte):
  🟢 Cache gefunden (Import) · 🔵 unterwegs abgehakt · 🟠 betreten, aber noch kein Fund · 🔴 offen. Der aktuelle Kreis ist blau umrandet.
- **Alarm beim Betreten** eines Kreises ohne Fund, auch wenn die App geschlossen ist. Bereits gefundene oder abgehakte Kreise lösen keinen Alarm aus.
- **In der Nähe:** Entfernung und Himmelsrichtung zur Grenze der 15 nächsten Kreise, Entfernung bis zur Grenze des aktuellen Kreises und die **5 nächsten noch offenen Kreise**. Antippen zeigt den Kreis auf der Karte.
- **Geocaching-Import** über die Pocket Query „My Finds“ (GPX). Jeder Fund wird seinem Kreis zugeordnet.
- **Fortschritt** für Deutschland und jedes Bundesland (🏆 bei 100 %).
- Kreis antippen → Details + **Navigation zur Kreisgrenze** in Apple Karten.
- **Kreis suchen:** Lupe oben auf der Karte → Name oder Bundesland eingeben → die Karte springt zum Kreis und zeigt die Details.
- **Unterwegs abhaken:** Kreis als gefunden markieren, bevor die nächste „My Finds“-PQ da ist. Wird beim nächsten Import automatisch durch den echten Fund ersetzt.
- Energiesparmodus für die Ortung im Hintergrund.

## Projekt öffnen (Mac mit Xcode 16 oder neuer)
1. Repo klonen: `git clone https://github.com/irrwisch1/LandkreisApp.git` und `LandkreisApp.xcodeproj` öffnen.
2. Target *LandkreisApp* → *Signing & Capabilities* → eigenes Team (Apple-ID) wählen.
   Falls Xcode meckert, die Bundle-ID `io.github.irrwisch1.landkreisapp` anpassen (muss eindeutig sein).
3. iPhone anschließen (Entwicklermodus an), ▶︎ starten.
4. Beim Start Mitteilungen erlauben und Standort auf **„Immer“** stellen, sonst gibt es keinen Alarm im Hintergrund.

Bereits eingerichtet: Background Mode „Location updates“ (`Info.plist`), Standort-Berechtigungstexte,
`counties.geojson` (VG250 Stand 01.01.) und `county-borders.lzfse` (VG25) liegen in `LandkreisApp/`. Alle Dateien im Ordner `LandkreisApp/`
werden automatisch ins Target übernommen.

## Kreisdaten vorbereiten
1. Beim BKG (gdz.bkg.bund.de → Open Data → *Verwaltungsgebiete 1:250 000*, „VG250“) die Shapefile-Variante laden, aktueller Stand.
2. `Data/generate_counties.sh /pfad/zu/VG250_KRS.shp` ausführen, das Skript schreibt direkt nach `LandkreisApp/counties.geojson`.
   Das Skript filtert die Landflächen (`GF = 4`), behält nur `AGS`, `GEN`, `BEZ`, rechnet nach WGS84 um und vereinfacht die Grenzen topologisch sauber auf 25 % der Punkte (ca. 2,6 MB, Grenzen im Mittel ca. 12 m genau).
3. Lizenz: [dl-de/by-2-0](https://www.govdata.de/dl-de/by-2-0). Den Quellenvermerk mit Veränderungshinweis zeigt die App in den Einstellungen. Bei neuen Daten das Jahr im Vermerk anpassen (Einstellungen, README, LICENSE).

Die Karte nutzt diese vereinfachten Grenzen. Für die Zuordnung der Funde wären sie an Kreisgrenzen zu ungenau, dafür gibt es die genaueren Grenzen aus VG25:
1. Beim BKG (gdz.bkg.bund.de → Open Data → *Verwaltungsgebiete 1:25 000*, „VG25“) die GeoPackage-Variante laden, aktueller Stand.
2. `python3 -m pip install shapely pyproj numpy`, dann `Data/generate_borders.py /pfad/zu/DE_VG25.gpkg` ausführen. Das Skript schreibt unvereinfacht nach `LandkreisApp/county-borders.lzfse` (ca. 9,5 MB). Es schneidet Hanau aus dem Main-Kinzig-Kreis heraus, weil VG25 mit Stand 31.12.2025 die Kreisfreiheit von Hanau ab 01.01.2026 noch nicht enthält.
3. Lizenz: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0), Quellenvermerk ebenfalls in den Einstellungen.

## Wichtig: Geocaching-Anbindung
Eine direkte Anmeldung mit dem Geocaching-Konto ist für private Apps nicht möglich: Die offizielle API gibt Geocaching HQ nur an geprüfte Partner-Apps frei, und automatisches Einloggen/Auslesen der Website verstößt gegen die Nutzungsbedingungen.
Der saubere Weg (Premium nötig):
1. geocaching.com → *Pocket Queries* → bei **„My Finds“** auf „Add to Queue“.
2. Nach einigen Minuten die ZIP herunterladen (landet in der Dateien-App).
3. In LandkreisApp: *Einstellungen → „My Finds“ importieren* und die ZIP direkt wählen, eine entpackte .gpx geht auch. Zusatz-Wegpunkte (`…-wpts.gpx`) werden ignoriert. Bei neuen Funden einfach wiederholen.

Hinweis: Bei Mystery-Caches zählt die im GPX enthaltene Koordinate. Liegt das Final in einem anderen Kreis, kann die Zuordnung abweichen.

## Testen ohne Autofahrt
In Xcode *Debug → Simulate Location* oder eine eigene GPX-Route laden, die über eine Kreisgrenze führt.

## Datenschutz
Die App überträgt keine Daten, alles bleibt auf dem Gerät, siehe [privacy.md](privacy.md).
Für den App Store dient der Link auf diese Datei als Datenschutz-URL, die GitHub-Issues als Support-URL.

## Lizenz
Code: [MIT](LICENSE). Ausgenommen sind die Kreisgrenzen:
- `LandkreisApp/counties.geojson`: © [BKG](https://www.bkg.bund.de) (2026) [dl-de/by-2-0](https://www.govdata.de/dl-de/by-2-0), [Datenquellen](https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_vg_nuts.pdf). Daten verändert: Landflächen gefiltert, nach WGS84 umgerechnet, Grenzen vereinfacht.
- `LandkreisApp/county-borders.lzfse`: © [BKG](https://www.bkg.bund.de) (2026) [CC BY 4.0](https://creativecommons.org/licenses/by/4.0), [Datenquellen](https://sgx.geodatenzentrum.de/web_public/gdz/datenquellen/datenquellen_vg25.pdf). Daten verändert: nach WGS84 umgerechnet, Hanau als kreisfreie Stadt aus dem Main-Kinzig-Kreis herausgelöst, in ein eigenes Binärformat umgewandelt.
