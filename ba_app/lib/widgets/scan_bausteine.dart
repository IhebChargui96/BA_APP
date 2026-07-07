// Gemeinsame UI-Bausteine fuer die Scan-Screens.
//
// Die drei Scanmodi verwenden dieselben Grundelemente: Ringauswahl,
// Ergebnisbereich und die Button-Reihe fuer Foto und Analyse. Unterschiede
// zwischen den Modi werden ueber Parameter und Callbacks gesteuert.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/farbtafel_controller.dart';

// Umschalter zwischen 4 und 5 Ringen.
//
// Solange darfAendern false ist (z. B. waehrend einer laufenden
// Analyse oder nach der Auswahl), wird nur der aktuelle Wert als
// Text angezeigt. onChanged liefert die neue Ringanzahl (4 oder 5).
// Der aufrufende Screen kuemmert sich selbst um setState und
// eventuelle Aufraeumarbeiten.
/// Umschalter zwischen 4- und 5-Ring-Auswertung.
class RingAuswahl extends StatelessWidget {
  final int gesamtRinge;
  final bool darfAendern;
  final ValueChanged<int> onChanged;
  const RingAuswahl({
    super.key,
    required this.gesamtRinge,
    required this.darfAendern,
    required this.onChanged,
  });

  // Zeigt den 4/5-Umschalter, oder - falls gesperrt - nur den aktuellen Wert.
  @override
  Widget build(BuildContext context) {
    if (!darfAendern) {
      return Text(
        'Ringanzahl: $gesamtRinge',
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      );
    }
    return ToggleButtons(
      isSelected: [gesamtRinge == 4, gesamtRinge == 5],
      onPressed: (index) => onChanged(index == 0 ? 4 : 5),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('4 Ringe'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('5 Ringe'),
        ),
      ],
    );
  }
}

// Ergebnisbereich unterhalb des Fotos.
//
// Zeigt je nach Controller-Zustand einen Ladeindikator, den
// Fehlertext oder das Ergebnis mit der Bestaetigungszeile.
// Die Bestaetigungszeile fragt nach, ob alle Ringfarben richtig
// erkannt wurden: Der Nutzer bestaetigt oder oeffnet das
// Korrektur-Sheet.
/// Zeigt Ladezustand, Fehler oder Scan-Ergebnis unterhalb des Fotos.
class ScanErgebnisBereich extends StatelessWidget {
  final FarbtafelController controller;
  final VoidCallback onKorrektur;
  final VoidCallback onBestaetigen;
  const ScanErgebnisBereich({
    super.key,
    required this.controller,
    required this.onKorrektur,
    required this.onBestaetigen,
  });

  // Waehlt je nach Controller-Zustand Ladeindikator, Fehler oder Ergebnis.
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.laeuft.value) {
        return const CircularProgressIndicator();
      }
      if (controller.fehler.value.isNotEmpty) {
        return Text(
          'Fehler: ${controller.fehler.value}',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        );
      }
      if (controller.ergebnis.value.isNotEmpty) {
        return Column(
          children: [
            Text(
              controller.ergebnis.value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _bestaetigungsZeile(),
          ],
        );
      }
      return const SizedBox.shrink();
    });
  }

  // Frage "alles richtig?" mit den Knoepfen Korrigieren und Uebernehmen.
  Widget _bestaetigungsZeile() {
    return Column(
      children: [
        const Text(
          'Sind alle Ringfarben richtig erkannt?',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.edit, color: Colors.orange),
              label: const Text('Nein, korrigieren'),
              onPressed: onKorrektur,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Ja, uebernehmen'),
              onPressed: onBestaetigen,
            ),
          ],
        ),
      ],
    );
  }
}

// Button-Reihe "Foto laden" / "Analysieren".
//
// Beide Callbacks duerfen null sein - der jeweilige Button ist dann
// deaktiviert. So sperren die YOLO-Modi den Foto-Button waehrend
// der Erkennung, und "Analysieren" bleibt gesperrt, bis alle
// noetigen Eingaben vorliegen.
/// Gemeinsame Button-Reihe fuer Foto laden und Analyse starten.
class ScanButtonBereich extends StatelessWidget {
  final VoidCallback? onFotoLaden;
  final VoidCallback? onAnalysieren;
  const ScanButtonBereich({
    super.key,
    required this.onFotoLaden,
    required this.onAnalysieren,
  });

  // Baut die Reihe mit Foto- und Analyse-Button. Ein null-Callback
  // deaktiviert den jeweiligen Button.
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.photo),
          label: const Text('Foto laden'),
          onPressed: onFotoLaden,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Analysieren'),
          onPressed: onAnalysieren,
        ),
      ],
    );
  }
}
