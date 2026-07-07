/// Grober Lagerort, zum Beispiel Labor, Arbeitszimmer oder Werkstatt.
///
/// Ein Lagerort ist die uebergeordnete Ebene. Die genaue Stelle wird danach
/// ueber einen Lagerplatz beschrieben.
class Lagerort {
  int? id;
  String name;
  String? beschreibung;

  Lagerort({this.id, required this.name, this.beschreibung});

  /// Erstellt einen Lagerort aus einem Datenbankeintrag.
  factory Lagerort.fromMap(Map<String, dynamic> map) {
    return Lagerort(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      beschreibung: map['beschreibung'] as String?,
    );
  }

  /// Bereitet den Lagerort fuer das Speichern in SQLite vor.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'name': name, 'beschreibung': beschreibung};
    if (id != null) map['id'] = id;
    return map;
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() => 'Lagerort(id: $id, name: $name)';
}
