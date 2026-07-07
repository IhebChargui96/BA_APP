// Loest kleine lineare Gleichungssysteme fuer die Homographie.
//
// Bei der geometrischen Korrektur der Farbtafel entstehen acht unbekannte
// Homographie-Parameter. Diese Datei loest das dazugehoerige lineare
// Gleichungssystem mit Gauss-Elimination und Pivotsuche.
//
// Als fachliche Grundlage dient die Gauss-Elimination nach Dahmen/Reusken.
// In der Bachelorarbeit wird diese Stelle in Abschnitt 3.8 eingeordnet.

const double _pivotEpsilon = 1e-12;

/// Loest das lineare Gleichungssystem A * x = b.
///
/// Die Eingabematrix wird nicht direkt veraendert. Fuer die Rechnung wird
/// eine Arbeitskopie der erweiterten Matrix [A | b] angelegt.
List<double> gaussLoesen(List<List<double>> matrix, List<double> rhs) {
  final n = rhs.length;

  if (n == 0) {
    throw Exception('Das Gleichungssystem ist leer.');
  }

  if (matrix.length != n) {
    throw Exception('Matrix-Hoehe (${matrix.length}) passt nicht zu rhs ($n).');
  }

  // Arbeitskopie der erweiterten Matrix [A | b].
  final a = <List<double>>[];

  for (int i = 0; i < n; i++) {
    if (matrix[i].length != n) {
      throw Exception(
        'Matrix muss quadratisch sein: '
        'Zeile $i hat ${matrix[i].length} Eintraege.',
      );
    }

    a.add([...matrix[i], rhs[i]]);
  }

  // Vorwaertselimination mit Pivotsuche.
  for (int spalte = 0; spalte < n; spalte++) {
    int pivotZeile = spalte;
    double pivotWert = a[spalte][spalte].abs();

    // In der aktuellen Spalte wird die stabilste Pivot-Zeile gesucht.
    for (int i = spalte + 1; i < n; i++) {
      final wert = a[i][spalte].abs();

      if (wert > pivotWert) {
        pivotWert = wert;
        pivotZeile = i;
      }
    }

    if (pivotWert < _pivotEpsilon) {
      throw Exception('Matrix ist singulaer oder fast singulaer.');
    }

    // Zeilen tauschen, wenn ein besserer Pivot gefunden wurde.
    if (pivotZeile != spalte) {
      final temp = a[spalte];
      a[spalte] = a[pivotZeile];
      a[pivotZeile] = temp;
    }

    // Untere Zeilen auf 0 bringen.
    for (int i = spalte + 1; i < n; i++) {
      final faktor = a[i][spalte] / a[spalte][spalte];

      for (int j = spalte; j <= n; j++) {
        a[i][j] = a[i][j] - faktor * a[spalte][j];
      }

      // Rundungsreste an dieser Stelle entfernen.
      a[i][spalte] = 0.0;
    }
  }

  // Rueckwaertseinsetzen.
  final x = List<double>.filled(n, 0.0);

  for (int i = n - 1; i >= 0; i--) {
    double summe = a[i][n];

    for (int j = i + 1; j < n; j++) {
      summe = summe - a[i][j] * x[j];
    }

    if (a[i][i].abs() < _pivotEpsilon) {
      throw Exception('Rueckwaertseinsetzen nicht moeglich.');
    }

    x[i] = summe / a[i][i];
  }

  return x;
}
