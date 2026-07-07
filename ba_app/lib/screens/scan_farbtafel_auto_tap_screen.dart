// Screen fuer Modus 2: YOLO erkennt Widerstand UND Farbtafel automatisch,
// Ring-Marker koennen durch Tap-Korrektur einzeln nachgesetzt werden.
//
// Workflow:
// Foto laden -> YOLO findet Widerstand + Farbreferenz ->
// Widerstand-Box um 8 % erweitern, damit aeussere Farbringe nicht
// abgeschnitten werden ->
// Tafel-Ecken aus Farbreferenz-Box ableiten ->
// Ringpositionen aus erweiterter Widerstand-Box ableiten ->
// Falls noetig: Nutzer tippt in der Toolbar auf einen Ring und tippt
// im Bild auf die korrekte Position, der Marker springt dorthin ->
// Analyse -> Wert anzeigen -> bestaetigen oder korrigieren.
//
// Unterschied zu Modus 1:
// Modus 1 ist vollautomatisch ohne Eingriff. Modus 2 erlaubt nach der
// automatischen Erkennung eine ringweise Tap-Korrektur. Dadurch koennen
// Marker-Position-Fehler korrigiert werden, ohne die Vorteile der
// automatischen Tafel-Erkennung zu verlieren.
//
// Tap-Mechanik:
// Der Nutzer tippt zuerst in der Toolbar auf den zu korrigierenden Ring
// (Ring 1 bis 5), anschliessend im Bild auf die richtige Position. Diese
// Trennung zwischen Auswahl und Positionierung vermeidet Fehlbedienungen
// und Konflikte mit der Zoom-Funktion des InteractiveViewer.
//
// Hinweis:
// Modus 2 setzt ein YOLO-Modell mit 2 Klassen voraus
// (0 = farbreferenz, 1 = widerstand). Bei einem 1-Klassen-Modell wird
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

// Ring-Anteile fuer Modus 2.
//
// Identisch zu Modus 1, da die Ausgangslage gleich ist:
// Die YOLO-Widerstand-Box wird um 8 % erweitert (siehe
// _widerstandBoxPadding). Die Ringe werden im Bereich 15 % - 75 %
// der erweiterten Box gleichmaessig verteilt. Bei realen Widerstaenden
// kompensiert dieser Bereich das Padding und die typische Ring-
// Anordnung (Wertringe links, Toleranzring rechts mit groesserem
// Abstand). Wenn die geometrische Verteilung daneben liegt, kann der
// Nutzer ueber die Tap-Korrektur einzelne Marker nachsetzen.
const double _ringStartAnteilModus2 = 0.15;
const double _ringEndAnteilModus2 = 0.75;

/// Modus 2: YOLO-Erkennung mit Korrektur einzelner Ringpositionen.
class ScanFarbtafelAutoTapScreen extends StatefulWidget {
  const ScanFarbtafelAutoTapScreen({super.key});

  @override
  State<ScanFarbtafelAutoTapScreen> createState() =>
      _ScanFarbtafelAutoTapScreenState();
}

class _ScanFarbtafelAutoTapScreenState
    extends State<ScanFarbtafelAutoTapScreen> {
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

  // Tap-Korrektur-Zustand.
  //
  // _bildWirdBewegt:
  //   Wird true sobald das Bild mit zwei Fingern bewegt oder gezoomt
  //   wird. Verhindert dass ein Pan-Ende als Tap interpretiert wird.
  //   Wird 150 ms nach Interaktions-Ende zurueckgesetzt.
  //
  // _aktiverRingIndex:
  //   null wenn keine Korrektur aktiv ist, sonst Index 0 bis
  //   gesamtRinge-1. Wird durch Druck auf einen Ring-Button in der
  //   Toolbar gesetzt.
  //
  // _manuelleRingPositionen:
  //   Liste der korrigierten Ring-Positionen. Bleibt null bis der
  //   erste Tap ausgefuehrt wird, dann wird sie mit den geometrischen
  //   Standard-Positionen initialisiert und anschliessend gezielt
  //   ueberschrieben.
  bool _bildWirdBewegt = false;
  int? _aktiverRingIndex;
  List<List<double>>? _manuelleRingPositionen;

  // Tafel-Ecken aus der Farbreferenz-Box ableiten.
  // Reihenfolge wie in Modus 1 und 3:
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

  // Geometrische Standard-Ringpositionen aus der erweiterten
  // Widerstand-Box. Werden verwendet, solange keine Tap-Korrektur
  // erfolgt ist. Identisch zur Logik in Modus 1.
  List<List<double>> get _geometrischeRingPositionen {
    if (_widerstandBox == null) {
      return const [];
    }
    return verteileRingeInBox(
      box: _widerstandBox!,
      gesamtRinge: _gesamtRinge,
      startAnteil: _ringStartAnteilModus2,
      endAnteil: _ringEndAnteilModus2,
    );
  }

  // Aktive Ringpositionen.
  // Liefert die manuell gesetzten Positionen, falls vorhanden,
  // andernfalls die geometrischen Standard-Positionen.
  List<List<double>> get _ringPositionen {
    if (_manuelleRingPositionen != null) {
      return _manuelleRingPositionen!;
    }
    return _geometrischeRingPositionen;
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
      _bildWirdBewegt = false;
      _setzeManuellePositionenZurueck();
    });
    _controller.ladeFoto(bild);
    await _starteYolo(bild);
  }

  // Laesst YOLO Widerstand und Farbreferenz suchen.
  // Modus 2 braucht das 2-Klassen-Modell. Ohne Treffer wird eine
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
      // Modus 2 braucht ein YOLO-Modell mit 2 Klassen.
      if (_yolo.anzahlKlassen < 2) {
        setState(() {
          _yoloFehler =
              'Modus 2 benoetigt ein YOLO-Modell mit 2 Klassen '
              '(widerstand und farbreferenz). Aktuell sind nur '
              '${_yolo.anzahlKlassen} Klassen geladen.\n'
              'Bitte Modus 3 verwenden.';
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

  // Verarbeitet einen Tap im Bild zur Ring-Korrektur.
  //
  // Wird nur ausgefuehrt, wenn ein Ring-Index aktiv ist (Toolbar-
  // Button gedrueckt) und das Bild nicht gerade bewegt oder gezoomt
  // wird. Die uebergebenen Koordinaten sind bereits in Original-
  // Bildkoordinaten umgerechnet.
  void _verarbeiteRingTipp(double xBild, double yBild) {
    if (_aktiverRingIndex == null) {
      return;
    }
    if (_widerstandBox == null) {
      return;
    }
    final index = _aktiverRingIndex!;
    if (index < 0 || index >= _gesamtRinge) {
      return;
    }
    setState(() {
      // Beim ersten Tap werden die manuellen Positionen mit den
      // geometrischen Standard-Werten initialisiert. So bleiben die
      // anderen Marker an der geschaetzten Position, waehrend nur
      // der ausgewaehlte Ring neu gesetzt wird.
      _manuelleRingPositionen ??= List<List<double>>.from(
        _geometrischeRingPositionen.map((p) => List<double>.from(p)),
      );
      _manuelleRingPositionen![index] = [xBild, yBild];
    });
  }

  // Setzt alle manuellen Ring-Positionen zurueck.
  // Wird aufgerufen wenn die Ring-Anzahl geaendert wird oder ein
  // neues Foto geladen wird, damit nicht Reste aus einem alten
  // Korrektur-Vorgang sichtbar bleiben.
  void _setzeManuellePositionenZurueck() {
    _manuelleRingPositionen = null;
    _aktiverRingIndex = null;
  }

  // Uebergibt Tafel-Ecken und Ringpositionen an den FarbtafelController.
  // Manuell korrigierte Marker haben Vorrang vor den geschaetzten.
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
      _bildWirdBewegt = false;
      _setzeManuellePositionenZurueck();
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
    // Aktiver Korrektur-Modus: explizite Anweisung was zu tun ist.
    if (_aktiverRingIndex != null) {
      final ringNr = _aktiverRingIndex! + 1;
      return 'Tippe im Bild auf den richtigen Ring $ringNr.\n'
          'Tipp: Mit zwei Fingern reinzoomen fuer mehr Genauigkeit.';
    }
    return 'Beide Objekte sind erkannt. Falls ein Ring-Marker daneben '
        'liegt, oben "Ring 1" bis "Ring $_gesamtRinge" antippen und im '
        'Bild auf die richtige Stelle tippen. Sonst direkt analysieren.';
  }

  // Analyse ist moeglich, sobald Foto, Widerstand-Box und Farbtafel-Box vorliegen.
  bool get _kannAnalysieren {
    return _fotoDatei != null &&
        _widerstandBox != null &&
        _farbreferenzBox != null;
  }

  // Im Modus 2 kann die Ringanzahl auch nach der YOLO-Erkennung
  // noch geaendert werden, weil der Nutzer keine Ringe einzeln klickt.
  // Waehrend YOLO laeuft, wird das Toggle gesperrt.
  bool get _darfRingAnzahlAendern {
    return !_yoloLaeuft;
  }

  // Baut die Oberflaeche von Modus 2 auf (Anweisung, Korrektur-Toolbar, Foto).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vollautomatisch mit Tap-Korrektur'),
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
                    // Bei Wechsel der Ring-Anzahl die manuellen Positionen
                    // verwerfen, damit nicht 5 Marker in einem 4-Ring-System
                    // sichtbar bleiben (oder umgekehrt).
                    _setzeManuellePositionenZurueck();
                  });
                },
              ),
              const SizedBox(height: 4),
              _ringKorrekturToolbar(),
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

  // Toolbar zur ringweisen Tap-Korrektur.
  //
  // Wird erst sichtbar, wenn YOLO erfolgreich erkannt hat (Widerstand-
  // Box vorhanden) und keine Analyse laeuft. Vorher gibt es nichts
  // zu korrigieren.
  //
  // Der Nutzer tippt einen Ring-Button (1 bis gesamtRinge) und tippt
  // anschliessend im Bild auf die richtige Position. Der aktive Button
  // ist farbig hervorgehoben. Ueber den X-Button kann der Korrektur-
  // Modus wieder verlassen werden.
  Widget _ringKorrekturToolbar() {
    if (_widerstandBox == null || _yoloLaeuft) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Ring korrigieren: ', style: TextStyle(fontSize: 13)),
        for (int i = 0; i < _gesamtRinge; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _ringButton(i),
          ),
        if (_aktiverRingIndex != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Korrektur deaktivieren',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _aktiverRingIndex = null;
              });
            },
          ),
      ],
    );
  }

  // Einzelner Ring-Button in der Toolbar.
  // Klick aktiviert den Ring fuer die naechste Tap-Korrektur.
  // Erneuter Klick auf denselben Button deaktiviert die Korrektur.
  Widget _ringButton(int index) {
    final aktiv = _aktiverRingIndex == index;
    final label = '${index + 1}';
    return SizedBox(
      width: 36,
      height: 32,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: aktiv ? Colors.orange : Colors.grey.shade300,
          foregroundColor: aktiv ? Colors.white : Colors.black87,
        ),
        onPressed: () {
          setState(() {
            _aktiverRingIndex = aktiv ? null : index;
          });
        },
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  // Anzeigebereich des Fotos mit Zoom und Tap-Korrektur.
  // Der GestureDetector liegt im Kind des InteractiveViewers - dadurch
  // kommen Tap-Koordinaten automatisch unskaliert an und es reicht
  // eine einzige Umrechnung Bild zu Anzeige.
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
                // Erkennt Zoom- und Pan-Gesten. Solange das Bild
                // bewegt wird, werden Taps ignoriert, damit nach
                // einem Pan kein versehentlicher Marker gesetzt wird.
                // 150 ms Nachlauf hat sich in Modus 3 bewaehrt.
                onInteractionUpdate: (_) {
                  _bildWirdBewegt = true;
                },
                onInteractionEnd: (_) {
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) {
                      _bildWirdBewegt = false;
                    }
                  });
                },
                child: SizedBox(
                  width: anzeigeBreite,
                  height: anzeigeHoehe,
                  // GestureDetector reagiert auf Single-Taps.
                  // Der Handler prueft selbst, ob ein Ring aktiv ist
                  // und ob das Bild gerade bewegt wird. Pinch/Pan
                  // gehen direkt an den InteractiveViewer.
                  child: GestureDetector(
                    onTapUp: (details) {
                      if (_bildWirdBewegt) {
                        return;
                      }
                      if (_aktiverRingIndex == null) {
                        return;
                      }
                      final xBild = details.localPosition.dx * skala;
                      final yBild = details.localPosition.dy * skala;
                      _verarbeiteRingTipp(xBild, yBild);
                    },
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
                        // Ring-Marker. Der aktive Ring wird etwas
                        // groesser und in Orange dargestellt, damit
                        // klar ist, welcher Marker als naechstes
                        // verschoben wird.
                        for (int i = 0; i < _ringPositionen.length; i++)
                          ScanMarker(
                            bildPos: _ringPositionen[i],
                            skala: skala,
                            farbe: _aktiverRingIndex == i
                                ? Colors.orange
                                : Colors.red,
                            groesse: _aktiverRingIndex == i ? 7.0 : 4.0,
                          ),
                        if (_yoloLaeuft)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
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
