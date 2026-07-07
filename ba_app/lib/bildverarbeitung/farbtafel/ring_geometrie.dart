// Startpunkte fuer die Messung der Farbringe innerhalb einer YOLO-Box.
//
// Die genaue Lage der einzelnen Ringe wird hier nicht im Bild gesucht.
// Stattdessen werden die Punkte gleichmaessig entlang der laengeren Achse
// der erkannten Widerstandsbox verteilt. Das ist eine einfache Naeherung
// fuer Modus 1 und Modus 2.
//
// Die Leserichtung kann diese Geometrie nicht sicher bestimmen. Wenn ein
// Widerstand andersherum liegt oder die Ringe ungleichmaessig verteilt sind,
// muss die Nutzerin oder der Nutzer die Punkte im zweiten Scanmodus korrigieren.
// Diese Grenze wird in der Evaluation der Bachelorarbeit beschrieben.

import '../../models/erkannte_box.dart';

// Standardwerte fuer die Ringverteilung innerhalb der laengeren Box-Achse.
const double ringStartAnteil = 0.15;
const double ringEndAnteil = 0.75;

/// Verteilt vier oder fuenf Ringpunkte in einer erkannten Widerstandsbox.
///
/// Bei einer horizontalen Box werden die Punkte von links nach rechts gesetzt.
/// Bei einer vertikalen Box werden sie von oben nach unten gesetzt.
List<List<double>> verteileRingeInBox({
  required ErkannteBox box,
  required int gesamtRinge,
  double startAnteil = ringStartAnteil,
  double endAnteil = ringEndAnteil,
}) {
  if (gesamtRinge != 4 && gesamtRinge != 5) {
    throw Exception('Nur 4 oder 5 Ringe unterstuetzt, bekommen: $gesamtRinge.');
  }

  if (box.breite <= 0 || box.hoehe <= 0) {
    throw Exception('YOLO-Box hat eine ungueltige Groesse.');
  }

  if (startAnteil < 0.0 || endAnteil > 1.0 || startAnteil >= endAnteil) {
    throw Exception(
      'Ungueltige Ring-Anteile: startAnteil=$startAnteil, '
      'endAnteil=$endAnteil.',
    );
  }

  final positionen = <List<double>>[];

  // Die laengere Achse passt besser zur Ausrichtung des Widerstands.
  if (box.breite >= box.hoehe) {
    final yMitte = box.y + box.hoehe / 2.0;
    final xStart = box.x + box.breite * startAnteil;
    final xEnde = box.x + box.breite * endAnteil;
    final abstand = (xEnde - xStart) / (gesamtRinge - 1);

    for (int i = 0; i < gesamtRinge; i++) {
      final x = xStart + i * abstand;
      positionen.add([x, yMitte]);
    }
  } else {
    final xMitte = box.x + box.breite / 2.0;
    final yStart = box.y + box.hoehe * startAnteil;
    final yEnde = box.y + box.hoehe * endAnteil;
    final abstand = (yEnde - yStart) / (gesamtRinge - 1);

    for (int i = 0; i < gesamtRinge; i++) {
      final y = yStart + i * abstand;
      positionen.add([xMitte, y]);
    }
  }

  return positionen;
}
