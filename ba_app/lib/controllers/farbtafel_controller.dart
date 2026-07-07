// Controller fuer die Farbtafel-Methode.
//
// Diese Klasse steuert den Ablauf zwischen Scan-Oberflaeche und
// Bildverarbeitung. Die eigentlichen Rechenschritte liegen in
// lib/bildverarbeitung/farbtafel/.
//
// Ablauf in kurzer Form:
// 1. Foto laden.
// 2. Farbtafel anhand von vier Punkten geometrisch korrigieren.
// 3. 12 Referenzfarben aus der Farbtafel messen.
// 4. Ringfarben an den Ringpositionen messen.
// 5. Farben mit BGR-Regeln und L*a*b*-Vergleich bestimmen.
// 6. Widerstandswert nach dem IEC-Farbcode berechnen.
//
// Je nach Scanmodus kommen die Punkte aus der YOLO-Erkennung,
// aus automatisch gesetzten Ringpositionen oder aus manuellen Eingaben.
// Wenn die automatische Erkennung danebenliegt, koennen die Farben danach
// in der Oberflaeche korrigiert werden.

import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import '../bildverarbeitung/farbtafel/bgr_farbe.dart';
import '../bildverarbeitung/farbtafel/farb_finder.dart';
import '../bildverarbeitung/farbtafel/farbtafel_korrektur.dart';
import '../bildverarbeitung/farbtafel/median_messung.dart';
import '../helpers/widerstands_berechner.dart';

/// Steuert die Farbtafel-Auswertung fuer die Scan-Screens.
///
/// Der Controller speichert das aktuelle Foto, die erkannten Ringfarben,
/// den Ergebnistext und moegliche Fehlermeldungen. Die eigentliche
/// Bildverarbeitung bleibt in den Hilfsdateien der Farbtafel-Methode.
class FarbtafelController extends GetxController {
  final Rxn<img.Image> aktuellesFoto = Rxn<img.Image>();
  final erkannteFarben = <String>[].obs;
  final ergebnis = ''.obs;
  final fehler = ''.obs;
  final laeuft = false.obs;

  // Letztes IEC-Ergebnis. Wird vom Scan-Screen ausgelesen, wenn der
  // die Nutzerin oder der Nutzer den erkannten Wert ins Inventar uebernehmen will.
  final Rxn<IecErgebnis> letztesIecErgebnis = Rxn<IecErgebnis>();

  // Zielgroesse der geometrisch korrigierten Farbtafel.
  // Die Werte stammen aus der Python-Vorarbeit und wurden fuer die
  // Dart-Version uebernommen.
  static const int _tafelBreite = 200;
  static const int _tafelHoehe = 800;

  // Messbereich fuer die Referenzfarben auf der korrigierten Farbtafel.
  static const int _referenzRadiusX = 20;
  static const int _referenzRadiusY = 20;

  // Messbereich fuer Ringfarben bei horizontal liegendem Widerstand.
  // Ringe laufen dann vertikal ueber den Koerper - ROI schmal und hoch.
  // Werte aus der Python-Vorarbeit uebernommen
  // (RING_RADIUS_X = 5, RING_RADIUS_Y = 25).
  static const int _ringRadiusXHorizontal = 5;
  static const int _ringRadiusYHorizontal = 25;

  // Messbereich fuer Ringfarben bei vertikal liegendem Widerstand.
  // Ringe laufen dann horizontal ueber den Koerper - ROI breit und niedrig.
  // Achsen sind gegenueber dem horizontalen Fall vertauscht.
  static const int _ringRadiusXVertikal = 25;
  static const int _ringRadiusYVertikal = 5;

  /// Setzt ein neues Foto und loescht alte Ergebnisse.
  void ladeFoto(img.Image foto) {
    aktuellesFoto.value = foto;
    erkannteFarben.clear();
    ergebnis.value = '';
    fehler.value = '';
    laeuft.value = false;
    letztesIecErgebnis.value = null;
  }

  /// Startet die Analyse mit den Klick- oder YOLO-Daten aus der UI.
  //
  // tafelEcken:
  //   4 Punkte der Farbreferenz im Originalbild.
  //   Reihenfolge: links oben, rechts oben, rechts unten, links unten.
  //
  // ringPositionen:
  //   Mittelpunkt jedes Farbrings im Originalbild.
  //
  // gesamtRinge:
  //   4 oder 5.
  //
  // Grenze dieser Version:
  // Die Analyse laeuft synchron. Fuer die aktuelle Testumgebung war das
  // ausreichend einfach. Bei groesseren Bildern oder laengerer Laufzeit
  // waere ein eigener Isolate sinnvoll, damit die Oberflaeche frei bleibt.
  void analysiere({
    required List<List<double>> tafelEcken,
    required List<List<double>> ringPositionen,
    required int gesamtRinge,
  }) {
    final foto = aktuellesFoto.value;
    if (foto == null) {
      fehler.value = 'Kein Foto geladen.';
      return;
    }
    if (tafelEcken.length != 4) {
      fehler.value = 'Es muessen genau 4 Farbtafel-Ecken gewaehlt werden.';
      return;
    }
    if (gesamtRinge != 4 && gesamtRinge != 5) {
      fehler.value = 'Es werden nur 4 oder 5 Ringe unterstuetzt.';
      return;
    }
    if (ringPositionen.length != gesamtRinge) {
      fehler.value = 'Anzahl der Ringpunkte passt nicht zur Ringanzahl.';
      return;
    }
    laeuft.value = true;
    fehler.value = '';
    ergebnis.value = '';
    erkannteFarben.clear();
    letztesIecErgebnis.value = null;
    try {
      final referenzFarben = _referenzFarbenAusTafelLesen(
        foto: foto,
        tafelEcken: tafelEcken,
      );
      final ringFarben = _ringFarbenLesenUndKlassifizieren(
        foto: foto,
        ringPositionen: ringPositionen,
        gesamtRinge: gesamtRinge,
        referenzFarben: referenzFarben,
      );
      _setzeErgebnisAusFarben(ringFarben);
    } catch (e) {
      fehler.value = e.toString();
    } finally {
      laeuft.value = false;
    }
  }

  /// Uebernimmt manuell korrigierte Farben aus dem Korrektur-Sheet.
  //
  // Es wird nur der Widerstandswert neu berechnet. Die Pixel muessen nicht
  // erneut aus dem Bild gelesen werden.
  void farbenManuellSetzen(List<String> neueFarben) {
    if (neueFarben.length != 4 && neueFarben.length != 5) {
      fehler.value = 'Es werden nur 4 oder 5 Ringe unterstuetzt.';
      return;
    }
    try {
      fehler.value = '';
      _setzeErgebnisAusFarben(neueFarben);
    } catch (e) {
      fehler.value = e.toString();
    }
  }

  // Baut aus einer Farbliste den Ergebnistext fuer die Oberflaeche.
  // Wird von analysiere() und farbenManuellSetzen() genutzt.
  void _setzeErgebnisAusFarben(List<String> farben) {
    erkannteFarben.assignAll(farben);
    final iec = berechneWiderstand(farben);
    letztesIecErgebnis.value = iec;
    final hinweis = iec.hinweis;
    if (hinweis != null && hinweis.trim().isNotEmpty) {
      ergebnis.value =
          'Farben: ${farben.join(' - ')}\n'
          'Hinweis: $hinweis';
    } else {
      ergebnis.value =
          'Farben: ${farben.join(' - ')}\n'
          'Wert: ${iec.formatierterWert} ${iec.toleranz}';
    }
  }

  // Korrigiert die Farbreferenz auf 200 x 800 Pixel und misst danach
  // die 12 Referenzfarben von oben nach unten.
  List<BgrFarbe> _referenzFarbenAusTafelLesen({
    required img.Image foto,
    required List<List<double>> tafelEcken,
  }) {
    // Wie in der Python-Vorarbeit:
    // Die Farbreferenz wird geometrisch korrigiert (200 x 800 Pixel).
    // Danach werden 12 Messbereiche von oben nach unten gelesen.
    final tafel = korrigiereFarbtafel(
      quellBild: foto,
      quellEcken: tafelEcken,
      zielBreite: _tafelBreite,
      zielHoehe: _tafelHoehe,
    );
    final referenzFarben = <BgrFarbe>[];
    final feldHoehe = _tafelHoehe / 12.0;
    // Wie in der Python-Vorarbeit wird nicht die ganze Breite gelesen,
    // sondern ein kleiner Bereich bei etwa einem Viertel der Breite.
    // Dadurch stoeren Text, Linien und Nachbarspalten weniger.
    final mitteX = _tafelBreite ~/ 4;
    for (int i = 0; i < 12; i++) {
      final mitteY = (feldHoehe * i + feldHoehe / 2).round();
      final x1 = _begrenzeInt(mitteX - _referenzRadiusX, 0, tafel.width - 1);
      final y1 = _begrenzeInt(mitteY - _referenzRadiusY, 0, tafel.height - 1);
      final x2 = _begrenzeInt(mitteX + _referenzRadiusX, x1 + 1, tafel.width);
      final y2 = _begrenzeInt(mitteY + _referenzRadiusY, y1 + 1, tafel.height);
      final farbe = medianBgrAusRoi(
        bild: tafel,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
      );
      referenzFarben.add(farbe);
    }
    return referenzFarben;
  }

  // Misst an jeder Ringposition den Median einer kleinen ROI und
  // bestimmt die Farbe mit BGR-Regeln und L*a*b*-Vergleich.
  List<String> _ringFarbenLesenUndKlassifizieren({
    required img.Image foto,
    required List<List<double>> ringPositionen,
    required int gesamtRinge,
    required List<BgrFarbe> referenzFarben,
  }) {
    final farben = <String>[];
    // Lage des Widerstands aus der Verteilung der Ringpunkte ableiten.
    // Wenn der Abstand zwischen erstem und letztem Ring in X groesser
    // ist als in Y, liegt der Widerstand horizontal. Sonst vertikal.
    final horizontalerWiderstand = _istHorizontalerWiderstand(ringPositionen);
    final ringRadiusX = horizontalerWiderstand
        ? _ringRadiusXHorizontal
        : _ringRadiusXVertikal;
    final ringRadiusY = horizontalerWiderstand
        ? _ringRadiusYHorizontal
        : _ringRadiusYVertikal;
    for (int i = 0; i < ringPositionen.length; i++) {
      final cx = ringPositionen[i][0].round();
      final cy = ringPositionen[i][1].round();
      final x1 = _begrenzeInt(cx - ringRadiusX, 0, foto.width - 1);
      final y1 = _begrenzeInt(cy - ringRadiusY, 0, foto.height - 1);
      final x2 = _begrenzeInt(cx + ringRadiusX, x1 + 1, foto.width);
      final y2 = _begrenzeInt(cy + ringRadiusY, y1 + 1, foto.height);
      final pixel = medianBgrAusRoi(bild: foto, x1: x1, y1: y1, x2: x2, y2: y2);
      final farbe = findeFarbe(
        pixel: pixel,
        position: i + 1,
        gesamtRinge: gesamtRinge,
        referenzFarben: referenzFarben,
      );
      farben.add(farbe);
    }
    return farben;
  }

  // Einfache Regel fuer die Widerstandslage:
  // Wenn die Punkte mehr in X auseinanderliegen als in Y, liegt der
  // Widerstand horizontal im Foto. Sonst vertikal. Bei nur einem oder
  // keinem Ringpunkt wird horizontal angenommen.
  //
  // Bekannte Grenze:
  // Bei diagonal liegendem Widerstand sind dx und dy
  // ungefaehr gleich gross. Die ROI passt dann nicht zur Ringrichtung
  // und kann Nachbarringe mitmessen. Dieser Fall wird in der
  // Evaluation (Kapitel 6) als Fehlerfall dokumentiert.
  bool _istHorizontalerWiderstand(List<List<double>> ringPositionen) {
    if (ringPositionen.length < 2) {
      return true;
    }
    final erster = ringPositionen.first;
    final letzter = ringPositionen.last;
    final dx = (letzter[0] - erster[0]).abs();
    final dy = (letzter[1] - erster[1]).abs();
    return dx >= dy;
  }

  // Begrenzt einen Wert auf den erlaubten Bildbereich.
  int _begrenzeInt(int wert, int min, int max) {
    if (wert < min) {
      return min;
    }
    if (wert > max) {
      return max;
    }
    return wert;
  }
}
