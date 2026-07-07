/// Konkreter Lagerplatz innerhalb eines Lagerorts.
///
/// Ein Lagerplatz kann optional einen QR-Code besitzen. Der QR-Code gehoert zum
/// Lagerplatz und nicht zu einem einzelnen Produkt. Dadurch kann die App nach
/// dem Scannen direkt den passenden Lagerplatz oeffnen.
class Lagerplatz {
  int? id;
  String name;
  String? qrCode;
  int? lagerortId;

  Lagerplatz({this.id, required this.name, this.qrCode, this.lagerortId});

  /// Erstellt einen Lagerplatz aus einem Datenbankeintrag.
  factory Lagerplatz.fromMap(Map<String, dynamic> map) {
    return Lagerplatz(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      qrCode: map['qrCode'] as String?,
      lagerortId: map['lagerortId'] as int?,
    );
  }

  /// Bereitet den Lagerplatz fuer das Speichern in SQLite vor.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'qrCode': qrCode,
      'lagerortId': lagerortId,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() =>
      'Lagerplatz(id: $id, name: $name, lagerortId: $lagerortId)';
}
