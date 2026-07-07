README - Flutter-Projekt InventarScan

Diese Anlage enthält das vollständige Flutter-Projekt der App InventarScan.

Die App wurde im Rahmen der Bachelorarbeit

"Entwicklung einer Flutter-basierten App zur Inventarverwaltung und bildbasierten Auswertung von Widerständen"

an der Hochschule Hannover entwickelt.

Autor:
Iheb Chargui

Studiengang:
Elektrotechnik, Vertiefung Ingenieurinformatik

Betreuung:
Prof. Dr.-Ing. Martin Mutz
Prof. Dr.-Ing. Hanno Homann


1. Inhalt des Projekts

Das Flutter-Projekt enthält den Quellcode der App InventarScan. Die App verbindet eine lokale Inventarverwaltung mit einem bildbasierten Widerstandscheck.

Wichtige Funktionen der App sind:

- Produkte anlegen, bearbeiten, löschen und suchen
- Kategorien, Lagerorte und Lagerplätze verwalten
- Lagerplätze über QR-Code öffnen
- Produktdaten als CSV-Datei exportieren und importieren
- Produktfotos lokal speichern
- Ausleihen verwalten
- niedrige Stückzahlen anzeigen
- Widerstände per Foto auswerten
- Widerstand und Farbreferenz mit YOLO11n/TFLite lokalisieren
- Farbringe mithilfe einer Farbtafel auswerten
- Widerstandswert und Toleranz berechnen


2. Wichtige Projektbestandteile

Die wichtigsten Ordner und Dateien sind:

- lib/
  Quellcode der App

- lib/controllers/
  Controller für Produktverwaltung, Lagerorte, Lagerplätze, Kategorien, Ausleihen und Scanlogik

- lib/models/
  Datenmodelle der App, zum Beispiel Produkt, Kategorie, Lagerort, Lagerplatz und Ausleihe

- lib/screens/
  Benutzeroberflächen der App

- lib/widgets/
  Wiederverwendbare Oberflächenelemente

- lib/services/
  Technische Dienste, zum Beispiel Datenbankservice und YOLO/TFLite-Service

- lib/helper/ oder lib/helpers/
  Hilfsfunktionen für CSV, Fotoverwaltung, Validierung, Bildverarbeitung und Widerstandsberechnung

- assets/
  Ressourcen der App, zum Beispiel das YOLO/TFLite-Modell

- pubspec.yaml
  Flutter-Abhängigkeiten und eingetragene Assets


3. Voraussetzungen

Zum Ausführen des Projekts werden benötigt:

- Flutter SDK
- Dart SDK
- Visual Studio Code oder Android Studio
- Android-Gerät oder Android-Emulator


4. Projekt starten

Das Projekt in Visual Studio Code oder Android Studio öffnen.

Danach im Terminal im Projektordner ausführen:

flutter pub get

Anschließend ein Android-Gerät oder einen Emulator starten und die App ausführen mit:

flutter run


5. Hinweise zur App

Die App arbeitet lokal auf dem Gerät. Die Produktdaten werden in einer SQLite-Datenbank gespeichert.

Das YOLO11n-Modell wird lokal über TensorFlow Lite ausgeführt. Für den Widerstandscheck ist keine Cloud-Verbindung notwendig.

Roboflow und Google Colab wurden nur während der Entwicklung für Datensatz, Training und Export des YOLO-Modells verwendet. Sie gehören nicht zur später ausgeführten App.


6. Hinweise zu Fotos und CSV

Produktfotos werden nicht direkt in der SQLite-Datenbank gespeichert. Die App speichert nur den Pfad zur Bilddatei.

Beim CSV-Export werden die tabellarischen Produktdaten exportiert. Bilddateien selbst werden nicht in die CSV-Datei geschrieben.


7. Hinweis zum internen Projektnamen

Nach außen heißt die App InventarScan.

In einigen internen Dateien oder Ordnern kann noch der frühere Projektname "electrostock" vorkommen, zum Beispiel bei der Datenbankdatei oder beim Fotoordner. Diese Namen wurden beibehalten, damit vorhandene Daten nicht verloren gehen.


8. Zweck dieser Anlage

Diese Anlage dient dazu, den abgegebenen Quellcode der App nachvollziehbar bereitzustellen.

