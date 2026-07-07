// Kanalweise Medianmessung in einem rechteckigen ROI.
//
// Fuer die Farbringmessung wird nicht ein einzelner Pixel verwendet.
// Stattdessen werden alle Pixel in einem kleinen Messbereich betrachtet.
// Aus jedem Kanal wird der Median gebildet. Dadurch beeinflussen einzelne
// helle Reflexe oder dunkle Stoerstellen den Messwert weniger stark.
//
// Wichtig: Hier wird kein Filter ueber das ganze Bild ausgefuehrt.
// Es wird nur ein Messwert fuer den ausgewaehlten ROI gebildet.
// Fachlicher Bezug: Abschnitt 3.3 der Bachelorarbeit und die dort genannte
// Vorlesung Bildverarbeitung von Stollmeier/Homann.

import 'package:image/image.dart' as img;

import 'bgr_farbe.dart';

/// Liest aus einem rechteckigen Bildbereich den Medianwert fuer B, G und R.
///
/// `x1`/`y1` ist die linke obere Ecke. `x2`/`y2` ist die rechte untere
/// Grenze. Diese rechte und untere Grenze werden nicht mehr mitgezaehlt.
BgrFarbe medianBgrAusRoi({
  required img.Image bild,
  required int x1,
  required int y1,
  required int x2,
  required int y2,
}) {
  if (x1 >= x2 || y1 >= y2) {
    throw Exception('Ungueltiger ROI: x1=$x1 x2=$x2 y1=$y1 y2=$y2');
  }

  if (x1 < 0 || y1 < 0 || x2 > bild.width || y2 > bild.height) {
    throw Exception(
      'ROI ($x1,$y1)-($x2,$y2) liegt ausserhalb des Bildes '
      '(${bild.width}x${bild.height})',
    );
  }

  final blau = <int>[];
  final gruen = <int>[];
  final rot = <int>[];

  for (int y = y1; y < y2; y++) {
    for (int x = x1; x < x2; x++) {
      final pixel = bild.getPixel(x, y);

      blau.add(pixel.b.toInt());
      gruen.add(pixel.g.toInt());
      rot.add(pixel.r.toInt());
    }
  }

  return BgrFarbe(_median(blau), _median(gruen), _median(rot));
}

/// Berechnet den Median einer Werteliste.
///
/// Bei ungerader Anzahl wird der mittlere Wert genutzt. Bei gerader Anzahl
/// wird der Mittelwert der zwei mittleren Werte ganzzahlig abgerundet.
/// Das passt zur Python-Vorarbeit, weil dort `int(np.median(...))` verwendet
/// wurde und die Farbkanalwerte nicht negativ sind.
int _median(List<int> werte) {
  if (werte.isEmpty) {
    throw Exception('Median kann nicht aus leerer Liste berechnet werden.');
  }

  werte.sort();

  final mitte = werte.length ~/ 2;

  if (werte.length.isOdd) {
    return werte[mitte];
  }

  return (werte[mitte - 1] + werte[mitte]) ~/ 2;
}
