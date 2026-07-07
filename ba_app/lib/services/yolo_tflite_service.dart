import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../helpers/scan_konstanten.dart';
import '../models/erkannte_box.dart';
import '../models/yolo_ergebnis.dart';

/// Fuehrt die lokale YOLO/TFLite-Erkennung fuer InventarScan aus.
///
/// Das Modell lokalisiert nur Widerstand und Farbreferenz im Bild. Der
/// Widerstandswert wird danach getrennt ueber die Farbringauswertung berechnet.
///
/// Erwartetes Modell:
/// - YOLO11n, als TensorFlow-Lite-Datei exportiert
/// - Eingabe: [1, 640, 640, 3], RGB, Wertebereich 0..1
/// - Ausgabe: [1, 4 + K, 8400]
///
/// Die ersten vier Ausgabewerte sind cx, cy, Breite und Hoehe der Box.
/// Danach folgen die Klassenwerte. Beim 2-Klassen-Modell gilt:
/// 0 = farbreferenz, 1 = widerstand.
class YoloTfliteService {
  Interpreter? _interpreter;
  int _anzahlKlassen = 1;
  static const int _klasseFarbreferenz = 0;
  static const int _klasseWiderstand = 1;
  // Grenze, ab der ein Boxwert als Modellpixel statt als normalisierter
  // Wert (0..1) interpretiert wird. Der Wert liegt etwas ueber 1,0, damit
  // kleine numerische Abweichungen bei normalisierten Exporten nicht
  // faelschlich als Modellpixel gelten.
  static const double _normalisierteBoxwertGrenze = 1.5;

  // True, wenn das Modell geladen und einsatzbereit ist.
  bool get istGeladen {
    return _interpreter != null;
  }

  // Anzahl der Klassen des geladenen Modells (1 oder 2).
  int get anzahlKlassen {
    return _anzahlKlassen;
  }

  /// Laedt das TFLite-Modell und prueft die erwarteten Tensor-Formen.
  ///
  /// Wenn das Modell nicht zur Auswertung passt, wird es geschlossen und
  /// ein Fehler mit den gefundenen Formen ausgegeben.
  Future<void> modellLaden() async {
    if (_interpreter != null) {
      return;
    }
    _interpreter = await Interpreter.fromAsset(
      ScanKonstanten.modellPfad,
      options: InterpreterOptions()..threads = 4,
    );
    final eingabe = _interpreter!.getInputTensor(0).shape;
    final ausgabe = _interpreter!.getOutputTensor(0).shape;
    final eingabeOk =
        eingabe.length == 4 &&
        eingabe[1] == ScanKonstanten.modellGroesse &&
        eingabe[2] == ScanKonstanten.modellGroesse &&
        eingabe[3] == 3;
    final ausgabeOk =
        ausgabe.length == 3 &&
        (ausgabe[1] == 5 || ausgabe[1] == 6) &&
        ausgabe[2] == ScanKonstanten.anzahlYoloVorhersagen;
    if (!eingabeOk || !ausgabeOk) {
      _interpreter?.close();
      _interpreter = null;
      throw StateError(
        'Modell passt nicht zur Auswertung. '
        'Eingabe: $eingabe, Ausgabe: $ausgabe. '
        'Erwartet: [1, 640, 640, 3] und [1, 5 oder 6, 8400].',
      );
    }
    // 4 Box-Werte plus K Klassen-Konfidenzen.
    _anzahlKlassen = ausgabe[1] - 4;
  }

  /// Sucht die beste Widerstands-Box im Bild.
  ///
  /// Beim 1-Klassen-Modell ist die einzige Klasse der Widerstand. Beim
  /// 2-Klassen-Modell wird die Klasse widerstand ueber Index 1 gelesen.
  Future<YoloErgebnis> widerstandErkennen(img.Image originalBild) async {
    final klassenIndex = _anzahlKlassen == 1 ? 0 : _klasseWiderstand;
    return _erkenneKlasse(
      originalBild: originalBild,
      klassenIndex: klassenIndex,
    );
  }

  /// Sucht die beste Farbreferenz-Box im Bild.
  ///
  /// Bei einem 1-Klassen-Modell gibt es keine Farbreferenz-Klasse. Dann wird
  /// ein leeres Ergebnis zurueckgegeben.
  Future<YoloErgebnis> farbreferenzErkennen(img.Image originalBild) async {
    if (_anzahlKlassen < 2) {
      return const YoloErgebnis(
        box: null,
        maximaleKonfidenz: 0.0,
        inferenzZeitMs: 0,
      );
    }
    return _erkenneKlasse(
      originalBild: originalBild,
      klassenIndex: _klasseFarbreferenz,
    );
  }

  // Gemeinsamer Ablauf beider Erkennungen: Bild auf 640 x 640 skalieren,
  // auf 0..1 normalisieren, Modell ausfuehren und die beste Box
  // der gesuchten Klasse auswerten.
  Future<YoloErgebnis> _erkenneKlasse({
    required img.Image originalBild,
    required int klassenIndex,
  }) async {
    if (_interpreter == null) {
      throw StateError('YOLO-Modell wurde noch nicht geladen.');
    }
    final groesse = ScanKonstanten.modellGroesse;
    // Das Bild wird direkt auf 640 x 640 skaliert.
    // Eine Skalierung mit Randauffuellung waere eine moegliche Verbesserung,
    // wenn Boxen bei nicht-quadratischen Bildern systematisch verschoben sind.
    final eingabeBild = img.copyResize(
      originalBild,
      width: groesse,
      height: groesse,
    );
    final eingabe = List.generate(
      1,
      (_) => List.generate(
        groesse,
        (y) => List.generate(groesse, (x) {
          final pixel = eingabeBild.getPixel(x, y);
          return [
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        }),
      ),
    );
    final zeilen = 4 + _anzahlKlassen;
    final ausgabe = List.generate(
      1,
      (_) => List.generate(
        zeilen,
        (_) => List<double>.filled(ScanKonstanten.anzahlYoloVorhersagen, 0.0),
      ),
    );
    final uhr = Stopwatch()..start();
    _interpreter!.run(eingabe, ausgabe);
    uhr.stop();
    return _besteBoxFuerKlasse(
      ausgabe: ausgabe,
      klassenIndex: klassenIndex,
      originalBreite: originalBild.width,
      originalHoehe: originalBild.height,
      inferenzZeitMs: uhr.elapsedMilliseconds,
    );
  }

  // Waehlt aus allen Vorhersagen die Box mit der hoechsten Konfidenz fuer die
  // gesuchte Klasse, rechnet sie auf das Originalbild um und begrenzt sie auf
  // die Bildgrenzen. Liegt die Konfidenz unter der Schwelle oder ist die Box
  // leer, wird ein Ergebnis ohne Box zurueckgegeben.
  YoloErgebnis _besteBoxFuerKlasse({
    required List<List<List<double>>> ausgabe,
    required int klassenIndex,
    required int originalBreite,
    required int originalHoehe,
    required int inferenzZeitMs,
  }) {
    final konfidenzZeile = 4 + klassenIndex;
    double besteKonfidenz = 0.0;
    int besterIndex = -1;
    for (int i = 0; i < ScanKonstanten.anzahlYoloVorhersagen; i++) {
      final konfidenz = ausgabe[0][konfidenzZeile][i];
      if (konfidenz > besteKonfidenz) {
        besteKonfidenz = konfidenz;
        besterIndex = i;
      }
    }
    if (besterIndex == -1 || besteKonfidenz < ScanKonstanten.mindestKonfidenz) {
      return YoloErgebnis(
        box: null,
        maximaleKonfidenz: besteKonfidenz,
        inferenzZeitMs: inferenzZeitMs,
      );
    }
    final rohCx = ausgabe[0][0][besterIndex];
    final rohCy = ausgabe[0][1][besterIndex];
    final rohW = ausgabe[0][2][besterIndex];
    final rohH = ausgabe[0][3][besterIndex];
    final cx = _boxWertAufOriginal(
      wert: rohCx,
      originalGroesse: originalBreite,
    );
    final cy = _boxWertAufOriginal(wert: rohCy, originalGroesse: originalHoehe);
    final breite = _boxWertAufOriginal(
      wert: rohW,
      originalGroesse: originalBreite,
    );
    final hoehe = _boxWertAufOriginal(
      wert: rohH,
      originalGroesse: originalHoehe,
    );
    final x1 = _begrenzeInt((cx - breite / 2).round(), 0, originalBreite - 1);
    final y1 = _begrenzeInt((cy - hoehe / 2).round(), 0, originalHoehe - 1);
    final x2 = _begrenzeInt((cx + breite / 2).round(), 0, originalBreite);
    final y2 = _begrenzeInt((cy + hoehe / 2).round(), 0, originalHoehe);
    final boxBreite = x2 - x1;
    final boxHoehe = y2 - y1;
    if (boxBreite <= 0 || boxHoehe <= 0) {
      return YoloErgebnis(
        box: null,
        maximaleKonfidenz: besteKonfidenz,
        inferenzZeitMs: inferenzZeitMs,
      );
    }
    return YoloErgebnis(
      box: ErkannteBox(
        x: x1,
        y: y1,
        breite: boxBreite,
        hoehe: boxHoehe,
        konfidenz: besteKonfidenz,
      ),
      maximaleKonfidenz: besteKonfidenz,
      inferenzZeitMs: inferenzZeitMs,
    );
  }

  // YOLO/TFLite-Exporte koennen Boxwerte in zwei Formaten liefern:
  //   1. normalisiert: Werte liegen ungefaehr im Bereich 0..1
  //      (z. B. cx = 0,5 ist die Bildmitte).
  //   2. Modellraum: Werte liegen im 640x640-Eingaberaum
  //      (z. B. cx = 320 ist die Bildmitte im Modellbild).
  // Die Grenze _normalisierteBoxwertGrenze unterscheidet beide Faelle.
  double _boxWertAufOriginal({
    required double wert,
    required int originalGroesse,
  }) {
    if (wert <= _normalisierteBoxwertGrenze) {
      return wert * originalGroesse;
    }
    return (wert / ScanKonstanten.modellGroesse) * originalGroesse;
  }

  // Begrenzt einen Wert auf den Bereich [min, max].
  int _begrenzeInt(int wert, int min, int max) {
    if (wert < min) {
      return min;
    }
    if (wert > max) {
      return max;
    }
    return wert;
  }

  /// Gibt den TFLite-Interpreter frei.
  void schliessen() {
    _interpreter?.close();
    _interpreter = null;
  }
}
