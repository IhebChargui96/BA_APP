// Homographie fuer die geometrische Korrektur der Farbtafel.
//
// Eine schraeg fotografierte Farbtafel wird als ebene Flaeche betrachtet.
// Vier Eckpunkte reichen aus, um diese Flaeche auf ein rechteckiges Zielbild
// abzubilden. Dafuer wird eine projektive Transformation verwendet.
//
// In der Bachelorarbeit gehoert diese Datei zu Abschnitt 3.8.
// Als fachliche Grundlage dienen die Vorlesung Bildverarbeitung
// (Stollmeier/Homann) und Szeliski.

import 'gauss_loeser.dart';

// Kleine Schwelle, damit nicht durch eine fast nullwertige homogene Koordinate geteilt wird.
const double _wEpsilon = 1e-12;

/// Berechnet eine 3x3-Homographie aus vier Punktepaaren.
///
/// `quelle` enthaelt die vier Punkte im Ausgangsbild, `ziel` die passenden
/// Punkte im Zielbild. Die Reihenfolge der Punkte muss dabei zusammenpassen.
List<List<double>> berechneHomographie({
  required List<List<double>> quelle,
  required List<List<double>> ziel,
}) {
  _pruefePunkte(quelle, 'quelle');
  _pruefePunkte(ziel, 'ziel');

  final a = <List<double>>[];
  final b = <double>[];

  for (int i = 0; i < 4; i++) {
    final x = quelle[i][0];
    final y = quelle[i][1];

    final xZiel = ziel[i][0];
    final yZiel = ziel[i][1];

    // Gleichung fuer die x-Koordinate:
    // xZiel = (h11*x + h12*y + h13) / (h31*x + h32*y + 1)
    a.add([x, y, 1.0, 0.0, 0.0, 0.0, -x * xZiel, -y * xZiel]);
    b.add(xZiel);

    // Gleichung fuer die y-Koordinate:
    // yZiel = (h21*x + h22*y + h23) / (h31*x + h32*y + 1)
    a.add([0.0, 0.0, 0.0, x, y, 1.0, -x * yZiel, -y * yZiel]);
    b.add(yZiel);
  }

  // Gesucht werden die acht freien Matrixwerte. h33 wird auf 1 gesetzt.
  final h = gaussLoesen(a, b);

  if (h.length != 8) {
    throw Exception('Homographie konnte nicht berechnet werden.');
  }

  return [
    [h[0], h[1], h[2]],
    [h[3], h[4], h[5]],
    [h[6], h[7], 1.0],
  ];
}

/// Wendet die Homographie auf einen Punkt (x, y) an.
///
/// Intern wird mit homogenen Koordinaten gerechnet. Nach der Matrixmultiplikation
/// wird durch `w` geteilt, damit wieder normale Bildkoordinaten entstehen.
List<double> punktTransformieren(
  List<List<double>> homographie,
  double x,
  double y,
) {
  _pruefeHomographie(homographie);

  final h = homographie;

  final xZaehler = h[0][0] * x + h[0][1] * y + h[0][2];
  final yZaehler = h[1][0] * x + h[1][1] * y + h[1][2];
  final w = h[2][0] * x + h[2][1] * y + h[2][2];

  if (w.abs() < _wEpsilon) {
    throw Exception('Punkt kann nicht transformiert werden, weil w = 0 ist.');
  }

  return [xZaehler / w, yZaehler / w];
}

// Prueft, ob genau vier Punkte mit x- und y-Koordinate vorliegen.
void _pruefePunkte(List<List<double>> punkte, String name) {
  if (punkte.length != 4) {
    throw Exception(
      'Es werden genau 4 Punkte erwartet: $name hat ${punkte.length}.',
    );
  }

  for (int i = 0; i < punkte.length; i++) {
    if (punkte[i].length < 2) {
      throw Exception('Punkt ${i + 1} in $name hat keine x- und y-Koordinate.');
    }
  }
}

// Prueft, ob die Matrix als 3x3-Homographie vorliegt.
void _pruefeHomographie(List<List<double>> h) {
  if (h.length != 3) {
    throw Exception('Homographie muss 3 Zeilen haben.');
  }

  for (int i = 0; i < 3; i++) {
    if (h[i].length != 3) {
      throw Exception('Homographie-Zeile ${i + 1} muss 3 Werte haben.');
    }
  }
}
