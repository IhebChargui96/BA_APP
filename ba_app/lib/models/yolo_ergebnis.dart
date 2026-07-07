import 'erkannte_box.dart';

/// Ergebnis einer YOLO-Erkennung fuer eine bestimmte Klasse.
///
/// YOLO lokalisiert nur den Widerstand oder die Farbreferenz. Der
/// Widerstandswert wird danach getrennt ueber die Farbringauswertung berechnet.
class YoloErgebnis {
  final ErkannteBox? box;
  final double maximaleKonfidenz;
  final int inferenzZeitMs;

  const YoloErgebnis({
    required this.box,
    required this.maximaleKonfidenz,
    required this.inferenzZeitMs,
  });

  /// true bedeutet: Es gibt eine Box oberhalb der verwendeten Schwelle.
  bool get wurdeErkannt {
    return box != null;
  }

  /// Formatiert die maximale Konfidenz fuer Hinweise in der Oberflaeche.
  String get konfidenzText {
    return '${(maximaleKonfidenz * 100).toStringAsFixed(1)} %';
  }
}
