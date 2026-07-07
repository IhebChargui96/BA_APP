/// Validatoren fuer Formulareingaben in InventarScan.
///
/// Die Methoden liefern `null`, wenn die Eingabe gueltig ist. Bei einem Fehler
/// wird ein Text zurueckgegeben, den Flutter unter dem Formularfeld anzeigen kann.
class Validatoren {
  /// Vollstaendiger HsH-Raumcode, zum Beispiel `1B.0.29`.
  static final RegExp hsHRaumCodeRegex = RegExp(
    r'^\d+[A-Z]\.\d+\.\d{1,3}[a-z]?$',
  );

  /// Sucht einen Raumcode innerhalb eines laengeren Textes.
  ///
  /// Beispiel: Aus `Labor 1B.0.29` wird `1B.0.29` gefunden.
  static final RegExp raumCodeImTextRegex = RegExp(
    r'\d+[A-Za-z]\.\d+\.\d{1,3}[a-z]?',
  );

  /// Erkennt halbfertige Raumcodes wie `1B.0`.
  ///
  /// Dadurch kann die App gezielt einen Hinweis geben, statt die Eingabe als
  /// freien Lagerortnamen zu akzeptieren.
  static final RegExp unvollstaendigerRaumCodeRegex = RegExp(
    r'\d+[A-Za-z]\.\d+',
  );

  /// Erkennt das haeufige falsche Format mit Punkt zwischen Zahl und Buchstabe.
  ///
  /// Beispiel: `1.A.30` statt `1A.0.30`.
  static final RegExp falschGetrenntRegex = RegExp(r'\d+\.[A-Za-z]\.\d+');

  /// Prueft den Namen eines Lagerorts.
  ///
  /// Freie Namen wie `Arbeitszimmer` sind erlaubt. Wenn die Eingabe aber wie
  /// ein HsH-Raumcode aussieht, wird das Format genauer geprueft.
  static String? pruefeLagerortName(String name) {
    final text = name.trim();
    if (text.isEmpty) {
      return 'Bitte einen Namen eingeben.';
    }
    if (text.length < 2) {
      return 'Der Lagerort ist zu kurz.';
    }
    if (falschGetrenntRegex.hasMatch(text)) {
      return 'Raumformat: GebaeudeTrakt.Etage.Raum (z. B. 1B.0.29). '
          'Zwischen Zahl und Buchstabe gehoert kein Punkt.';
    }
    final raumCode = extrahiereRaumCode(text);
    if (raumCode != null) {
      final formatiert = formatiereRaumCode(raumCode);
      if (!hsHRaumCodeRegex.hasMatch(formatiert)) {
        return 'Raumformat ungueltig. Beispiel: 1B.0.29';
      }
      return null;
    }
    if (unvollstaendigerRaumCodeRegex.hasMatch(text)) {
      return 'Raumformat ungueltig. Beispiel: 1B.0.29';
    }
    return null;
  }

  /// Gibt den ersten Raumcode aus einem Text zurueck, falls einer gefunden wird.
  static String? extrahiereRaumCode(String text) {
    return raumCodeImTextRegex.firstMatch(text.trim())?.group(0);
  }

  /// Formatiert den Trakt-Buchstaben eines Raumcodes gross.
  ///
  /// Beispiel: `1b.0.29` wird zu `1B.0.29`.
  static String formatiereRaumCode(String raumCode) {
    final text = raumCode.trim();
    if (text.length < 2) {
      return text;
    }
    final match = RegExp(r'^(\d+)([A-Za-z])(.*)$').firstMatch(text);
    if (match == null) {
      return text;
    }
    final nummer = match.group(1)!;
    final trakt = match.group(2)!.toUpperCase();
    final rest = match.group(3)!;
    return '$nummer$trakt$rest';
  }

  /// Formatiert einen Lagerortnamen und normalisiert darin enthaltene Raumcodes.
  static String formatiereLagerort(String name) {
    final text = name.trim();
    final raumCode = extrahiereRaumCode(text);
    if (raumCode == null) {
      return text;
    }
    return text.replaceFirst(raumCode, formatiereRaumCode(raumCode));
  }

  /// Prueft, ob ein Lagerortname einen Raumcode enthaelt.
  static bool enthaeltRaumCode(String name) {
    return extrahiereRaumCode(name) != null;
  }

  /// Prueft, ob ein Text ein vollstaendiger HsH-Raumcode ist.
  static bool istGueltigerRaumCode(String text) {
    final formatiert = formatiereRaumCode(text.trim());
    return hsHRaumCodeRegex.hasMatch(formatiert);
  }

  /// Prueft ein Pflichtfeld auf leeren Inhalt.
  static String? pruefePflichtfeld(String text, String feldName) {
    if (text.trim().isEmpty) {
      return 'Bitte $feldName eingeben.';
    }
    return null;
  }

  /// Prueft die Stueckzahl eines Produkts.
  ///
  /// Der Wert darf 0 sein, weil ein Produkt im Inventar bekannt sein kann,
  /// auch wenn gerade kein Bestand vorhanden ist.
  static String? pruefeStueckzahl(String text) {
    return _pruefeGanzeZahl(text, feldName: 'Stueckzahl', minimum: 0);
  }

  /// Prueft die Mindestmenge eines Produkts.
  ///
  /// Die Mindestmenge muss mindestens 1 sein. So kann die Warnfunktion fuer
  /// niedrige Bestaende sinnvoll arbeiten.
  static String? pruefeMindestBestand(String text) {
    return _pruefeGanzeZahl(text, feldName: 'Mindestmenge', minimum: 1);
  }

  /// Gemeinsame Pruefung fuer ganzzahlige Eingaben mit unterer Grenze.
  static String? _pruefeGanzeZahl(
    String text, {
    required String feldName,
    required int minimum,
  }) {
    final wert = text.trim();
    if (wert.isEmpty) {
      return 'Bitte eine ganze Zahl eingeben.';
    }
    final zahl = int.tryParse(wert);
    if (zahl == null) {
      return 'Bitte eine ganze Zahl eingeben.';
    }
    if (zahl < minimum) {
      if (minimum == 0) {
        return '$feldName darf nicht negativ sein.';
      }
      return '$feldName muss mindestens $minimum sein.';
    }
    return null;
  }
}
