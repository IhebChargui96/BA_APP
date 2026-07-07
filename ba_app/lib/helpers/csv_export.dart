import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ausleihe.dart';
import '../models/kategorie.dart';
import '../models/lagerort.dart';
import '../models/lagerplatz.dart';
import '../models/produkt.dart';

/// Exportiert den Inventarbestand als flache Semikolon-CSV.
///
/// Aufbau: eine normale Tabelle. Eine Zeile entspricht einem Produkt mit
/// optionaler Ausleihe. Hat ein Produkt mehrere Ausleihen, wird die
/// Produktzeile pro Ausleihe wiederholt. Die Zeilen gehoeren ueber denselben
/// produktKey zusammen. produktKey ist nur ein CSV-Schluessel, keine SQLite-ID.
///
/// Nicht exportiert werden interne IDs und die Bilddateien selbst.
/// Zum Foto stehen zwei Spalten in der CSV:
/// - fotoVorhanden: ob die Bilddatei beim Export existierte (ja/nein)
/// - fotoPfad: der lokale Dateipfad des Fotos
/// Der Pfad ermoeglicht beim Import auf demselben Geraet, den Foto-Verweis
/// zu behalten. Auf einem anderen Geraet ist der Pfad ungueltig und wird
/// beim Import verworfen (mit Hinweis).
class CsvExport {
  static const String _trennzeichen = ';';
  static const List<String> _spalten = [
    'produktKey',
    'titel',
    'beschreibung',
    'stueckzahl',
    'mindestBestand',
    'kategorie',
    'lagerort',
    'lagerplatz',
    'qrCode',
    'ringFarben',
    'widerstandsWert',
    'toleranz',
    'erstelltAm',
    'aktualisiertAm',
    'fotoVorhanden',
    'fotoPfad',
    'ausleiheVorname',
    'ausleiheNachname',
    'ausleiheMenge',
    'ausleihdatum',
    'fristdatum',
    'rueckgabedatum',
    'ausleiheNotiz',
  ];

  /// Erstellt eine CSV-Datei und oeffnet den System-Teilen-Dialog.
  static Future<String> exportiereUndTeile({
    required List<Produkt> produkte,
    required List<Kategorie> kategorien,
    required List<Lagerort> lagerorte,
    required List<Lagerplatz> lagerplaetze,
    required List<Ausleihe> ausleihen,
  }) async {
    final pfad = await exportiereDatei(
      produkte: produkte,
      kategorien: kategorien,
      lagerorte: lagerorte,
      lagerplaetze: lagerplaetze,
      ausleihen: ausleihen,
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(pfad)], text: 'InventarScan CSV-Export'),
    );
    return pfad;
  }

  /// Schreibt die CSV-Datei in den App-Dokumenten-Ordner.
  static Future<String> exportiereDatei({
    required List<Produkt> produkte,
    required List<Kategorie> kategorien,
    required List<Lagerort> lagerorte,
    required List<Lagerplatz> lagerplaetze,
    required List<Ausleihe> ausleihen,
  }) async {
    final kategorieNachId = <int, Kategorie>{
      for (final k in kategorien)
        if (k.id != null) k.id!: k,
    };
    final lagerortNachId = <int, Lagerort>{
      for (final l in lagerorte)
        if (l.id != null) l.id!: l,
    };
    final lagerplatzNachId = <int, Lagerplatz>{
      for (final l in lagerplaetze)
        if (l.id != null) l.id!: l,
    };
    // Ausleihen nach Produkt gruppieren.
    final ausleihenNachProdukt = <int, List<Ausleihe>>{};
    for (final a in ausleihen) {
      ausleihenNachProdukt.putIfAbsent(a.produktId, () => []).add(a);
    }
    final zeilen = <String>[
      _zeile({for (final s in _spalten) s: s}),
    ];
    for (int i = 0; i < produkte.length; i++) {
      final produkt = produkte[i];
      final lagerplatz = lagerplatzNachId[produkt.lagerplatzId];
      final lagerort = lagerortNachId[lagerplatz?.lagerortId];
      final kategorie = kategorieNachId[produkt.kategorieId];
      // Produktdaten, die in jeder Zeile dieses Produkts stehen.
      final basis = <String, String>{
        'produktKey': 'P${(i + 1).toString().padLeft(3, '0')}',
        'titel': produkt.titel,
        'beschreibung': produkt.beschreibung ?? '',
        'stueckzahl': produkt.stueckzahl.toString(),
        'mindestBestand': produkt.mindestBestand.toString(),
        'kategorie': kategorie?.name ?? '',
        'lagerort': lagerort?.name ?? '',
        'lagerplatz': lagerplatz?.name ?? '',
        'qrCode': lagerplatz?.qrCode ?? '',
        'ringFarben': produkt.ringFarben ?? '',
        'widerstandsWert': produkt.widerstandsWert ?? '',
        'toleranz': produkt.toleranz ?? '',
        'erstelltAm': produkt.erstelltAm,
        'aktualisiertAm': produkt.aktualisiertAm,
        'fotoVorhanden': _fotoVorhanden(produkt.fotoPfad) ? 'ja' : 'nein',
        'fotoPfad': produkt.fotoPfad?.trim() ?? '',
      };
      final loans = produkt.id == null
          ? const <Ausleihe>[]
          : (ausleihenNachProdukt[produkt.id] ?? const <Ausleihe>[]);
      if (loans.isEmpty) {
        // Produkt ohne Ausleihe: eine Zeile, Ausleihspalten bleiben leer.
        zeilen.add(_zeile(basis));
      } else {
        // Pro Ausleihe eine Zeile. Die Produktdaten wiederholen sich.
        for (final a in loans) {
          zeilen.add(
            _zeile({
              ...basis,
              'ausleiheVorname': a.vorname,
              'ausleiheNachname': a.nachname,
              'ausleiheMenge': a.menge.toString(),
              'ausleihdatum': a.ausleihdatum,
              'fristdatum': a.fristdatum,
              'rueckgabedatum': a.rueckgabedatum ?? '',
              'ausleiheNotiz': a.notiz ?? '',
            }),
          );
        }
      }
    }
    final ordner = await getApplicationDocumentsDirectory();
    final datei = File('${ordner.path}/${_dateiname()}');
    // UTF-8-BOM hilft Tabellenprogrammen mit Umlauten und Sonderzeichen.
    final inhalt = '\uFEFF${zeilen.join('\n')}';
    await datei.writeAsString(inhalt, flush: true);
    return datei.path;
  }

  /// Baut eine CSV-Zeile in fester Spaltenreihenfolge.
  /// Nicht angegebene Spalten bleiben leer.
  static String _zeile(Map<String, String> felder) {
    return _spalten
        .map((spalte) => _csvFeld(felder[spalte] ?? ''))
        .join(_trennzeichen);
  }

  // Prueft, ob zum angegebenen Pfad eine Foto-Datei auf dem Geraet existiert.
  static bool _fotoVorhanden(String? pfad) {
    final text = pfad?.trim() ?? '';
    if (text.isEmpty) return false;
    try {
      return File(text).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Formatiert ein einzelnes CSV-Feld:
  /// - Zeilenumbrueche werden zu " | " zusammengezogen
  /// - Anfuehrungszeichen werden verdoppelt
  /// - Felder mit Semikolon oder Anfuehrungszeichen werden in "..." gesetzt
  static String _csvFeld(String wert) {
    var text = wert
        .replaceAll('\r\n', ' | ')
        .replaceAll('\n', ' | ')
        .replaceAll('\r', ' | ')
        .replaceAll('"', '""');
    if (text.contains(_trennzeichen) || text.contains('"')) {
      text = '"$text"';
    }
    return text;
  }

  // Baut den Dateinamen mit Zeitstempel aus Datum und Uhrzeit.
  static String _dateiname() {
    final jetzt = DateTime.now();
    String zwei(int wert) => wert.toString().padLeft(2, '0');
    return 'InventarScan_export_'
        '${jetzt.year}-${zwei(jetzt.month)}-${zwei(jetzt.day)}_'
        '${zwei(jetzt.hour)}-${zwei(jetzt.minute)}-${zwei(jetzt.second)}'
        '.csv';
  }
}
