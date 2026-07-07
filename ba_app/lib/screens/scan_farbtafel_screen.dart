// Screen zum Scannen eines Widerstands mit der Farbtafel-Methode.
//
// Workflow:
// Foto laden -> 4 Tafel-Ecken antippen -> Ringe antippen -> Wert anzeigen ->
// bestaetigen oder korrigieren.
//
// Die eigentliche Bildverarbeitung liegt im FarbtafelController und in
// lib/bildverarbeitung/farbtafel/. Dieser Screen sammelt nur die Eingaben
// des Nutzers und zeigt die Markierungen an.
//
// Fuer genauere Klicks kann das Foto mit zwei Fingern vergroessert werden.
// Waehrend das Bild bewegt oder gezoomt wird, werden Klicks kurz ignoriert,
// damit beim Zoomen kein falscher Punkt gesetzt wird.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
//import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../controllers/farbtafel_controller.dart';
import '../helpers/foto_quelle.dart';
import '../models/scan_ergebnis.dart';
import '../widgets/korrektur_sheet.dart';
import '../widgets/scan_bausteine.dart';
import '../widgets/scan_markierungen.dart';
import 'produkt_form_screen.dart';
import '../helpers/bild_orientierung.dart';

/// Modus 3: manueller Scan mit selbst gesetzten Tafel- und Ringpunkten.
class ScanFarbtafelScreen extends StatefulWidget {
  const ScanFarbtafelScreen({super.key});

  @override
  State<ScanFarbtafelScreen> createState() => _ScanFarbtafelScreenState();
}

class _ScanFarbtafelScreenState extends State<ScanFarbtafelScreen> {
  late final FarbtafelController _controller;
  File? _fotoDatei;
  Uint8List? _fotoBytes;
  int _bildBreite = 0;
  int _bildHoehe = 0;
  // Wird true, sobald das Bild wirklich bewegt oder gezoomt wird.
  // Danach wird ein kurzer Moment kein Marker gesetzt.
  bool _bildWirdBewegt = false;
  // Klicks werden in Original-Bildkoordinaten gespeichert.
  final List<List<double>> _tafelKlicks = [];
  final List<List<double>> _ringKlicks = [];
  int _gesamtRinge = 4;

  // Registriert den FarbtafelController beim Start des Screens.
  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<FarbtafelController>()
        ? Get.find<FarbtafelController>()
        : Get.put(FarbtafelController());
  }

  // Gibt beim Schliessen den FarbtafelController frei.
  @override
  void dispose() {
    if (Get.isRegistered<FarbtafelController>()) {
      Get.delete<FarbtafelController>();
    }
    super.dispose();
  }

  // Foto aufnehmen oder aus der Galerie laden, dekodieren und
  // den Klick-Ablauf von vorn beginnen.
  Future<void> _ladeFoto() async {
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
      _bildWirdBewegt = false;
      _tafelKlicks.clear();
      _ringKlicks.clear();
    });
    _controller.ladeFoto(bild);
  }

  // Ordnet einen Tipp dem aktuellen Schritt zu:
  // erst 4 Tafel-Ecken, danach die Ringpositionen.
  void _verarbeiteTipp(double xBild, double yBild) {
    setState(() {
      if (_tafelKlicks.length < 4) {
        _tafelKlicks.add([xBild, yBild]);
        return;
      }
      if (_ringKlicks.length < _gesamtRinge) {
        _ringKlicks.add([xBild, yBild]);
      }
    });
  }

  // Prueft die Klickdaten und uebergibt sie an den FarbtafelController.
  void _analysiere() {
    if (_fotoDatei == null) {
      Get.snackbar(
        'Hinweis',
        'Bitte zuerst ein Foto laden.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_tafelKlicks.length != 4) {
      Get.snackbar(
        'Hinweis',
        'Bitte zuerst alle 4 Ecken der Farbtafel antippen.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_ringKlicks.length != _gesamtRinge) {
      Get.snackbar(
        'Hinweis',
        'Bitte alle $_gesamtRinge Farbringe antippen.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    _controller.analysiere(
      tafelEcken: _tafelKlicks,
      ringPositionen: _ringKlicks,
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
    // Wert und Toleranz nur uebergeben, wenn die Berechnung gueltig war,
    // sonst koennte ein falscher Wert im Formular landen.
    final scan = ScanErgebnis(
      fotoPfad: fotoDatei.path,
      ringFarben: _controller.erkannteFarben.join(' - '),
      widerstandsWert: iec.istGueltig ? iec.formatierterWert : null,
      toleranz: iec.istGueltig ? iec.toleranz : null,
      hinweis: iec.hinweis,
    );
    // Zum Produkt-Formular wechseln. Der ProduktController kuemmert sich
    // dort um Stueckzahl, Lagerort und das Speichern in der Datenbank.
    Get.to(() => ProduktFormScreen(scanErgebnis: scan));
  }

  // Loescht alle Klicks und das Ergebnis fuer einen neuen Versuch.
  void _zuruecksetzen() {
    setState(() {
      _fotoDatei = null;
      _fotoBytes = null;
      _bildBreite = 0;
      _bildHoehe = 0;
      _bildWirdBewegt = false;
      _tafelKlicks.clear();
      _ringKlicks.clear();
    });
    _controller.aktuellesFoto.value = null;
    _controller.erkannteFarben.clear();
    _controller.ergebnis.value = '';
    _controller.fehler.value = '';
    _controller.laeuft.value = false;
    _controller.letztesIecErgebnis.value = null;
  }

  // Liefert den Hinweistext fuer den aktuellen Klick-Schritt.
  String _anweisung() {
    if (_fotoDatei == null) {
      return 'Lade ein Foto, auf dem Widerstand und Farbtafel zu sehen sind.';
    }
    if (_tafelKlicks.length < 4) {
      final ecken = [
        'links oben',
        'rechts oben',
        'rechts unten',
        'links unten',
      ];
      return 'Tippe Tafel-Ecke ${_tafelKlicks.length + 1} von 4: '
          '${ecken[_tafelKlicks.length]}.\n'
          'Tipp: Mit zwei Fingern reinzoomen, dann mit einem Finger tippen.';
    }
    if (_ringKlicks.length < _gesamtRinge) {
      return 'Tippe Ring ${_ringKlicks.length + 1} von $_gesamtRinge '
          'von links nach rechts.\n'
          'Tipp: Mit zwei Fingern reinzoomen, dann mit einem Finger tippen.';
    }
    return 'Alle Punkte sind erfasst. Jetzt kann analysiert werden.';
  }

  // Analyse ist moeglich, sobald Foto, 4 Tafel-Ecken und alle Ringe gesetzt sind.
  bool get _kannAnalysieren {
    return _fotoDatei != null &&
        _tafelKlicks.length == 4 &&
        _ringKlicks.length == _gesamtRinge;
  }

  // Die Ringanzahl darf nur geaendert werden, solange noch kein Punkt gesetzt
  // ist. Ein spaeterer Wechsel wuerde die bereits gesetzten Klicks unbrauchbar
  // machen, weil die erwartete Ringanzahl dann nicht mehr passt.
  bool get _darfRingAnzahlAendern {
    return _tafelKlicks.isEmpty && _ringKlicks.isEmpty;
  }

  // Baut die Oberflaeche von Modus 3 auf (Anweisung, Foto, Buttons).
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mit Farbtafel scannen'),
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
                onFotoLaden: _ladeFoto,
                onAnalysieren: _kannAnalysieren ? _analysiere : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Anzeigebereich des Fotos mit Zoom und Tipp-Erkennung.
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
                maxScale: 8.0,
                panEnabled: true,
                scaleEnabled: true,
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
                  child: GestureDetector(
                    onTapUp: (details) {
                      if (_bildWirdBewegt) {
                        return;
                      }
                      final xBild = details.localPosition.dx * skala;
                      final yBild = details.localPosition.dy * skala;
                      _verarbeiteTipp(xBild, yBild);
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(_fotoBytes!, fit: BoxFit.fill),
                        ),
                        for (int i = 0; i < _tafelKlicks.length; i++)
                          ScanMarker(
                            bildPos: _tafelKlicks[i],
                            skala: skala,
                            farbe: Colors.yellow,
                            gefuellt: true,
                          ),
                        for (int i = 0; i < _ringKlicks.length; i++)
                          ScanMarker(
                            bildPos: _ringKlicks[i],
                            skala: skala,
                            farbe: Colors.red,
                            groesse: 3.0,
                            gefuellt: true,
                          ),
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
