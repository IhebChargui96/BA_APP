// Geometrische Korrektur der Farbtafel.
//
// Die schraeg fotografierte Farbtafel wird auf ein rechteckiges Zielbild
// umgerechnet. Danach liegen die Farbfelder an festen Positionen und koennen
// in der App gleich gemessen werden.
//
// Grundlage sind Rueckwaertsabbildung und bilineare Interpolation aus der
// Vorlesung Bildverarbeitung von Stollmeier/Homann. Inhaltlich entspricht das
// Kapitel 3.8 der Bachelorarbeit.

import 'package:image/image.dart' as img;

import 'homographie.dart';

/// Korrigiert den angeklickten Farbbereich der Farbtafel.
///
/// Aus vier Eckpunkten im Originalbild wird ein rechteckiges Zielbild erzeugt.
/// Die Methode veraendert nicht die Farben selbst gezielt, sondern ordnet die
/// Pixel der Tafel geometrisch neu an.
img.Image korrigiereFarbtafel({
  required img.Image quellBild,
  required List<List<double>> quellEcken,
  required int zielBreite,
  required int zielHoehe,
}) {
  if (quellEcken.length != 4) {
    throw Exception('Es werden genau 4 Eckpunkte erwartet.');
  }
  if (zielBreite <= 0 || zielHoehe <= 0) {
    throw Exception('Zielgroesse muss positiv sein.');
  }
  final zielEcken = [
    [0.0, 0.0],
    [zielBreite - 1.0, 0.0],
    [zielBreite - 1.0, zielHoehe - 1.0],
    [0.0, zielHoehe - 1.0],
  ];
  // Rueckwaertsabbildung:
  // Fuer jeden Zielpixel wird gesucht, an welcher Stelle im Originalbild
  // der passende Farbwert liegt. So entstehen keine Luecken im Zielbild.
  final hInvers = berechneHomographie(quelle: zielEcken, ziel: quellEcken);
  final zielBild = img.Image(width: zielBreite, height: zielHoehe);
  for (int y = 0; y < zielHoehe; y++) {
    for (int x = 0; x < zielBreite; x++) {
      final quellPunkt = punktTransformieren(
        hInvers,
        x.toDouble(),
        y.toDouble(),
      );
      final bgr = _bilinearSampeln(quellBild, quellPunkt[0], quellPunkt[1]);
      // image.setPixelRgb erwartet RGB. Die interne Messung arbeitet hier
      // mit BGR, deshalb wird die Reihenfolge beim Schreiben wieder gedreht.
      zielBild.setPixelRgb(x, y, bgr[2], bgr[1], bgr[0]);
    }
  }
  return zielBild;
}

/// Liest einen Farbwert an einer nicht ganzzahligen Bildposition.
///
/// Wenn die transformierte Position zwischen Pixeln liegt, werden die vier
/// Nachbarpixel bilinear interpoliert. Rueckgabeformat: [B, G, R].
List<int> _bilinearSampeln(img.Image bild, double x, double y) {
  // Punkte ausserhalb des Bildes werden schwarz gesetzt. Das betrifft nur
  // Randbereiche, wenn ein Zielpunkt ausserhalb des Originalbildes landet.
  if (x < 0 || y < 0 || x > bild.width - 1 || y > bild.height - 1) {
    return [0, 0, 0];
  }
  final x0 = x.floor();
  final y0 = y.floor();
  final x1 = _begrenzeInt(x0 + 1, 0, bild.width - 1);
  final y1 = _begrenzeInt(y0 + 1, 0, bild.height - 1);
  final dx = x - x0;
  final dy = y - y0;
  final p00 = bild.getPixel(x0, y0);
  final p10 = bild.getPixel(x1, y0);
  final p01 = bild.getPixel(x0, y1);
  final p11 = bild.getPixel(x1, y1);
  final b = _interpoliere(
    p00.b.toDouble(),
    p10.b.toDouble(),
    p01.b.toDouble(),
    p11.b.toDouble(),
    dx,
    dy,
  );
  final g = _interpoliere(
    p00.g.toDouble(),
    p10.g.toDouble(),
    p01.g.toDouble(),
    p11.g.toDouble(),
    dx,
    dy,
  );
  final r = _interpoliere(
    p00.r.toDouble(),
    p10.r.toDouble(),
    p01.r.toDouble(),
    p11.r.toDouble(),
    dx,
    dy,
  );
  return [
    b.round().clamp(0, 255).toInt(),
    g.round().clamp(0, 255).toInt(),
    r.round().clamp(0, 255).toInt(),
  ];
}

/// Interpoliert bilinear zwischen vier Eckwerten.
///
/// p00 = oben links, p10 = oben rechts, p01 = unten links, p11 = unten rechts.
double _interpoliere(
  double p00,
  double p10,
  double p01,
  double p11,
  double dx,
  double dy,
) {
  final oben = p00 * (1 - dx) + p10 * dx;
  final unten = p01 * (1 - dx) + p11 * dx;
  return oben * (1 - dy) + unten * dy;
}

// Begrenzt einen ganzzahligen Wert auf den Bereich von minimum bis maximum.
int _begrenzeInt(int wert, int minimum, int maximum) {
  if (wert < minimum) {
    return minimum;
  }
  if (wert > maximum) {
    return maximum;
  }
  return wert;
}
