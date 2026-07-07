// Auswahl-Screen fuer die drei Scanmodi der Farbtafel-Methode.
//
// Diese Seite ist nur der Einstieg in den Scanbereich. Die eigentliche
// Analyse liegt in den jeweiligen Scan-Screens und im FarbtafelController.
//
// Modus 1 nutzt die automatische YOLO-Erkennung ohne Punktkorrektur.
// Modus 2 nutzt YOLO und erlaubt die Korrektur einzelner Ringpositionen.
// Modus 3 arbeitet manuell mit selbst gesetzten Tafel- und Ringpunkten.
//
// Modus 2 ist fuer die praktische Nutzung besonders wichtig, weil die
// automatische Erkennung erhalten bleibt und einzelne Ringfehler trotzdem
// korrigiert werden koennen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'scan_farbtafel_auto_screen.dart';
import 'scan_farbtafel_auto_tap_screen.dart';
import 'scan_farbtafel_screen.dart';

/// Auswahlseite fuer die drei Scanvarianten der Farbtafel-Methode.
class ScanAuswahlScreen extends StatelessWidget {
  const ScanAuswahlScreen({super.key});

  // Baut die Auswahlseite mit dem Info-Kasten und den drei Modus-Karten auf.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan-Methode waehlen'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _einleitung(),
              const SizedBox(height: 16),
              _modusAutoKarte(),
              const SizedBox(height: 12),
              _modusAutoTapKarte(),
              const SizedBox(height: 12),
              _modusManuellKarte(),
            ],
          ),
        ),
      ),
    );
  }

  // Info-Kasten am Kopf der Seite.
  Widget _einleitung() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Die App bietet drei Varianten der Farbtafel-Methode mit '
              'ansteigendem Grad an manueller Beteiligung. Damit kann '
              'flexibel auf unterschiedliche Bauformen und Lichtverhaeltnisse '
              'reagiert werden.',
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // Karte fuer Modus 1 (vollautomatisch, ohne Punktkorrektur).
  Widget _modusAutoKarte() {
    return _modusKarte(
      titel: 'Vollautomatisch',
      untertitel: 'Modus 1',
      beschreibung:
          'YOLO erkennt Widerstand und Farbtafel automatisch. Die Ring-'
          'Marker werden geometrisch in der erkannten Box verteilt. '
          'Schnellster Modus, am besten geeignet fuer Standard-Bauformen '
          'mit guter Beleuchtung.',
      icon: Icons.auto_awesome,
      farbe: Colors.green,
      empfohlen: false,
      onTap: () {
        Get.to(() => const ScanFarbtafelAutoScreen());
      },
    );
  }

  // Karte fuer Modus 2 (automatisch mit Tap-Korrektur, empfohlener Hauptmodus).
  Widget _modusAutoTapKarte() {
    return _modusKarte(
      titel: 'Vollautomatisch mit Tap-Korrektur',
      untertitel: 'Modus 2',
      beschreibung:
          'YOLO erkennt Widerstand und Farbtafel automatisch. Falls die '
          'Ring-Marker nicht exakt sitzen, koennen sie ueber die Toolbar '
          '(Ring 1 bis 5) einzeln ausgewaehlt und im Bild auf die richtige '
          'Position getippt werden. Empfohlener Hauptmodus, da er '
          'automatische Geschwindigkeit mit hoher Praezision verbindet.',
      icon: Icons.touch_app,
      farbe: Colors.orange,
      empfohlen: true,
      onTap: () {
        Get.to(() => const ScanFarbtafelAutoTapScreen());
      },
    );
  }

  // Karte fuer Modus 3 (vollmanuell mit selbst gesetzten Punkten).
  Widget _modusManuellKarte() {
    return _modusKarte(
      titel: 'Vollmanuell mit Farbtafel',
      untertitel: 'Modus 3',
      beschreibung:
          'Farbtafel-Ecken und Ringpositionen werden vollstaendig manuell '
          'angetippt. Dieser Modus entspricht am ehesten dem Python-'
          'Testskript und dient als Fallback fuer extreme Bauformen oder '
          'schlechte Lichtverhaeltnisse.',
      icon: Icons.edit_location,
      farbe: Colors.blue,
      empfohlen: false,
      onTap: () {
        Get.to(() => const ScanFarbtafelScreen());
      },
    );
  }

  // Baut eine einzelne Modus-Karte mit Icon, Titel, Untertitel und Beschreibung.
  // Der Parameter empfohlen zeigt bei Modus 2 einen farbigen Rahmen und ein Badge.
  Widget _modusKarte({
    required String titel,
    required String untertitel,
    required String beschreibung,
    required IconData icon,
    required Color farbe,
    required bool empfohlen,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: empfohlen
          ? RoundedRectangleBorder(
              side: BorderSide(color: farbe, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: farbe.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: farbe),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titel,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (empfohlen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: farbe,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'EMPFOHLEN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      untertitel,
                      style: TextStyle(
                        color: farbe,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      beschreibung,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
