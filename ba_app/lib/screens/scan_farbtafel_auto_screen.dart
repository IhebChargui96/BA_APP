// Screen fuer Modus 1: YOLO erkennt Widerstand UND Farbtafel automatisch.
//
// Workflow:
// Foto laden -> YOLO findet Widerstand + Farbreferenz ->
// Widerstand-Box um 8 % erweitern, damit aeussere Farbringe nicht
// abgeschnitten werden ->
// Tafel-Ecken aus Farbreferenz-Box ableiten ->
// Ringpositionen aus erweiterter Widerstand-Box ableiten ->
// Analyse -> Wert anzeigen -> bestaetigen oder korrigieren.
//
// Hinweis:
// Die Tafel-Ecken werden hier aus einer axis-aligned Bounding-Box
// abgeleitet. Wenn die Tafel im Foto stark verdreht oder perspektivisch
// verzerrt ist, kann das ungenau sein. Fuer diesen Fall ist Modus 2
// oder Modus 3 vorgesehen.
//
// Es gibt keine Klick-Eingabe in Modus 1. Der Zoom dient nur zur
// Sichtkontrolle der Markierungen, damit der Nutzer pruefen kann,
// ob die Punkte richtig liegen.
//
// Modus 1 setzt ein YOLO-Modell mit 2 Klassen voraus:
// 0 = farbreferenz, 1 = widerstand. Bei einem 1-Klassen-Modell wird
// eine Fehlermeldung angezeigt.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../bildverarbeitung/farbtafel/ring_geometrie.dart';
import '../controllers/farbtafel_controller.dart';
import '../helpers/foto_quelle.dart';
import '../models/erkannte_box.dart';
import '../models/scan_ergebnis.dart';
import '../services/yolo_tflite_service.dart';
import '../widgets/korrektur_sheet.dart';
import '../widgets/scan_bausteine.dart';
import '../widgets/scan_markierungen.dart';
import 'produkt_form_screen.dart';
import '../helpers/bild_orientierung.dart';

// 8 % Zusatzbereich fuer die YOLO-Widerstand-Box.
//
// YOLO liefert nur die Box des Widerstandskoerpers. Aeussere Farbringe
// koennen dadurch knapp am Rand der Box liegen. Der Zusatzbereich wurde
// aus den eigenen Testbildern der App abgeleitet und haelt mehr Rand
// fuer die anschliessende Ringmessung frei.
const double _widerstandBoxPadding = 0.08;

// Ring-Anteile fuer Modus 1.
//
// Die Punkte werden nicht ueber die ganze Box verteilt. Die Messung startet
// erst nach einem kleinen Rand und endet vor dem rechten Rand der erweiterten
// Box. Diese Startnaeherung wurde an den eigenen Testbildern geprueft.
// Schwierige Aufnahmen koennen danach in Modus 2 oder 3 korrigiert werden.
const double _ringStartAnteilModus1 = 0.15;
const double _ringEndAnteilModus1 = 0.75;

/// Modus 1: automatische YOLO-Erkennung ohne manuelle Punktkorrektur.
class ScanFarbtafelAutoScreen extends StatefulWidget {
  const ScanFarbtafelAutoScreen({super.key});

  @override
  State<ScanFarbtafelAutoScreen> createState() =>
      _ScanFarbtafelAutoScreenState();
}

class _ScanFarbtafelAutoScreenState extends State<ScanFarbtafelAutoScreen> {
  late final FarbtafelController _controller;
  late final YoloTfliteService _yolo;
  File? _fotoDatei;
  Uint8List? _fotoBytes;
  int _bildBreite = 0;
  int _bildHoehe = 0;
  ErkannteBox? _widerstandBox;
  ErkannteBox? _farbreferenzBox;
  bool _yoloLaeuft = false;
  String? _yoloFehler;
  int _gesamtRinge = 4;

  // Tafel-Ecken aus der Farbreferenz-Box ableiten.
  // Reihenfolge wie in Modus 2 und 3:
  // links oben, rechts oben, rechts unten, links unten.
  List<List<double>> get _tafelEcken {
    if (_farbreferenzBox == null) {
      return const [];
    }
    final box = _farbreferenzBox!;
    final x1 = box.x.toDouble();
    final y1 = box.y.toDouble();
    final x2 = (box.x + box.breite).toDouble();
    final y2 = (box.y + box.hoehe).toDouble();
    return [
      [x1, y1],
      [x2, y1],
      [x2, y2],
      [x1, y2],
    ];
  }

  // Ringpositionen aus der erweiterten Widerstand-Box berechnen.
  //
  // Die Ringe werden in einem festen Anteils-Bereich (15 - 75 %)
  // der Box gleichmaessig verteilt. Die Werte beruecksichtigen das
  // 8 %-Padding und die typische Anordnung der Ringe bei realen
  // Widerstaenden (Wertringe links, Toleranzring rechts mit
  // groesserem Abstand).
  List<List<double>> get _ringPositionen {
    if (_widerstandBox == null) {
      return const [];
    }
    return verteileRingeInBox(
      box: _widerstandBox!,
      gesamtRinge: _gesamtRinge,
      startAnteil: _ringStartAnteilModus1,
      endAnteil: _ringEndAnteilModus1,
    );
  }

  // Registriert den FarbtafelController und den YOLO-Service beim Start.
  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<FarbtafelController>()
        ? Get.find<FarbtafelController>()
        : Get.put(FarbtafelController());
    _yolo = Get.isRegistered<YoloTfliteService>()
        ? Get.find<YoloTfliteService>()
        : Get.put(YoloTfliteService());
  }

  // Gibt beim Schliessen den FarbtafelController frei.
  @override
  void dispose() {
    if (Get.isRegistered<FarbtafelController>()) {
      Get.delete<FarbtafelController>();
    }
    // YoloTfliteService wird nicht geloescht.
    // Das Modell kann appweit wiederverwendet werden.
    super.dispose();
  }

  // Foto aufnehmen oder aus der Galerie laden, dekodieren,
  // alten Zustand verwerfen und die YOLO-Erkennung starten.
  Future<void> _ladeFoto() async {
    if (_yoloLaeuft) {
      return;
    }
    final quelle = await waehleFotoQuelle(context);
    if (quelle == null) {
      return;
    }
    final picker = ImagePicker();
    final ausgewaehlt = await picker.pickImage(source: quelle);
    if (ausgewaehlt == null) {
      return;
    }
    final bytes = await ausgewaehlt.readAsBytes();
    // Bild mit EXIF-Orientierung lesen, damit Anzeige und Klickpunkte
    // zum tatsaechlich angezeigten Foto passen.
    final bild = dekodiereMitOrientierung(bytes);
    if (!mounted) {
      return;
    }
    if (bild == null) {
      Get.snackbar(
        'Fehler',
        'Bild konnte nicht gelesen werden.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    setState(() {
      _fotoDatei = File(ausgewaehlt.path);
      _fotoBytes = bytes;
      _bildBreite = bild.width;
      _bildHoehe = bild.height;
      _widerstandBox = null;
      _farbreferenzBox = null;
      _yoloFehler = null;
    });
    _controller.ladeFoto(bild);
    await _starteYolo(bild);
  }

  // Laesst YOLO Widerstand und Farbreferenz suchen.
  // Modus 1 braucht das 2-Klassen-Modell. Ohne Treffer wird eine
  // Meldung mit der maximalen Konfidenz angezeigt.
  Future<void> _starteYolo(img.Image bild) async {
    setState(() {
      _yoloLaeuft = true;
      _yoloFehler = null;
    });
    try {
      if (!_yolo.istGeladen) {
        await _yolo.modellLaden();
      }
      // Modus 1 braucht ein YOLO-Modell mit 2 Klassen.
      if (_yolo.anzahlKlassen < 2) {
        setState(() {
          _yoloFehler =
              'Modus 1 benoetigt ein YOLO-Modell mit 2 Klassen '
              '(widerstand und farbreferenz). Aktuell sind nur '
              '${_yolo.anzahlKlassen} Klassen geladen.\n'
              'Bitte Modus 3 verwenden - Modus 2 benoetigt\n'
              'das gleiche Modell.';
        });
        return;
      }
      final widerstandErgebnis = await _yolo.widerstandErkennen(bild);
      final farbreferenzErgebnis = await _yolo.farbreferenzErkennen(bild);
      if (!mounted) {
        return;
      }
      if (widerstandErgebnis.box == null) {
        setState(() {
          final prozent = (widerstandErgebnis.maximaleKonfidenz * 100)
              .toStringAsFixed(1);
          _yoloFehler =
              'Kein Widerstand erkannt '
              '(max. Konfidenz: $prozent %).';
        });
        return;
      }
      if (farbreferenzErgebnis.box == null) {
        setState(() {
          final prozent = (farbreferenzErgebnis.maximaleKonfidenz * 100)
              .toStringAsFixed(1);
          _yoloFehler =
              'Keine Farbtafel erkannt '
              '(max. Konfidenz: $prozent %).';
        });
        return;
      }
      // YOLO-Widerstand-Box vor dem Setzen um 8 % erweitern.
      //
      // Die Farbreferenz-Box bleibt unveraendert.
      // Die eigentlichen Farbfelder werden im FarbtafelController
      // gezielt in der linken Farbfeld-Spalte gemessen. Deshalb ist
      // hier kein Padding fuer die Farbreferenz-Box noetig.
      final erweiterteWiderstandBox = _erweitereBox(
        widerstandErgebnis.box!,
        bild.width,
        bild.height,
      );
      setState(() {
        _widerstandBox = erweiterteWiderstandBox;
        _farbreferenzBox = farbreferenzErgebnis.box;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _yoloFehler = 'YOLO-Fehler: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _yoloLaeuft = false;
        });
      }
    }
  }

  // Erweitert eine YOLO-Box um den Padding-Faktor in beide Dimensionen.
  //
  // Die neue Box wird auf die Bildgrenzen begrenzt, damit sie nicht
  // ausserhalb des Fotos endet. Liegt die ursprueengliche Box am
  // Bildrand, wird das Padding an dieser Seite gekuerzt.
  //
  // yoloBox:
  //   Die von YOLO gelieferte Bounding-Box im Originalbild.
  //
  // bildBreite, bildHoehe:
  //   Groesse des Originalbildes in Pixeln.
  ErkannteBox _erweitereBox(
    ErkannteBox yoloBox,
    int bildBreite,
    int bildHoehe,
  ) {
    final paddingX = (yoloBox.breite * _widerstandBoxPadding).round();
    final paddingY = (yoloBox.hoehe * _widerstandBoxPadding).round();
    int neueX = yoloBox.x - paddingX;
    int neueY = yoloBox.y - paddingY;
    int neueBreite = yoloBox.breite + 2 * paddingX;
    int neueHoehe = yoloBox.hoehe + 2 * paddingY;
    // Linke und obere Kante an die Bildgrenze klemmen. Verschwundene
    // Pixel werden auch von der Box-Groesse abgezogen, sodass die
    // rechte und untere Kante an der richtigen Stelle bleibt.
    if (neueX < 0) {
      neueBreite = neueBreite + neueX;
      neueX = 0;
    }
    if (neueY < 0) {
      neueHoehe = neueHoehe + neueY;
      neueY = 0;
    }
    // Rechte und untere Kante an die Bildgrenze klemmen.
    if (neueX + neueBreite > bildBreite) {
      neueBreite = bildBreite - neueX;
    }
    if (neueY + neueHoehe > bildHoehe) {
      neueHoehe = bildHoehe - neueY;
    }
    return ErkannteBox(
      x: neueX,
      y: neueY,
      breite: neueBreite,
      hoehe: neueHoehe,
      konfidenz: yoloBox.konfidenz,
    );
  }

  // Uebergibt Tafel-Ecken und Ringpositionen an den FarbtafelController.
  // Die eigentliche Bildverarbeitung laeuft dort.
  void _analysiere() {
    if (_widerstandBox == null || _farbreferenzBox == null) {
      Get.snackbar(
        'Hinweis',
        'YOLO hat noch keine vollstaendigen Ergebnisse geliefert.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    _controller.analysiere(
      tafelEcken: _tafelEcken,
      ringPositionen: _ringPositionen,
      gesamtRinge: _gesamtRinge,
    );
  }

  // Oeffnet das Korrektur-Sheet und rechnet mit geaenderten Farben neu.
  Future<void> _zeigeKorrektur() async {
    final aktuelleFarben = List<String>.from(_controller.erkannteFarben);
    if (aktuelleFarben.isEmpty) {
      Get.snackbar(
        'Hinweis',
        'Es gibt noch keine erkannten Farben.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final korrigiert = await zeigeKorrekturSheet(
      context: context,
      aktuelleFarben: aktuelleFarben,
      gesamtRinge: _gesamtRinge,
    );
    if (korrigiert != null) {
      _controller.farbenManuellSetzen(korrigiert);
    }
  }

  // Uebernimmt das Ergebnis: Foto speichern, ScanErgebnis bauen und
  // das vorausgefuellte Produktformular oeffnen.
  void _bestaetige() {
    final iec = _controller.letztesIecErgebnis.value;
    final fotoDatei = _fotoDatei;
    if (iec == null || fotoDatei == null) {
      Get.snackbar(
        'Hinweis',
        'Es liegt noch kein vollstaendiges Ergebnis vor.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    // Scan-Ergebnis fuer das Produkt-Formular zusammenstellen.
    // Wert und Toleranz nur uebergeben, wenn die Berechnung gueltig war.
    final scan = ScanErgebnis(
      fotoPfad: fotoDatei.path,
      ringFarben: _controller.erkannteFarben.join(' - '),
      widerstandsWert: iec.istGueltig ? iec.formatierterWert : null,
      toleranz: iec.istGueltig ? iec.toleranz : null,
      hinweis: iec.hinweis,
    );
    Get.to(() => ProduktFormScreen(scanErgebnis: scan));
  }

  // Loescht Boxen, Marker und Ergebnis fuer einen neuen Versuch.
  void _zuruecksetzen() {
    setState(() {
      _fotoDatei = null;
      _fotoBytes = null;
      _bildBreite = 0;
      _bildHoehe = 0;
      _widerstandBox = null;
      _farbreferenzBox = null;
      _yoloFehler = null;
      _yoloLaeuft = false;
    });
    _controller.aktuellesFoto.value = null;
    _controller.erkannteFarben.clear();
    _controller.ergebnis.value = '';
    _controller.fehler.value = '';
    _controller.laeuft.value = false;
    _controller.letztesIecErgebnis.value = null;
  }

  // Liefert den Hinweistext fuer den aktuellen Schritt.
  String _anweisung() {
    if (_fotoDatei == null) {
      return 'Lade ein Foto, auf dem Widerstand und Farbtafel zu sehen sind. '
          'YOLO sucht beides automatisch.';
    }
    if (_yoloLaeuft) {
      return 'Widerstand und Farbtafel werden mit YOLO gesucht ...';
    }
    if (_yoloFehler != null) {
      return _yoloFehler!;
    }
    if (_widerstandBox == null || _farbreferenzBox == null) {
      return 'Noch keine vollstaendige YOLO-Erkennung.';
    }
    return 'Beide Objekte sind erkannt. Jetzt kann analysiert werden.\n'
        'Tipp: Mit zwei Fingern reinzoomen und pruefen ob die Punkte '
        'richtig liegen.';
  }

  // Analyse ist moeglich, sobald Foto, Widerstand-Box und Farbtafel-Box vorliegen.
  bool get _kannAnalysieren {
    return _fotoDatei != null &&
        _widerstandBox != null &&
        _farbreferenzBox != null;
  }

  // Im Modus 1 kann die Ringanzahl auch nach der YOLO-Erkennung
  // noch geaendert werden, weil der Nutzer keine Ringe einzeln klickt.
  // Waehrend YOLO laeuft, wird das Toggle gesperrt.
  bool get _darfRingAnzahlAendern {
    return !_yoloLaeuft;
  }

  // Baut die Oberflaeche von Modus 1 auf (Anweisung, Foto, Buttons).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vollautomatisch mit YOLO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Zuruecksetzen',
            onPressed: _zuruecksetzen,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                _anweisung(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              RingAuswahl(
                gesamtRinge: _gesamtRinge,
                darfAendern: _darfRingAnzahlAendern,
                onChanged: (anzahl) {
                  setState(() {
                    _gesamtRinge = anzahl;
                  });
                },
              ),
              const SizedBox(height: 8),
              Expanded(child: _fotoBereich()),
              const SizedBox(height: 8),
              ScanErgebnisBereich(
                controller: _controller,
                onKorrektur: _zeigeKorrektur,
                onBestaetigen: _bestaetige,
              ),
              const SizedBox(height: 8),
              ScanButtonBereich(
                onFotoLaden: _yoloLaeuft ? null : _ladeFoto,
                onAnalysieren: _kannAnalysieren ? _analysiere : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Anzeigebereich des Fotos mit Zoom (InteractiveViewer) und den
  // Overlays fuer YOLO-Boxen und geschaetzte Ring-Marker.
  Widget _fotoBereich() {
    if (_fotoDatei == null || _fotoBytes == null || _bildBreite == 0) {
      return const Center(
        child: Text(
          'Noch kein Foto geladen',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = _bildBreite / _bildHoehe;
        double anzeigeBreite;
        double anzeigeHoehe;
        if (constraints.maxWidth / aspect <= constraints.maxHeight) {
          anzeigeBreite = constraints.maxWidth;
          anzeigeHoehe = constraints.maxWidth / aspect;
        } else {
          anzeigeHoehe = constraints.maxHeight;
          anzeigeBreite = constraints.maxHeight * aspect;
        }
        final skala = _bildBreite / anzeigeBreite;
        return Center(
          child: SizedBox(
            width: anzeigeBreite,
            height: anzeigeHoehe,
            child: ClipRect(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 12.0,
                panEnabled: true,
                scaleEnabled: true,
                child: SizedBox(
                  width: anzeigeBreite,
                  height: anzeigeHoehe,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(_fotoBytes!, fit: BoxFit.fill),
                      ),
                      if (_widerstandBox != null)
                        YoloBoxOverlay(
                          box: _widerstandBox!,
                          skala: skala,
                          farbe: Colors.green,
                          beschriftung: 'Widerstand',
                        ),
                      if (_farbreferenzBox != null)
                        YoloBoxOverlay(
                          box: _farbreferenzBox!,
                          skala: skala,
                          farbe: Colors.purple,
                          beschriftung: 'Farbtafel',
                        ),
                      for (int i = 0; i < _tafelEcken.length; i++)
                        ScanMarker(
                          bildPos: _tafelEcken[i],
                          skala: skala,
                          farbe: Colors.yellow,
                        ),
                      for (int i = 0; i < _ringPositionen.length; i++)
                        ScanMarker(
                          bildPos: _ringPositionen[i],
                          skala: skala,
                          farbe: Colors.red,
                          groesse: 4.0,
                        ),
                      if (_yoloLaeuft)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
