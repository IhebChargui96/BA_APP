import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/ausleihe.dart';
import '../models/kategorie.dart';
import '../models/lagerort.dart';
import '../models/lagerplatz.dart';
import '../models/produkt.dart';
import '../services/datenbank_service.dart';
import 'csv_helfer.dart';

/// Ergebnis eines CSV-Imports fuer die Rueckmeldung an die UI.
class CsvImportErgebnis {
  final int produkteImportiert;
  final int produkteUebersprungen;
  final int kategorienErstellt;
  final int lagerorteErstellt;
  final int lagerplaetzeErstellt;
  final int ausleihenImportiert;
  final int ausleihenUebersprungen;
  final List<String> hinweise;
  const CsvImportErgebnis({
    this.produkteImportiert = 0,
    this.produkteUebersprungen = 0,
    this.kategorienErstellt = 0,
    this.lagerorteErstellt = 0,
    this.lagerplaetzeErstellt = 0,
    this.ausleihenImportiert = 0,
    this.ausleihenUebersprungen = 0,
    this.hinweise = const [],
  });
  factory CsvImportErgebnis.mitHinweis(String hinweis) =>
      CsvImportErgebnis(hinweise: [hinweis]);
}

/// Importiert eine flache InventarScan-CSV als Wiederherstellung.
///
/// Eine CSV-Zeile beschreibt ein Produkt mit optionaler Ausleihe. Mehrere
/// Zeilen mit gleichem produktKey gehoeren zum selben Produkt, zum Beispiel
/// wenn ein Produkt mehrere Ausleihen hat.
///
/// Der Import ersetzt den vorhandenen Datenbestand. Loeschen und Neuaufbau
/// laufen in einer SQLite-Transaktion. Wenn ein Fehler auftritt, bleibt der
/// alte Bestand erhalten. Bilddateien werden nicht in der CSV gespeichert.
/// Ein fotoPfad wird nur uebernommen, wenn die Datei auf diesem Geraet
/// wirklich existiert.
class CsvImport {
  static final DatenbankService _db = DatenbankService.instanz;
  static const List<String> _pflichtSpalten = ['produktKey', 'titel'];

  // Liest die CSV, prueft das Format und baut den Datenbestand in einer
  // Transaktion neu auf. Bei einem Fehler bleibt der alte Bestand erhalten.
  static Future<CsvImportErgebnis> importiere(String pfad) async {
    final datei = File(pfad);
    if (!datei.existsSync()) {
      return CsvImportErgebnis.mitHinweis('Datei wurde nicht gefunden.');
    }
    var inhalt = await datei.readAsString();
    if (inhalt.startsWith('\uFEFF')) {
      inhalt = inhalt.substring(1);
    }
    final zeilen = inhalt
        .split(RegExp(r'\r?\n'))
        .where((z) => z.trim().isNotEmpty)
        .toList();
    if (zeilen.length < 2) {
      return CsvImportErgebnis.mitHinweis('CSV-Datei enthaelt keine Daten.');
    }
    // Spaltennamen aus der Kopfzeile auf ihre Position abbilden.
    final spalten = <String, int>{};
    final kopf = CsvHelfer.parseZeile(zeilen.first);
    for (int i = 0; i < kopf.length; i++) {
      spalten[kopf[i].trim()] = i;
    }
    final fehlende = _pflichtSpalten
        .where((s) => !spalten.containsKey(s))
        .toList();
    if (fehlende.isNotEmpty) {
      return CsvImportErgebnis.mitHinweis(
        'CSV-Format passt nicht. Fehlende Spalten: ${fehlende.join(', ')}',
      );
    }
    // Datenzeilen einmal parsen. reihen[j] entspricht CSV-Zeile j + 2.
    final reihen = [
      for (int i = 1; i < zeilen.length; i++) CsvHelfer.parseZeile(zeilen[i]),
    ];
    String feld(List<String> werte, String name) =>
        CsvHelfer.feld(werte, spalten, name);
    final hinweise = <String>[];
    // Ohne mindestens eine Zeile mit Titel wird nichts geloescht.
    final hatProdukt = reihen.any(
      (werte) => feld(werte, 'titel').trim().isNotEmpty,
    );
    if (!hatProdukt) {
      return CsvImportErgebnis.mitHinweis(
        'Import abgebrochen: keine gueltige Produktzeile gefunden.',
      );
    }
    // Die Caches gelten nur fuer diesen Import. Die Tabellen werden vorher
    // geleert, deshalb werden Kategorien und Lagerdaten hier neu aufgebaut.
    final kategorieCache = <String, int>{};
    final lagerortCache = <String, int>{};
    final lagerplatzCache = <String, int>{};
    int produkteImportiert = 0;
    int produkteUebersprungen = 0;
    int ausleihenImportiert = 0;
    int ausleihenUebersprungen = 0;
    try {
      await _db.inTransaktion((txn) async {
        // Restore: zuerst den alten Zustand entfernen.
        await _db.alleDatenLoeschenMit(txn);
        final keyZuId = <String, int>{};
        final keyZuTitel = <String, String>{};
        for (int j = 0; j < reihen.length; j++) {
          final werte = reihen[j];
          final nr = j + 2;
          final titel = feld(werte, 'titel').trim();
          if (titel.isEmpty) {
            produkteUebersprungen++;
            hinweise.add('Zeile $nr: Titel fehlt, Zeile uebersprungen.');
            continue;
          }
          var key = feld(werte, 'produktKey').trim().toUpperCase();
          if (key.isEmpty) {
            // Ohne Schluessel ist die Zeile ein eigenstaendiges Produkt.
            key = 'P_ZEILE_$nr';
          }
          // Produkt pro produktKey nur einmal anlegen.
          var produktId = keyZuId[key];
          if (produktId == null) {
            final kategorieId = await _kategorieId(
              txn,
              feld(werte, 'kategorie'),
              kategorieCache,
            );
            final lagerortId = await _lagerortId(
              txn,
              feld(werte, 'lagerort'),
              lagerortCache,
            );
            final lagerplatzId = await _lagerplatzId(
              txn,
              name: feld(werte, 'lagerplatz'),
              lagerortId: lagerortId,
              qrCode: feld(werte, 'qrCode'),
              cache: lagerplatzCache,
            );
            final lokal = <String>[];
            final stueckzahl = _zahl(
              feld(werte, 'stueckzahl'),
              0,
              0,
              'Stueckzahl',
              lokal,
            );
            // Standard und Minimum sind 1, wie beim Anlegen in der App.
            final mindestBestand = _zahl(
              feld(werte, 'mindestBestand'),
              1,
              1,
              'Mindestmenge',
              lokal,
            );
            final erstelltAm = CsvHelfer.produktDatum(
              feld(werte, 'erstelltAm'),
              'erstelltAm',
              lokal,
            );
            final aktualisiertAm = CsvHelfer.produktDatum(
              feld(werte, 'aktualisiertAm'),
              'aktualisiertAm',
              lokal,
            );
            for (final h in lokal) {
              hinweise.add('Zeile $nr: $h');
            }
            // Foto-Verweis nur uebernehmen, wenn die Datei auf diesem
            // Geraet wirklich existiert. So behaelt ein Restore auf dem
            // gleichen Geraet die Fotos. Pfade von fremden Geraeten werden
            // verworfen und gemeldet.
            final fotoPfadRoh = feld(werte, 'fotoPfad').trim();
            String? fotoPfad;
            if (fotoPfadRoh.isNotEmpty) {
              if (File(fotoPfadRoh).existsSync()) {
                fotoPfad = fotoPfadRoh;
              } else {
                lokal.add('Foto nicht gefunden, Verweis entfernt.');
              }
            }
            final produkt = Produkt(
              titel: titel,
              beschreibung: CsvHelfer.leerZuNull(feld(werte, 'beschreibung')),
              stueckzahl: stueckzahl,
              mindestBestand: mindestBestand,
              fotoPfad: fotoPfad,
              kategorieId: kategorieId,
              lagerplatzId: lagerplatzId,
              ringFarben: CsvHelfer.leerZuNull(feld(werte, 'ringFarben')),
              widerstandsWert: CsvHelfer.leerZuNull(
                feld(werte, 'widerstandsWert'),
              ),
              toleranz: CsvHelfer.leerZuNull(feld(werte, 'toleranz')),
              erstelltAm: erstelltAm,
              aktualisiertAm: aktualisiertAm,
            );
            produktId = await _db.produktWiederherstellenMit(txn, produkt);
            keyZuId[key] = produktId;
            keyZuTitel[key] = titel;
            produkteImportiert++;
          } else if (keyZuTitel[key] != titel) {
            hinweise.add(
              'Zeile $nr: abweichende Produktdaten fuer produktKey "$key", '
              'erste Zeile gilt.',
            );
          }
          // Ausleihe nur, wenn diese Zeile Ausleihdaten hat.
          final vorname = feld(werte, 'ausleiheVorname').trim();
          final nachname = feld(werte, 'ausleiheNachname').trim();
          if (vorname.isEmpty && nachname.isEmpty) {
            continue;
          }
          if (vorname.isEmpty || nachname.isEmpty) {
            ausleihenUebersprungen++;
            hinweise.add(
              'Zeile $nr: Vorname oder Nachname fehlt, Ausleihe uebersprungen.',
            );
            continue;
          }
          final lokal = <String>[];
          final ausleihdatum = CsvHelfer.ausleihdatum(
            feld(werte, 'ausleihdatum'),
            lokal,
          );
          final fristdatum = CsvHelfer.fristdatum(
            feld(werte, 'fristdatum'),
            ausleihdatum,
            lokal,
          );
          final rueckgabedatum = CsvHelfer.rueckgabedatum(
            feld(werte, 'rueckgabedatum'),
            lokal,
          );
          final menge = _zahl(
            feld(werte, 'ausleiheMenge'),
            1,
            1,
            'Ausleihmenge',
            lokal,
          );
          for (final h in lokal) {
            hinweise.add('Zeile $nr: $h');
          }
          final ausleihe = Ausleihe(
            produktId: produktId,
            vorname: vorname,
            nachname: nachname,
            menge: menge,
            ausleihdatum: ausleihdatum,
            fristdatum: fristdatum,
            rueckgabedatum: rueckgabedatum,
            notiz: CsvHelfer.leerZuNull(feld(werte, 'ausleiheNotiz')),
          );
          await _db.ausleiheWiederherstellenMit(txn, ausleihe);
          ausleihenImportiert++;
        }
      });
    } catch (e) {
      // Die Transaktion wurde zurueckgerollt, der alte Bestand ist erhalten.
      return CsvImportErgebnis(
        hinweise: [
          ...hinweise,
          'Import abgebrochen, alte Daten wurden nicht veraendert: $e',
        ],
      );
    }
    // Aeltere Exporte hatten noch keine fotoPfad-Spalte.
    if (produkteImportiert > 0 && !spalten.containsKey('fotoPfad')) {
      hinweise.add('CSV ohne fotoPfad-Spalte: Fotos wurden nicht uebernommen.');
    }
    return CsvImportErgebnis(
      produkteImportiert: produkteImportiert,
      produkteUebersprungen: produkteUebersprungen,
      kategorienErstellt: kategorieCache.length,
      lagerorteErstellt: lagerortCache.length,
      lagerplaetzeErstellt: lagerplatzCache.length,
      ausleihenImportiert: ausleihenImportiert,
      ausleihenUebersprungen: ausleihenUebersprungen,
      hinweise: hinweise,
    );
  }

  // Stammdaten anlegen und im Cache merken
  // Legt eine Kategorie einmal pro Name an und merkt sie im Cache.
  static Future<int?> _kategorieId(
    Transaction txn,
    String name,
    Map<String, int> cache,
  ) async {
    final text = name.trim();
    if (text.isEmpty) return null;
    final schluessel = text.toLowerCase();
    final vorhanden = cache[schluessel];
    if (vorhanden != null) return vorhanden;
    final id = await _db.kategorieEinfuegenMit(txn, Kategorie(name: text));
    cache[schluessel] = id;
    return id;
  }

  // Legt einen Lagerort einmal pro Name an und merkt ihn im Cache.
  static Future<int?> _lagerortId(
    Transaction txn,
    String name,
    Map<String, int> cache,
  ) async {
    final text = name.trim();
    if (text.isEmpty) return null;
    final schluessel = text.toLowerCase();
    final vorhanden = cache[schluessel];
    if (vorhanden != null) return vorhanden;
    final id = await _db.lagerortEinfuegenMit(txn, Lagerort(name: text));
    cache[schluessel] = id;
    return id;
  }

  // Legt einen Lagerplatz einmal pro Lagerort und Name an und merkt ihn im Cache.
  static Future<int?> _lagerplatzId(
    Transaction txn, {
    required String name,
    required int? lagerortId,
    required String qrCode,
    required Map<String, int> cache,
  }) async {
    final text = name.trim();
    if (text.isEmpty) return null;
    final schluessel = '${lagerortId ?? 0}|${text.toLowerCase()}';
    final vorhanden = cache[schluessel];
    if (vorhanden != null) return vorhanden;
    final id = await _db.lagerplatzEinfuegenMit(
      txn,
      Lagerplatz(
        name: text,
        lagerortId: lagerortId,
        qrCode: CsvHelfer.leerZuNull(qrCode),
      ),
    );
    cache[schluessel] = id;
    return id;
  }

  // Liest eine ganze Zahl >= minimum, sonst Standard/Minimum + Hinweis.
  // Die Zeilennummer setzt die aufrufende Schleife ueber den lokalen Puffer.
  static int _zahl(
    String roh,
    int standard,
    int minimum,
    String feldName,
    List<String> hinweise,
  ) {
    final wert = int.tryParse(roh.trim());
    if (wert == null) {
      hinweise.add('$feldName fehlt/ungueltig, $standard verwendet.');
      return standard;
    }
    if (wert < minimum) {
      hinweise.add('$feldName war zu klein, $minimum verwendet.');
      return minimum;
    }
    return wert;
  }
}
