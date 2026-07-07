/// Hilfsfunktionen fuer den CSV-Import.
///
/// Diese Datei enthaelt nur kleine Hilfsfunktionen:
/// - Feldzugriff ueber Spaltennamen
/// - Umwandlung leerer Texte zu null
/// - robuste Datumsaufloesung
/// - einfacher Semikolon-CSV-Parser
///
/// Dadurch bleibt csv_import.dart besser lesbar.
class CsvHelfer {
  /// Liest ein Feld ueber den Spaltennamen.
  ///
  /// Fehlt die Spalte oder ist der Index ausserhalb der Zeile, wird ein
  /// leerer String geliefert. Dadurch bricht der Import nicht sofort ab,
  /// sondern kann spaeter eine verstaendliche Meldung ausgeben.
  static String feld(
    List<String> werte,
    Map<String, int> spalten,
    String name,
  ) {
    final index = spalten[name];
    if (index == null || index < 0 || index >= werte.length) {
      return '';
    }
    return werte[index];
  }

  /// Wandelt einen leeren Text in null um.
  ///
  /// Das wird fuer optionale Datenbankfelder verwendet, z. B.
  /// Beschreibung, Widerstandswert, Toleranz oder Rueckgabedatum.
  static String? leerZuNull(String wert) {
    final text = wert.trim();
    return text.isEmpty ? null : text;
  }

  /// Wandelt einen CSV-Datumstext in einen ISO-String um.
  ///
  /// Akzeptiert:
  /// - ISO-Format: 2026-06-08
  /// - ISO mit Uhrzeit: 2026-06-08T10:30:00
  /// - deutsches Format: 08.06.2026
  /// - deutsches Kurzformat: 8.6.2026
  ///
  /// Leere oder ungueltige Werte liefern null.
  static String? _datumOderNull(String wert) {
    final text = wert.trim();
    if (text.isEmpty) {
      return null;
    }
    final iso = DateTime.tryParse(text);
    if (iso != null) {
      return iso.toIso8601String();
    }
    final teile = text.split('.');
    if (teile.length == 3) {
      final tag = int.tryParse(teile[0].trim());
      final monat = int.tryParse(teile[1].trim());
      final jahr = int.tryParse(teile[2].trim());
      if (tag != null && monat != null && jahr != null) {
        final datum = DateTime(jahr, monat, tag);
        // Ueberlauf abfangen:
        // DateTime(2026, 13, 32) wuerde sonst automatisch weiterrechnen.
        if (datum.year == jahr && datum.month == monat && datum.day == tag) {
          return datum.toIso8601String();
        }
      }
    }
    return null;
  }

  /// Produktdatum fuer erstelltAm/aktualisiertAm.
  ///
  /// Wenn das Datum gueltig ist, wird es uebernommen.
  /// Wenn es leer ist, wird null geliefert. Das Produkt-Modell setzt dann
  /// automatisch den Importzeitpunkt.
  /// Wenn es nicht leer, aber ungueltig ist, wird ein Hinweis ergaenzt.
  static String? produktDatum(
    String roh,
    String feldName,
    List<String> hinweise,
  ) {
    if (roh.trim().isEmpty) {
      return null;
    }
    final iso = _datumOderNull(roh);
    if (iso == null) {
      hinweise.add('$feldName ungueltig, Importzeitpunkt verwendet.');
      return null;
    }
    return iso;
  }

  /// Datum fuer den Beginn einer Ausleihe.
  ///
  /// Wenn das Feld leer oder ungueltig ist, wird das heutige Datum verwendet.
  static String ausleihdatum(String roh, List<String> hinweise) {
    final iso = _datumOderNull(roh);
    if (iso != null) {
      return iso;
    }
    hinweise.add('Ausleihdatum fehlt/ungueltig, heutiges Datum verwendet.');
    return DateTime.now().toIso8601String();
  }

  /// Fristdatum fuer eine Ausleihe.
  ///
  /// Wenn das Feld leer oder ungueltig ist, wird ausleihdatum + 14 Tage
  /// verwendet. Diese Regel ist einfach und fuer den Backup-Import gut
  /// erklaerbar.
  static String fristdatum(
    String roh,
    String ausleihdatum,
    List<String> hinweise,
  ) {
    final iso = _datumOderNull(roh);
    if (iso != null) {
      return iso;
    }
    final basis = DateTime.tryParse(ausleihdatum) ?? DateTime.now();
    hinweise.add(
      'Fristdatum fehlt/ungueltig, Ausleihdatum + 14 Tage verwendet.',
    );
    return basis.add(const Duration(days: 14)).toIso8601String();
  }

  /// Rueckgabedatum fuer eine Ausleihe.
  ///
  /// Leer bedeutet: Die Ausleihe ist offen.
  /// Ungueltige Werte werden ebenfalls als offen behandelt, aber mit Hinweis.
  static String? rueckgabedatum(String roh, List<String> hinweise) {
    if (roh.trim().isEmpty) {
      return null;
    }
    final iso = _datumOderNull(roh);
    if (iso == null) {
      hinweise.add('Rueckgabedatum ungueltig, Ausleihe als offen behandelt.');
      return null;
    }
    return iso;
  }

  /// Einfacher Parser fuer Semikolon-CSV mit "..."-Quoting.
  ///
  /// Unterstuetzt:
  /// - Semikolon als Trennzeichen
  /// - Felder in Anfuehrungszeichen
  /// - doppelte Anfuehrungszeichen innerhalb eines Feldes
  ///
  /// Echte Zeilenumbrueche innerhalb eines Feldes werden hier nicht
  /// unterstuetzt. Der Export ersetzt Zeilenumbrueche vorher durch " | ".
  static List<String> parseZeile(String zeile) {
    final werte = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;
    for (int i = 0; i < zeile.length; i++) {
      final zeichen = zeile[i];
      if (zeichen == '"') {
        final naechstes = i + 1 < zeile.length ? zeile[i + 1] : null;
        if (inQuote && naechstes == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (zeichen == ';' && !inQuote) {
        werte.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(zeichen);
      }
    }
    werte.add(buffer.toString());
    return werte;
  }
}
