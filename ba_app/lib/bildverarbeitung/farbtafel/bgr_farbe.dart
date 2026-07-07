// BGR-Kanalreihenfolge fuer gemessene Farben.
//
// OpenCV nutzt in der Python-Vorarbeit die Reihenfolge Blau, Gruen, Rot.
// Die Dart-Auswertung uebernimmt diese Reihenfolge, damit Messwerte,
// Referenzfarben und Farbregeln gleich gelesen werden.
// BGR ist hier kein eigener Farbraum, sondern nur die Reihenfolge der Kanaele.

/// Kleine Datenklasse fuer einen gemessenen Farbwert.
///
/// Jeder Kanal liegt zwischen 0 und 255.
class BgrFarbe {
  final int b;
  final int g;
  final int r;

  /// Erstellt eine BGR-Farbe aus den drei Kanalwerten.
  ///
  /// Die asserts stellen sicher, dass jeder Kanal im gueltigen Bereich
  /// von 0 bis 255 liegt.
  const BgrFarbe(this.b, this.g, this.r)
    : assert(b >= 0 && b <= 255),
      assert(g >= 0 && g <= 255),
      assert(r >= 0 && r <= 255);

  /// Erstellt eine BGR-Farbe aus einer RGB-Eingabe.
  ///
  /// Das ist praktisch, wenn eine Bibliothek die Werte als Rot, Gruen, Blau
  /// liefert, die weitere Auswertung aber BGR erwartet.
  factory BgrFarbe.ausRgb(int rot, int gruen, int blau) {
    return BgrFarbe(blau, gruen, rot);
  }

  /// Gibt die Farbe als lesbaren Text zurueck, zum Beispiel BGR(b=10, g=20, r=30).
  @override
  String toString() {
    return 'BGR(b=$b, g=$g, r=$r)';
  }

  /// Zwei BGR-Farben gelten als gleich, wenn alle drei Kanalwerte uebereinstimmen.
  @override
  bool operator ==(Object other) {
    return other is BgrFarbe && other.b == b && other.g == g && other.r == r;
  }

  /// Hash-Wert passend zum Gleichheitsvergleich ueber die drei Kanaele.
  @override
  int get hashCode {
    return Object.hash(b, g, r);
  }
}
