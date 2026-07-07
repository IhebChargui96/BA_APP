// Bottom Sheet zum Korrigieren der erkannten Ringfarben.
//
// Nach der automatischen Erkennung kann die Farbliste einzeln angepasst
// oder die Leserichtung umgekehrt werden. So bleibt das Scan-Ergebnis
// kontrollierbar, bevor es in das Produktformular uebernommen wird.

import 'package:flutter/material.dart';

import '../bildverarbeitung/farbtafel/iec_ringfarben.dart';
import '../helpers/widerstands_berechner.dart';

// Hilfsfunktion zum Aufrufen des Sheets von einem Screen aus.
//
// aktuelleFarben:
//   Die aktuelle Farbliste (vom Controller).
//
// gesamtRinge:
//   4 oder 5.
//
// Rueckgabe:
//   Die korrigierte Liste, oder null bei Abbruch.
/// Oeffnet das Korrektur-Sheet und gibt die geaenderte Farbliste zurueck.
Future<List<String>?> zeigeKorrekturSheet({
  required BuildContext context,
  required List<String> aktuelleFarben,
  required int gesamtRinge,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => KorrekturSheet(
      aktuelleFarben: aktuelleFarben,
      gesamtRinge: gesamtRinge,
    ),
  );
}

/// Erlaubt die manuelle Korrektur der erkannten Ringfarben.
class KorrekturSheet extends StatefulWidget {
  final List<String> aktuelleFarben;
  final int gesamtRinge;
  const KorrekturSheet({
    super.key,
    required this.aktuelleFarben,
    required this.gesamtRinge,
  });

  @override
  State<KorrekturSheet> createState() => _KorrekturSheetState();
}

class _KorrekturSheetState extends State<KorrekturSheet> {
  late List<String> _farben;

  @override
  void initState() {
    super.initState();
    // Eigene Kopie damit Aenderungen nicht in die Original-Liste schreiben.
    _farben = List<String>.from(widget.aktuelleFarben);
  }

  // Setzt die Farbe an einer Ringposition neu.
  void _setzeFarbe(int index, String farbe) {
    setState(() => _farben[index] = farbe);
  }

  // Kehrt die Leserichtung der Ringe um.
  void _umkehren() {
    setState(() => _farben = _farben.reversed.toList());
  }

  /// Berechnet eine kurze Vorschau aus der aktuell gewaehlten Farbliste.
  String _vorschau() {
    try {
      final iec = berechneWiderstand(_farben);
      if (iec.hinweis != null) {
        return 'Hinweis: ${iec.hinweis}';
      }
      return '${iec.formatierterWert} ${iec.toleranz}';
    } catch (e) {
      return 'Fehler: $e';
    }
  }

  // Baut das Sheet mit Ring-Dropdowns, Umkehr-Button, Vorschau und Aktionen auf.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ringfarben korrigieren',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ...List.generate(_farben.length, _ringZeile),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Reihenfolge umkehren'),
              onPressed: _umkehren,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Vorschau: ${_vorschau()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Uebernehmen'),
                  onPressed: () => Navigator.pop(context, _farben),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Eine Zeile pro Ring: Dropdown mit den an dieser Position erlaubten Farben.
  // Eine unerlaubte Farbe wird rot markiert und muss geaendert werden.
  Widget _ringZeile(int i) {
    final erlaubt = erlaubteFarbenFuerPosition(
      position: i + 1,
      gesamtRinge: widget.gesamtRinge,
    );
    final aktuell = _farben[i];
    final aktuellIstErlaubt = erlaubt.contains(aktuell);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              'Ring ${i + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: aktuellIstErlaubt ? aktuell : null,
              isExpanded: true,
              hint: Text(
                aktuellIstErlaubt
                    ? aktuell
                    : '$aktuell (ungueltig - bitte aendern)',
                style: TextStyle(color: aktuellIstErlaubt ? null : Colors.red),
              ),
              items: erlaubt
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (neu) {
                if (neu != null) _setzeFarbe(i, neu);
              },
            ),
          ),
        ],
      ),
    );
  }
}
