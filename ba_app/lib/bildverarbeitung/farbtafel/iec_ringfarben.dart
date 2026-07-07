// Erlaubte Farben je Ringposition nach IEC 60062.
//
// Die Funktion nutzt 1-basierte Ringpositionen:
// Position 1 = erster Ring, Position 2 = zweiter Ring usw.
// In InventarScan wird nur die in der Arbeit verwendete Teilmenge betrachtet.

// Schwarz = 0, Braun = 1, ..., Weiss = 9.
const List<String> _ziffernFarben = [
  'Schwarz',
  'Braun',
  'Rot',
  'Orange',
  'Gelb',
  'Gruen',
  'Blau',
  'Violett',
  'Grau',
  'Weiss',
];

// Multiplikatorfarben: Ziffernfarben plus Gold und Silber.
const List<String> _multiplikatorFarben = [
  'Schwarz',
  'Braun',
  'Rot',
  'Orange',
  'Gelb',
  'Gruen',
  'Blau',
  'Violett',
  'Grau',
  'Weiss',
  'Gold',
  'Silber',
];

// Toleranzfarben, die in der App unterstuetzt werden.
// Orange und Gelb werden in dieser Teilmenge nicht als Toleranzfarben zugelassen.
const List<String> _toleranzFarben = [
  'Braun',
  'Rot',
  'Gruen',
  'Blau',
  'Violett',
  'Grau',
  'Gold',
  'Silber',
];

/// Liefert die erlaubten Farben fuer eine Ringposition.
///
/// 4-Ring: Position 1/2 = Ziffern, 3 = Multiplikator, 4 = Toleranz.
/// 5-Ring: Position 1/2/3 = Ziffern, 4 = Multiplikator, 5 = Toleranz.
List<String> erlaubteFarbenFuerPosition({
  required int position,
  required int gesamtRinge,
}) {
  if (gesamtRinge == 4) {
    if (position == 1 || position == 2) {
      return _ziffernFarben;
    }

    if (position == 3) {
      return _multiplikatorFarben;
    }

    if (position == 4) {
      return _toleranzFarben;
    }
  }

  if (gesamtRinge == 5) {
    if (position == 1 || position == 2 || position == 3) {
      return _ziffernFarben;
    }

    if (position == 4) {
      return _multiplikatorFarben;
    }

    if (position == 5) {
      return _toleranzFarben;
    }
  }

  throw Exception('Position $position bei $gesamtRinge Ringen ist ungueltig.');
}
