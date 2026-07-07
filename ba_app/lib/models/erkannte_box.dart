/// Rechteckiger Bildbereich im Originalfoto.
///
/// Die Box beschreibt die Lage eines erkannten Objekts im Bild. Sie wird zum
/// Beispiel fuer YOLO-Ergebnisse verwendet und enthaelt zusaetzlich die
/// Konfidenz der Erkennung.
class ErkannteBox {
  final int x;
  final int y;
  final int breite;
  final int hoehe;
  final double konfidenz;

  const ErkannteBox({
    required this.x,
    required this.y,
    required this.breite,
    required this.hoehe,
    required this.konfidenz,
  });

  // Rechte Bildkante der Box (x + breite).
  int get rechts => x + breite;
  // Untere Bildkante der Box (y + hoehe).
  int get unten => y + hoehe;

  /// Formatiert die Konfidenz fuer die Anzeige in der App.
  String get konfidenzText {
    return '${(konfidenz * 100).toStringAsFixed(1)} %';
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() {
    return 'Box(x=$x, y=$y, breite=$breite, hoehe=$hoehe, '
        'konfidenz=$konfidenzText)';
  }
}
