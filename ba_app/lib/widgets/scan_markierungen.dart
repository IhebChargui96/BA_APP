// Gemeinsame Anzeige-Widgets fuer die Scan-Screens.
//
// Die Widgets zeichnen Marker und YOLO-Boxen ueber dem angezeigten Foto.
// Dafuer werden Original-Bildkoordinaten mit der uebergebenen Skala in
// Anzeige-Koordinaten umgerechnet.

import 'package:flutter/material.dart';

import '../models/erkannte_box.dart';

// Hoehe des Beschriftungs-Labels oberhalb der YOLO-Box.
const double _labelHoehe = 22.0;

// Marker fuer Farbtafel-Ecken und Ringpositionen.
//
// Standard ist ein duenner farbiger Ring mit transparenter Mitte.
// Dadurch bleibt der Bildpunkt darunter sichtbar, auch wenn das Bild
// im InteractiveViewer stark vergroessert ist und der Marker
// mit-skaliert. Mit gefuellt = true wird stattdessen ein gefuellter
// Punkt mit weissem Rand gezeichnet (Darstellung aus Modus 3).
//
// Die Standard-Groesse 8 px ist fuer die Farbtafel-Ecken gedacht.
// Bei den Widerstands-Ringen wird eine kleinere Groesse uebergeben,
// damit die einzelnen Ringe nicht ueberdeckt werden.
/// Zeichnet einen Marker fuer Tafel-Ecken oder Ringpositionen.
class ScanMarker extends StatelessWidget {
  final List<double> bildPos;
  final double skala;
  final Color farbe;
  final double groesse;
  final bool gefuellt;
  const ScanMarker({
    super.key,
    required this.bildPos,
    required this.skala,
    required this.farbe,
    this.groesse = 8.0,
    this.gefuellt = false,
  });

  // Rechnet die Bildposition in Anzeige-Koordinaten um und zeichnet den Marker.
  @override
  Widget build(BuildContext context) {
    final xAnzeige = bildPos[0] / skala;
    final yAnzeige = bildPos[1] / skala;
    return Positioned(
      left: xAnzeige - groesse / 2,
      top: yAnzeige - groesse / 2,
      child: IgnorePointer(
        child: Container(
          width: groesse,
          height: groesse,
          decoration: BoxDecoration(
            color: gefuellt ? farbe : Colors.transparent,
            shape: BoxShape.circle,
            border: gefuellt
                ? Border.all(color: Colors.white, width: 1.5)
                : Border.all(color: farbe, width: 1.2),
          ),
        ),
      ),
    );
  }
}

// YOLO-Box-Anzeige mit Label oberhalb der Box.
//
// Aufbau:
// - Positioned umrahmt exakt die YOLO-Box (left, top, width, height).
// - Innen ein Stack mit clipBehavior: Clip.none. Dadurch duerfen
//   Kinder ausserhalb der Stack-Grenzen gezeichnet werden.
// - Positioned.fill setzt den Box-Rahmen exakt auf die YOLO-Box.
// - Das Label wird durch top: -_labelHoehe nach oben aus dem
//   Stack hinaus verschoben. Dadurch sitzt es oberhalb des Rahmens
//   und verdeckt weder Farbringe noch Farbfelder.
//
// Vorteil gegenueber einer Column mit Label + Rahmen:
// Die Position des Rahmens ist nicht mehr von der tatsaechlichen
// Hoehe des Labels abhaengig. Wenn die Text-Hoehe in einer anderen
// Schrift-Konfiguration leicht abweicht, bleibt der Rahmen trotzdem
// exakt auf der YOLO-Box.
/// Zeichnet eine YOLO-Box mit Beschriftung oberhalb des Rahmens.
class YoloBoxOverlay extends StatelessWidget {
  final ErkannteBox box;
  final double skala;
  final Color farbe;
  final String beschriftung;
  const YoloBoxOverlay({
    super.key,
    required this.box,
    required this.skala,
    required this.farbe,
    required this.beschriftung,
  });

  // Rechnet die Box in Anzeige-Koordinaten um und zeichnet Rahmen plus Label.
  @override
  Widget build(BuildContext context) {
    final xAnzeige = box.x / skala;
    final yAnzeige = box.y / skala;
    final breiteAnzeige = box.breite / skala;
    final hoeheAnzeige = box.hoehe / skala;
    return Positioned(
      left: xAnzeige,
      top: yAnzeige,
      width: breiteAnzeige,
      height: hoeheAnzeige,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Box-Rahmen: sitzt exakt auf der YOLO-Box.
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: farbe, width: 3),
                ),
              ),
            ),
            // Label: liegt oberhalb der Box und verdeckt den Inhalt nicht.
            Positioned(
              left: 0,
              top: -_labelHoehe,
              child: Container(
                color: farbe,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '$beschriftung ${box.konfidenzText}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
