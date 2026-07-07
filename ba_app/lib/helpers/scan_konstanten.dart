/// Zentrale Werte fuer den Scanbereich der App.
///
/// Die Konstanten gehoeren zum aktuell verwendeten YOLO11n-TFLite-Modell.
/// Bei einem anderen Modell muessen vor allem Eingabegroesse, Ausgabeform und
/// Modellpfad erneut geprueft werden.
class ScanKonstanten {
  /// Quadratische Eingabegroesse des YOLO-Modells in Pixeln.
  static const int modellGroesse = 640;

  /// Anzahl der moeglichen YOLO-Kandidaten pro Bild.
  ///
  /// Bei 640 x 640 Pixeln entstehen 80 * 80, 40 * 40 und 20 * 20 Positionen.
  /// Zusammen ergibt das 8400 Kandidaten. Das sind noch keine erkannten
  /// Objekte, sondern nur moegliche Vorhersagepositionen.
  static const int anzahlYoloVorhersagen = 8400;

  /// Untere Grenze fuer die Konfidenz einer Erkennung.
  ///
  /// Der Wert ist ein Parameter der App. Er liegt niedrig genug, damit reale
  /// Aufnahmen nicht zu frueh verworfen werden. Die Qualitaet des Modells wird
  /// getrennt in der Evaluation der Bachelorarbeit bewertet.
  static const double mindestKonfidenz = 0.25;

  /// Maximale Groesse fuer Fotos, die mit der Kamera aufgenommen werden.
  ///
  /// Auf dem verwendeten Pixel 4a liegen die Fotos in diesem Bereich. Eine zu
  /// kleine Groesse wuerde Details an den Farbringen verlieren.
  static const int maximaleFotoBreite = 4032;
  static const int maximaleFotoHoehe = 4032;

  /// Pfad zum eingebundenen TFLite-Modell in den App-Assets.
  static const String modellPfad = 'assets/models/best_float32.tflite';
}
