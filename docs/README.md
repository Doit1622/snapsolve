# SnapSolve Web

Web-Version von SnapSolve als einzelne Datei `docs/index.html`. Läuft in Safari auf dem iPhone, ohne Mac und ohne Xcode.

## Warum HTTPS nötig ist

Safari gibt die Kamera nur auf Seiten frei, die über HTTPS geladen werden. Eine lokal geöffnete Datei funktioniert deshalb nicht. Am einfachsten ist GitHub Pages, das ist kostenlos.

## Auf GitHub Pages bereitstellen

1. Auf github.com ein neues Repository anlegen, z. B. `snapsolve`. Es muss öffentlich sein, damit GitHub Pages kostenlos funktioniert. Die Datei enthält keinen API-Key.
2. `docs/index.html` hochladen: *Add file → Upload files*.
3. *Settings → Pages*, unter *Branch* `main` und den Ordner `/docs` wählen, speichern.
4. Nach etwa einer Minute ist die App unter `https://DEINNAME.github.io/snapsolve/` erreichbar.

Der API-Key steht nie in der Datei. Du trägst ihn erst auf dem iPhone in den Einstellungen ein, er bleibt nur dort im Browser gespeichert.

## Auf dem iPhone einrichten

1. Die Adresse in Safari öffnen.
2. Teilen-Symbol → *Zum Home-Bildschirm*. Dann startet SnapSolve wie eine App im Vollbild.
3. Beim ersten Start den Kamerazugriff erlauben und den API-Key eintragen.

## Bedienung

- **Intervall** über die Leiste wählen, dann **Start**. **Einmal** macht einen einzelnen Durchlauf.
- Lautsprecher-Symbol liest die letzte Lösung erneut vor.
- Schloss-Symbol sperrt den Bildschirm gegen Fehlbedienung. Er wird abgedunkelt, bleibt aber an und zeigt „SnapSolve aktiv“ samt Status. Zum Entsperren 1,5 Sekunden gedrückt halten. Mit externer Tastatur sperrt auch die Taste L.

## Einschränkungen

- Safari muss im Vordergrund und der Bildschirm an bleiben. Die App hält den Bildschirm über die Wake-Lock-Funktion wach. Wird das iPhone gesperrt oder die App gewechselt, pausiert die Kamera.
- Safari erlaubt Sprachausgabe erst nach einer Berührung. Deshalb startet das Vorlesen erst, nachdem du einmal auf Start oder Einmal getippt hast.
- Der API-Key liegt im localStorage des Browsers. Wer das entsperrte iPhone in der Hand hat, kann ihn auslesen. Nutze am besten einen eigenen Key mit Ausgabenlimit in der Console.
