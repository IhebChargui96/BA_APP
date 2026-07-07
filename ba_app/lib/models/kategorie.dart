/// Produktkategorie fuer die Ordnung des Inventars.
class Kategorie {
  int? id;
  String name;

  Kategorie({this.id, required this.name});

  /// Erstellt eine Kategorie aus einem Datenbankeintrag.
  factory Kategorie.fromMap(Map<String, dynamic> map) {
    return Kategorie(id: map['id'] as int?, name: map['name'] as String? ?? '');
  }

  /// Bereitet die Kategorie fuer das Speichern in SQLite vor.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'name': name};
    if (id != null) map['id'] = id;
    return map;
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() => 'Kategorie(id: $id, name: $name)';
}
