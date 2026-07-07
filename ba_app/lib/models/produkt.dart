/// Produkt oder Gegenstand im lokalen Inventar.
///
/// Die Klasse enthaelt allgemeine Produktdaten wie Titel, Stueckzahl, Foto,
/// Kategorie und Lagerplatz. Bei Widerstaenden koennen zusaetzlich Ringfarben,
/// Widerstandswert und Toleranz gespeichert werden.
class Produkt {
  int? id;
  String titel;
  String? beschreibung;
  int stueckzahl;
  int mindestBestand;
  String? fotoPfad;
  int? kategorieId;
  int? lagerplatzId;
  // Widerstandsdaten aus dem Scan. Bei anderen Produkten bleiben diese Felder
  // leer. So kann dieselbe Tabelle normale Produkte und Widerstaende speichern.
  String? ringFarben;
  String? widerstandsWert;
  String? toleranz;
  String erstelltAm;
  String aktualisiertAm;

  Produkt({
    this.id,
    required this.titel,
    this.beschreibung,
    this.stueckzahl = 1,
    this.mindestBestand = 1,
    this.fotoPfad,
    this.kategorieId,
    this.lagerplatzId,
    this.ringFarben,
    this.widerstandsWert,
    this.toleranz,
    String? erstelltAm,
    String? aktualisiertAm,
  }) : erstelltAm = erstelltAm ?? DateTime.now().toIso8601String(),
       aktualisiertAm = aktualisiertAm ?? DateTime.now().toIso8601String();

  /// Gibt an, ob der Bestand unter der Mindestmenge liegt.
  ///
  /// Beispiel: Bei Stueckzahl 1 und Mindestmenge 1 erscheint noch keine Warnung.
  /// Erst wenn die Stueckzahl kleiner als die Mindestmenge ist, wird das Produkt
  /// als niedriger Bestand markiert.
  bool get istBestandNiedrig => stueckzahl < mindestBestand;

  /// Ein Produkt gilt hier als Widerstand, wenn ein Widerstandswert gespeichert ist.
  bool get istWiderstand =>
      widerstandsWert != null && widerstandsWert!.trim().isNotEmpty;

  /// Erstellt ein Produkt aus einem Datenbankeintrag.
  factory Produkt.fromMap(Map<String, dynamic> map) {
    return Produkt(
      id: map['id'] as int?,
      titel: map['titel'] as String? ?? '',
      beschreibung: map['beschreibung'] as String?,
      stueckzahl: map['stueckzahl'] as int? ?? 1,
      mindestBestand: map['mindestBestand'] as int? ?? 1,
      fotoPfad: map['fotoPfad'] as String?,
      kategorieId: map['kategorieId'] as int?,
      lagerplatzId: map['lagerplatzId'] as int?,
      ringFarben: map['ringFarben'] as String?,
      widerstandsWert: map['widerstandsWert'] as String?,
      toleranz: map['toleranz'] as String?,
      erstelltAm: map['erstelltAm'] as String?,
      aktualisiertAm: map['aktualisiertAm'] as String?,
    );
  }

  /// Bereitet das Produkt fuer das Speichern in SQLite vor.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'titel': titel,
      'beschreibung': beschreibung,
      'stueckzahl': stueckzahl,
      'mindestBestand': mindestBestand,
      'fotoPfad': fotoPfad,
      'kategorieId': kategorieId,
      'lagerplatzId': lagerplatzId,
      'ringFarben': ringFarben,
      'widerstandsWert': widerstandsWert,
      'toleranz': toleranz,
      'erstelltAm': erstelltAm,
      'aktualisiertAm': aktualisiertAm,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() {
    return 'Produkt(id: $id, titel: $titel, '
        'stueckzahl: $stueckzahl, wert: $widerstandsWert)';
  }
}
