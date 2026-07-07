// Umrechnung von BGR nach CIE-L*a*b* fuer den Farbvergleich.
//
// Die App liest Farben als BGR-Werte. Fuer den Vergleich mit der Farbtafel
// werden Ringfarbe und Referenzfarbe in denselben L*a*b*-Farbraum umgerechnet.
// Danach wird der einfache euklidische Abstand ΔE*ab verwendet.
//
// Die sRGB-Linearisierung und der D65-Weisspunkt folgen der sRGB-Definition.
// Die L*a*b*-Formeln werden in der Bachelorarbeit in Abschnitt 3.5 beschrieben.
// CIEDE2000 wird hier nicht genutzt. Die App verwendet den einfacheren Abstand,
// damit die Entscheidung direkt im Code pruefbar bleibt.

import 'dart:math';

import 'bgr_farbe.dart';

// Reihenfolge der 12 Farbfelder auf der verwendeten Farbtafel.
// Diese Reihenfolge muss zur Messung der Referenzfarben passen.
const List<String> farbNamen = [
  'Schwarz',
  'Braun',
  'Rot',
  'Orange',
  'Gelb',
  'Gruen',
  'Blau',
  'Violett',
  'Grau',
  'Weiss',
  'Gold',
  'Silber',
];

/// Wandelt eine BGR-Farbe in L*a*b* um.
///
/// Rueckgabe: [L*, a*, b*]. L* beschreibt die Helligkeit, a* und b* die
/// Farbrichtungen.
List<double> bgrZuLab(BgrFarbe farbe) {
  // 1. Auf sRGB-Werte 0..1 skalieren.
  double r = farbe.r / 255.0;
  double g = farbe.g / 255.0;
  double b = farbe.b / 255.0;
  // 2. sRGB-Linearisierung nach IEC 61966-2-1.
  // Die sRGB-Transferfunktion besitzt einen linearen Teil fuer kleine Werte
  // und eine Potenzfunktion fuer groessere Werte.
  r = _linearisieren(r);
  g = _linearisieren(g);
  b = _linearisieren(b);
  // 3. Lineares RGB -> XYZ mit D65-Weisspunkt.
  // Matrix und Weisspunktwerte stammen aus der sRGB-Definition
  // nach IEC 61966-2-1 (nicht aus Gonzalez/Woods).
  double x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
  double y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
  double z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;
  // 4. Auf D65-Weisspunkt normieren.
  x = x / 0.95047;
  y = y / 1.00000;
  z = z / 1.08883;
  // 5. XYZ -> Lab.
  // Gleichungen (6-31) bis (6-34) aus Gonzalez/Woods 2018, S. 419.
  x = _xyzAnpassen(x);
  y = _xyzAnpassen(y);
  z = _xyzAnpassen(z);
  final l = 116.0 * y - 16.0;
  final a = 500.0 * (x - y);
  final labB = 200.0 * (y - z);
  return [l, a, labB];
}

// sRGB-Linearisierung nach IEC 61966-2-1.
double _linearisieren(double c) {
  if (c <= 0.04045) {
    return c / 12.92;
  }
  return pow((c + 0.055) / 1.055, 2.4).toDouble();
}

// Nichtlineare Hilfsfunktion fuer XYZ -> L*a*b*.
double _xyzAnpassen(double t) {
  if (t > 0.008856) {
    return pow(t, 1.0 / 3.0).toDouble();
  }
  return (7.787 * t) + (16.0 / 116.0);
}

/// Berechnet den einfachen euklidischen Abstand ΔE*ab im L*a*b*-Farbraum.
///
/// Quelle ΔE*ab: Tkalcic/Tasic. CIEDE2000 ist genauer, wird hier aber nicht
/// verwendet. Fuer InventarScan bleibt der einfache Abstand leichter pruefbar
/// und passt zur Farbtafel-Methode.
double labAbstand(BgrFarbe farbe1, BgrFarbe farbe2) {
  final lab1 = bgrZuLab(farbe1);
  final lab2 = bgrZuLab(farbe2);
  final dL = lab1[0] - lab2[0];
  final da = lab1[1] - lab2[1];
  final db = lab1[2] - lab2[2];
  return sqrt(dL * dL + da * da + db * db);
}

/// Sucht aus den erlaubten Farben die Referenzfarbe mit dem kleinsten
/// L*a*b*-Abstand.
///
/// Es werden nur Farben betrachtet, die an der Ringposition sinnvoll sind.
String naechsteFarbeUeberLab({
  required BgrFarbe pixel,
  required List<String> erlaubt,
  required List<BgrFarbe> referenzFarben,
}) {
  if (erlaubt.isEmpty) {
    throw Exception('Die Liste der erlaubten Farben darf nicht leer sein.');
  }
  if (referenzFarben.length != farbNamen.length) {
    throw Exception(
      'Es werden genau ${farbNamen.length} Referenzfarben erwartet.',
    );
  }
  String bester = erlaubt.first;
  double kleinsterAbstand = double.infinity;
  for (final name in erlaubt) {
    final index = farbNamen.indexOf(name);
    if (index == -1) {
      throw Exception('Unbekannte Farbe: $name');
    }
    final abstand = labAbstand(pixel, referenzFarben[index]);
    if (abstand < kleinsterAbstand) {
      kleinsterAbstand = abstand;
      bester = name;
    }
  }
  return bester;
}
