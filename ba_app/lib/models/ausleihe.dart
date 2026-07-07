/// Ausleihe eines Produkts an eine Person.
///
/// Die Ausleihe wird getrennt vom Produktbestand gespeichert. So ist
/// festgehalten, welche Menge ausgeliehen wurde und ob die Rueckgabe schon
/// eingetragen ist.
class Ausleihe {
  int? id;
  int produktId;
  String vorname;
  String nachname;
  int menge;
  // Datumswerte werden als ISO-8601-Text gespeichert, damit SQLite sie einfach
  // ablegen kann und Dart sie spaeter wieder mit DateTime.tryParse lesen kann.
  String ausleihdatum;
  String fristdatum;
  // null oder leer bedeutet: Die Ausleihe ist noch offen.
  String? rueckgabedatum;
  String? notiz;

  Ausleihe({
    this.id,
    required this.produktId,
    required this.vorname,
    required this.nachname,
    this.menge = 1,
    required this.ausleihdatum,
    required this.fristdatum,
    this.rueckgabedatum,
    this.notiz,
  });

  /// Eine Ausleihe gilt erst dann als zurueckgegeben, wenn ein Rueckgabedatum
  /// vorhanden ist. Ein leerer Text zaehlt nicht als Rueckgabe.
  bool get istZurueckgegeben {
    return rueckgabedatum != null && rueckgabedatum!.trim().isNotEmpty;
  }

  // Kehrwert von istZurueckgegeben: offen, solange keine Rueckgabe vorliegt.
  bool get istOffen {
    return !istZurueckgegeben;
  }

  /// Prueft, ob die Rueckgabefrist ueberschritten ist.
  ///
  /// Dabei wird nur das Datum verglichen, nicht die Uhrzeit. Sonst koennte eine
  /// Ausleihe am Fristtag schon wegen der aktuellen Uhrzeit als ueberfaellig
  /// erscheinen.
  bool get istUeberfaellig {
    if (istZurueckgegeben) {
      return false;
    }
    final frist = DateTime.tryParse(fristdatum);
    if (frist == null) {
      return false;
    }
    final heute = _nurDatum(DateTime.now());
    final fristTag = _nurDatum(frist);
    return heute.isAfter(fristTag);
  }

  // Vor- und Nachname als ein Text.
  String get vollerName {
    return '$vorname $nachname'.trim();
  }

  // Ausleihdatum als DateTime, oder null bei ungueltigem Text.
  DateTime? get ausleihdatumParsed {
    return DateTime.tryParse(ausleihdatum);
  }

  // Fristdatum als DateTime, oder null bei ungueltigem Text.
  DateTime? get fristdatumParsed {
    return DateTime.tryParse(fristdatum);
  }

  // Rueckgabedatum als DateTime, oder null wenn offen oder ungueltig.
  DateTime? get rueckgabedatumParsed {
    if (rueckgabedatum == null || rueckgabedatum!.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(rueckgabedatum!);
  }

  /// Erstellt ein Ausleihe-Objekt aus einem Datenbankeintrag.
  factory Ausleihe.fromMap(Map<String, dynamic> map) {
    return Ausleihe(
      id: map['id'] as int?,
      produktId: map['produktId'] as int? ?? 0,
      vorname: map['vorname'] as String? ?? '',
      nachname: map['nachname'] as String? ?? '',
      menge: map['menge'] as int? ?? 1,
      ausleihdatum: map['ausleihdatum'] as String? ?? '',
      fristdatum: map['fristdatum'] as String? ?? '',
      rueckgabedatum: map['rueckgabedatum'] as String?,
      notiz: map['notiz'] as String?,
    );
  }

  /// Bereitet das Objekt fuer das Speichern in SQLite vor.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'produktId': produktId,
      'vorname': vorname,
      'nachname': nachname,
      'menge': menge,
      'ausleihdatum': ausleihdatum,
      'fristdatum': fristdatum,
      'rueckgabedatum': rueckgabedatum,
      'notiz': notiz,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() {
    return 'Ausleihe(id: $id, produktId: $produktId, '
        'an: $vollerName, menge: $menge, '
        'frist: $fristdatum, zurueck: $rueckgabedatum)';
  }

  // Schneidet die Uhrzeit ab und liefert nur Jahr, Monat und Tag.
  static DateTime _nurDatum(DateTime datum) {
    return DateTime(datum.year, datum.month, datum.day);
  }
}
