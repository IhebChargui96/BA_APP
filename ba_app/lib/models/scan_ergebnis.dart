/// Ergebnis eines Widerstands-Scans.
///
/// Dieses Objekt wird zwischen Scanbereich und Produktformular uebergeben. Das
/// Scan-Ergebnis wird dadurch nicht sofort gespeichert, sondern kann im Formular
/// zuerst geprueft und ergaenzt werden.
class ScanErgebnis {
  final String fotoPfad;
  final String ringFarben;
  final String? widerstandsWert;
  final String? toleranz;
  final String? hinweis;

  const ScanErgebnis({
    required this.fotoPfad,
    required this.ringFarben,
    this.widerstandsWert,
    this.toleranz,
    this.hinweis,
  });

  // True, wenn ein Widerstandswert vorliegt.
  bool get hatWiderstandswert =>
      widerstandsWert != null && widerstandsWert!.trim().isNotEmpty;
  // True, wenn ein Hinweistext vorliegt.
  bool get hatHinweis => hinweis != null && hinweis!.trim().isNotEmpty;

  /// Vorschlag fuer den Produkt-Titel im Formular.
  String get titelVorschlag =>
      hatWiderstandswert ? 'Widerstand $widerstandsWert' : 'Widerstand';

  /// Vorschlag fuer die Produktbeschreibung.
  ///
  /// Die Werte bleiben sichtbar, damit die Nutzerin oder der Nutzer das
  /// Scan-Ergebnis vor dem Speichern kontrollieren kann.
  String get beschreibungVorschlag {
    final zeilen = [
      'Farbringe: $ringFarben',
      if (widerstandsWert != null && widerstandsWert!.trim().isNotEmpty)
        'Widerstandswert: $widerstandsWert',
      if (toleranz != null && toleranz!.trim().isNotEmpty)
        'Toleranz: $toleranz',
      if (hinweis != null && hinweis!.trim().isNotEmpty) 'Hinweis: $hinweis',
    ];
    return zeilen.join('\n');
  }

  // Textform fuer Logausgaben und Fehlersuche.
  @override
  String toString() =>
      'ScanErgebnis(ringFarben: $ringFarben, wert: $widerstandsWert)';
}
