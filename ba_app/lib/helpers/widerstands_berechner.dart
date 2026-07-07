// Berechnung des Widerstandswerts aus erkannten Farbringen.
//
// Grundlage ist die Farbcodierung nach IEC 60062. Die Rechenlogik entspricht
// der Darstellung in der Bachelorarbeit: Wertziffern d1, d2 und bei 5-Ring-
// Widerstaenden d3, danach Multiplikator und Toleranz.
//
// Unterstuetzt werden 4-Ring- und 5-Ring-Widerstaende. Nicht behandelt werden
// der 3-Ring-Code ohne Toleranzring, der sechste Ring fuer den
// Temperaturkoeffizienten und der Pink-Multiplikator. Orange und Gelb werden
// als Ziffern- und Multiplikatorfarben genutzt, aber nicht als Toleranzfarben
// uebernommen.

/// Wertziffer pro Farbe. Schwarz entspricht 0, Braun 1, Rot 2 und so weiter.
const Map<String, int> _farbZiffer = {
  'schwarz': 0,
  'braun': 1,
  'rot': 2,
  'orange': 3,
  'gelb': 4,
  'gruen': 5,
  'blau': 6,
  'violett': 7,
  'grau': 8,
  'weiss': 9,
};

/// Multiplikator der Farbe als fertiger Faktor.
///
/// Gold und Silber stehen fuer Faktoren kleiner als 1.
const Map<String, double> _farbMultiplikator = {
  'schwarz': 1,
  'braun': 10,
  'rot': 100,
  'orange': 1000,
  'gelb': 10000,
  'gruen': 100000,
  'blau': 1000000,
  'violett': 10000000,
  'grau': 100000000,
  'weiss': 1000000000,
  'gold': 0.1,
  'silber': 0.01,
};

/// Toleranztext fuer den letzten Ring.
///
/// Die Tabelle enthaelt die in InventarScan genutzte Teilmenge der
/// Toleranzfarben. Fehlt eine Farbe, wird sie am Toleranzring nicht akzeptiert.
const Map<String, String> _farbToleranz = {
  'braun': '+/- 1%',
  'rot': '+/- 2%',
  'gruen': '+/- 0.5%',
  'blau': '+/- 0.25%',
  'violett': '+/- 0.1%',
  'grau': '+/- 0.01%',
  'gold': '+/- 5%',
  'silber': '+/- 10%',
};

/// Ergebnis einer Widerstandsberechnung.
class IecErgebnis {
  /// Berechneter Widerstandswert in Ohm.
  final double widerstandOhm;

  /// Wert als Text mit passender Einheit, zum Beispiel `4,7 kOhm`.
  final String formatierterWert;

  /// Toleranztext aus dem letzten Ring.
  final String toleranz;

  /// Anzahl der ausgewerteten Ringe.
  final int anzahlRinge;

  /// Hinweis bei ungueltiger Eingabe. `null` bedeutet: Ergebnis ist gueltig.
  final String? hinweis;

  IecErgebnis({
    required this.widerstandOhm,
    required this.formatierterWert,
    required this.toleranz,
    required this.anzahlRinge,
    this.hinweis,
  });

  /// Gibt an, ob die Farbringfolge erfolgreich berechnet werden konnte.
  bool get istGueltig => hinweis == null;

  // Kurze Textform: formatierter Wert und Toleranz, zum Beispiel `4,7 kOhm +/- 5%`.
  @override
  String toString() => '$formatierterWert $toleranz';
}

/// Berechnet den Widerstandswert aus einer Liste von Farbringen.
///
/// Die Funktion erwartet die Ringe bereits in richtiger Leserichtung.
/// Bei ungueltigen Farben wird kein Fehler geworfen, sondern ein Ergebnis mit
/// Hinweistext zurueckgegeben. Die UI kann diesen Hinweis anzeigen.
IecErgebnis berechneWiderstand(List<String> ringe) {
  if (ringe.length != 4 && ringe.length != 5) {
    return _fehler(
      'Es werden 4 oder 5 Ringe erwartet, gefunden: ${ringe.length}.',
      ringe.length,
    );
  }
  // Bei 4-Ring sind es zwei Wertziffern, bei 5-Ring drei.
  // Danach folgen Multiplikator und Toleranz.
  final anzahlZiffern = ringe.length - 2;
  // Die Wertziffern werden nacheinander zu einer Zahl zusammengesetzt:
  // 4-Ring: d1 * 10 + d2
  // 5-Ring: d1 * 100 + d2 * 10 + d3
  int wert = 0;
  for (int i = 0; i < anzahlZiffern; i++) {
    final d = _farbZiffer[ringe[i].toLowerCase()];
    if (d == null) {
      return _fehler(
        'Ring ${i + 1} (${ringe[i]}) konnte nicht als Wertziffer erkannt werden. '
        'Bitte mit "Korrigieren" anpassen.',
        ringe.length,
      );
    }
    wert = wert * 10 + d;
  }
  final mult = _farbMultiplikator[ringe[anzahlZiffern].toLowerCase()];
  if (mult == null) {
    return _fehler(
      'Multiplikator-Ring (${ringe[anzahlZiffern]}) konnte nicht erkannt werden. '
      'Bitte mit "Korrigieren" anpassen.',
      ringe.length,
    );
  }
  final tol = _farbToleranz[ringe[anzahlZiffern + 1].toLowerCase()];
  if (tol == null) {
    return _fehler(
      'Toleranz-Ring (${ringe[anzahlZiffern + 1]}) konnte nicht erkannt werden. '
      'Bitte mit "Korrigieren" anpassen.',
      ringe.length,
    );
  }
  final ohm = wert * mult;
  return IecErgebnis(
    widerstandOhm: ohm,
    formatierterWert: _formatiere(ohm),
    toleranz: tol,
    anzahlRinge: ringe.length,
  );
}

/// Baut ein ungueltiges Ergebnis mit Hinweistext.
IecErgebnis _fehler(String hinweis, int anzahlRinge) {
  return IecErgebnis(
    widerstandOhm: 0,
    formatierterWert: '?',
    toleranz: '?',
    anzahlRinge: anzahlRinge,
    hinweis: hinweis,
  );
}

/// Formatiert einen Ohm-Wert mit passender Einheit.
String _formatiere(double ohm) {
  if (ohm < 1000) {
    if (ohm == ohm.toInt()) return '${ohm.toInt()} Ohm';
    return '${_kommaFormat(ohm)} Ohm';
  }
  if (ohm < 1000000) {
    return '${_kommaFormat(ohm / 1000)} kOhm';
  }
  return '${_kommaFormat(ohm / 1000000)} MOhm';
}

/// Formatiert eine Zahl mit Komma als Dezimaltrennzeichen.
///
/// Bei glatten Werten wird die Nachkommastelle weggelassen.
String _kommaFormat(double wert) {
  if (wert == wert.toInt()) return '${wert.toInt()}';
  return wert.toStringAsFixed(1).replaceAll('.', ',');
}
