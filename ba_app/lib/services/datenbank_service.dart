import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ausleihe.dart';
import '../models/kategorie.dart';
import '../models/lagerort.dart';
import '../models/lagerplatz.dart';
import '../models/produkt.dart';

/// SQLite-Zugriff fuer InventarScan.
///
/// Hinweis:
/// Der Dateiname bleibt aus Kompatibilitaetsgruenden electrostock.db,
/// weil fruehere App-Versionen diese Datei bereits verwendet haben.
///
/// Alle SQL-Zugriffe liegen zentral in dieser Klasse. Dadurch bleibt die
/// Benutzeroberflaeche einfacher und muss keine SQL-Befehle kennen.
class DatenbankService {
  // Singleton: Der Datenbankzugriff wird nur einmal in der App erzeugt.
  static final DatenbankService instanz = DatenbankService._();
  DatenbankService._();

  Database? _datenbank;

  /// Oeffnet die lokale SQLite-Datenbank oder liefert die bereits geoeffnete Instanz.
  Future<Database> get datenbank async {
    if (_datenbank != null) return _datenbank!;
    final pfad = join(await getDatabasesPath(), 'electrostock.db');
    _datenbank = await openDatabase(
      pfad,
      version: 3,
      onConfigure: (db) async {
        // Foreign Keys muessen bei SQLite explizit eingeschaltet werden.
        // Sonst werden FOREIGN KEY Constraints ignoriert.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE kategorie (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE lagerort (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            beschreibung TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE lagerplatz (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            qrCode TEXT UNIQUE,
            lagerortId INTEGER,
            FOREIGN KEY (lagerortId) REFERENCES lagerort (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE produkt (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            titel TEXT NOT NULL,
            beschreibung TEXT,
            stueckzahl INTEGER NOT NULL DEFAULT 1,
            mindestBestand INTEGER NOT NULL DEFAULT 1,
            fotoPfad TEXT,
            kategorieId INTEGER,
            lagerplatzId INTEGER,
            ringFarben TEXT,
            widerstandsWert TEXT,
            toleranz TEXT,
            erstelltAm TEXT NOT NULL,
            aktualisiertAm TEXT NOT NULL,
            FOREIGN KEY (kategorieId) REFERENCES kategorie (id),
            FOREIGN KEY (lagerplatzId) REFERENCES lagerplatz (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE ausleihe (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            produktId INTEGER NOT NULL,
            vorname TEXT NOT NULL,
            nachname TEXT NOT NULL,
            menge INTEGER NOT NULL DEFAULT 1,
            ausleihdatum TEXT NOT NULL,
            fristdatum TEXT NOT NULL,
            rueckgabedatum TEXT,
            notiz TEXT,
            FOREIGN KEY (produktId) REFERENCES produkt (id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, alt, neu) async {
        if (alt < 2) {
          await db.execute(
            'ALTER TABLE produkt ADD COLUMN mindestBestand INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (alt < 3) {
          await db.execute('''
            CREATE TABLE ausleihe (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              produktId INTEGER NOT NULL,
              vorname TEXT NOT NULL,
              nachname TEXT NOT NULL,
              menge INTEGER NOT NULL DEFAULT 1,
              ausleihdatum TEXT NOT NULL,
              fristdatum TEXT NOT NULL,
              rueckgabedatum TEXT,
              notiz TEXT,
              FOREIGN KEY (produktId) REFERENCES produkt (id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
    return _datenbank!;
  }

  // --- Kategorien ---
  // Speichert eine neue Kategorie und liefert die vergebene ID.
  Future<int> kategorieEinfuegen(Kategorie k) async {
    final db = await datenbank;
    return db.insert('kategorie', k.toMap());
  }

  // Speichert eine Kategorie innerhalb einer laufenden Transaktion (CSV-Restore).
  Future<int> kategorieEinfuegenMit(Transaction txn, Kategorie k) async {
    return txn.insert('kategorie', k.toMap());
  }

  // Liefert alle Kategorien alphabetisch sortiert.
  Future<List<Kategorie>> alleKategorien() async {
    final db = await datenbank;
    final rows = await db.query('kategorie', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => Kategorie.fromMap(r)).toList();
  }

  // Aktualisiert eine bestehende Kategorie.
  Future<int> kategorieAktualisieren(Kategorie k) async {
    final db = await datenbank;
    return db.update(
      'kategorie',
      k.toMap(),
      where: 'id = ?',
      whereArgs: [k.id],
    );
  }

  // Loescht eine Kategorie ueber ihre ID.
  Future<int> kategorieLoeschen(int id) async {
    final db = await datenbank;
    return db.delete('kategorie', where: 'id = ?', whereArgs: [id]);
  }

  // --- Lagerorte ---
  // Speichert einen neuen Lagerort und liefert die vergebene ID.
  Future<int> lagerortEinfuegen(Lagerort l) async {
    final db = await datenbank;
    return db.insert('lagerort', l.toMap());
  }

  // Speichert einen Lagerort innerhalb einer laufenden Transaktion (CSV-Restore).
  Future<int> lagerortEinfuegenMit(Transaction txn, Lagerort l) async {
    return txn.insert('lagerort', l.toMap());
  }

  // Liefert alle Lagerorte alphabetisch sortiert.
  Future<List<Lagerort>> alleLagerorte() async {
    final db = await datenbank;
    final rows = await db.query('lagerort', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => Lagerort.fromMap(r)).toList();
  }

  // Aktualisiert einen bestehenden Lagerort.
  Future<int> lagerortAktualisieren(Lagerort l) async {
    final db = await datenbank;
    return db.update('lagerort', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
  }

  // Loescht einen Lagerort ueber seine ID.
  Future<int> lagerortLoeschen(int id) async {
    final db = await datenbank;
    return db.delete('lagerort', where: 'id = ?', whereArgs: [id]);
  }

  // --- Lagerplaetze ---
  // Speichert einen neuen Lagerplatz und liefert die vergebene ID.
  Future<int> lagerplatzEinfuegen(Lagerplatz l) async {
    final db = await datenbank;
    return db.insert('lagerplatz', l.toMap());
  }

  // Speichert einen Lagerplatz innerhalb einer laufenden Transaktion (CSV-Restore).
  Future<int> lagerplatzEinfuegenMit(Transaction txn, Lagerplatz l) async {
    return txn.insert('lagerplatz', l.toMap());
  }

  // Liefert alle Lagerplaetze alphabetisch sortiert.
  Future<List<Lagerplatz>> alleLagerplaetze() async {
    final db = await datenbank;
    final rows = await db.query('lagerplatz', orderBy: 'name COLLATE NOCASE');
    return rows.map((r) => Lagerplatz.fromMap(r)).toList();
  }

  // Liefert die Lagerplaetze eines bestimmten Lagerorts.
  Future<List<Lagerplatz>> lagerplaetzeFuerLagerort(int lagerortId) async {
    final db = await datenbank;
    final rows = await db.query(
      'lagerplatz',
      where: 'lagerortId = ?',
      whereArgs: [lagerortId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map((r) => Lagerplatz.fromMap(r)).toList();
  }

  // Sucht einen Lagerplatz ueber seinen QR-Code, oder null.
  Future<Lagerplatz?> lagerplatzPerQrCode(String qrCode) async {
    final db = await datenbank;
    final rows = await db.query(
      'lagerplatz',
      where: 'qrCode = ?',
      whereArgs: [qrCode],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Lagerplatz.fromMap(rows.first);
  }

  // Aktualisiert einen bestehenden Lagerplatz.
  Future<int> lagerplatzAktualisieren(Lagerplatz l) async {
    final db = await datenbank;
    return db.update(
      'lagerplatz',
      l.toMap(),
      where: 'id = ?',
      whereArgs: [l.id],
    );
  }

  // Loescht einen Lagerplatz ueber seine ID.
  Future<int> lagerplatzLoeschen(int id) async {
    final db = await datenbank;
    return db.delete('lagerplatz', where: 'id = ?', whereArgs: [id]);
  }

  // --- Produkte ---
  // Speichert ein neues Produkt und setzt die Zeitstempel.
  Future<int> produktEinfuegen(Produkt p) async {
    final db = await datenbank;
    final jetzt = DateTime.now().toIso8601String();
    if (p.erstelltAm.trim().isEmpty) {
      p.erstelltAm = jetzt;
    }
    p.aktualisiertAm = jetzt;
    return db.insert('produkt', _produktMapFuerSpeichern(p));
  }

  // Stellt ein Produkt beim CSV-Restore mit seinen Zeitstempeln wieder her.
  Future<int> produktWiederherstellenMit(Transaction txn, Produkt p) async {
    return txn.insert('produkt', _produktMapFuerRestore(p));
  }

  // Liefert das Produkt zu einer ID, oder null.
  Future<Produkt?> produktMitId(int id) async {
    final db = await datenbank;
    final rows = await db.query(
      'produkt',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Produkt.fromMap(rows.first);
  }

  // Liefert alle Produkte alphabetisch nach Titel sortiert.
  Future<List<Produkt>> alleProdukte() async {
    final db = await datenbank;
    final rows = await db.query('produkt', orderBy: 'titel COLLATE NOCASE');
    return rows.map((r) => Produkt.fromMap(r)).toList();
  }

  // Sucht Produkte ueber Titel, Beschreibung, Wert, Ringe, Kategorie, Lagerplatz und Lagerort.
  Future<List<Produkt>> produkteSuchen(String suchtext) async {
    final text = suchtext.trim();
    if (text.isEmpty) return alleProdukte();
    final db = await datenbank;
    final muster = '%$text%';
    final rows = await db.rawQuery(
      'SELECT produkt.* FROM produkt '
      'LEFT JOIN kategorie ON produkt.kategorieId = kategorie.id '
      'LEFT JOIN lagerplatz ON produkt.lagerplatzId = lagerplatz.id '
      'LEFT JOIN lagerort ON lagerplatz.lagerortId = lagerort.id '
      'WHERE produkt.titel LIKE ? '
      'OR produkt.beschreibung LIKE ? '
      'OR produkt.widerstandsWert LIKE ? '
      'OR produkt.ringFarben LIKE ? '
      'OR kategorie.name LIKE ? '
      'OR lagerplatz.name LIKE ? '
      'OR lagerort.name LIKE ? '
      'ORDER BY produkt.titel COLLATE NOCASE',
      [muster, muster, muster, muster, muster, muster, muster],
    );
    return rows.map((r) => Produkt.fromMap(r)).toList();
  }

  // Liefert die Produkte an einem bestimmten Lagerplatz.
  Future<List<Produkt>> produkteAmLagerplatz(int lagerplatzId) async {
    final db = await datenbank;
    final rows = await db.query(
      'produkt',
      where: 'lagerplatzId = ?',
      whereArgs: [lagerplatzId],
      orderBy: 'titel COLLATE NOCASE',
    );
    return rows.map((r) => Produkt.fromMap(r)).toList();
  }

  // Liefert Produkte, deren Stueckzahl unter dem Mindestbestand liegt.
  Future<List<Produkt>> produkteMitNiedrigemBestand() async {
    final db = await datenbank;
    final rows = await db.query(
      'produkt',
      where: 'stueckzahl < mindestBestand',
      orderBy: 'titel COLLATE NOCASE',
    );
    return rows.map((r) => Produkt.fromMap(r)).toList();
  }

  // Aktualisiert ein Produkt und setzt den Aktualisierungs-Zeitstempel.
  Future<int> produktAktualisieren(Produkt p) async {
    if (p.id == null) {
      return 0;
    }
    final db = await datenbank;
    p.aktualisiertAm = DateTime.now().toIso8601String();
    return db.update(
      'produkt',
      _produktMapFuerSpeichern(p),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  // Loescht ein Produkt. Zugehoerige Ausleihen entfernt die Datenbank per ON DELETE CASCADE.
  Future<int> produktLoeschen(int id) async {
    final db = await datenbank;
    return db.delete('produkt', where: 'id = ?', whereArgs: [id]);
  }

  // Erhoeht die Stueckzahl eines Produkts um die angegebene Menge.
  Future<void> stueckzahlErhoehen({
    required int produktId,
    int menge = 1,
  }) async {
    if (menge <= 0) return;
    final db = await datenbank;
    await db.rawUpdate(
      'UPDATE produkt SET stueckzahl = stueckzahl + ?, aktualisiertAm = ? WHERE id = ?',
      [menge, DateTime.now().toIso8601String(), produktId],
    );
  }

  // Verringert die Stueckzahl. MAX(0, ...) in der SQL verhindert negative Werte.
  Future<void> stueckzahlVerringern({
    required int produktId,
    int menge = 1,
  }) async {
    if (menge <= 0) return;
    final db = await datenbank;
    await db.rawUpdate(
      'UPDATE produkt SET stueckzahl = MAX(0, stueckzahl - ?), aktualisiertAm = ? WHERE id = ?',
      [menge, DateTime.now().toIso8601String(), produktId],
    );
  }

  // Setzt die Stueckzahl direkt. Negative Werte werden auf 0 begrenzt.
  Future<void> stueckzahlSetzen({
    required int produktId,
    required int stueckzahl,
  }) async {
    final wert = stueckzahl < 0 ? 0 : stueckzahl;
    final db = await datenbank;
    await db.rawUpdate(
      'UPDATE produkt SET stueckzahl = ?, aktualisiertAm = ? WHERE id = ?',
      [wert, DateTime.now().toIso8601String(), produktId],
    );
  }

  // --- Ausleihen ---
  // Speichert eine neue Ausleihe.
  Future<int> ausleiheEinfuegen(Ausleihe a) async {
    final db = await datenbank;
    return db.insert('ausleihe', a.toMap());
  }

  // Stellt eine Ausleihe beim CSV-Restore wieder her (neue ID).
  Future<int> ausleiheWiederherstellenMit(Transaction txn, Ausleihe a) async {
    final map = a.toMap();
    map.remove('id');
    return txn.insert('ausleihe', map);
  }

  // Summiert die offen ausgeliehene Menge eines Produkts (ohne zurueckgegebene).
  Future<int> offeneAusleihMengeFuerProdukt(int produktId) async {
    final db = await datenbank;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(menge), 0) AS summe
      FROM ausleihe
      WHERE produktId = ?
        AND (rueckgabedatum IS NULL OR TRIM(rueckgabedatum) = '')
      ''',
      [produktId],
    );
    final wert = rows.first['summe'];
    if (wert is int) {
      return wert;
    }
    if (wert is num) {
      return wert.toInt();
    }
    return int.tryParse('$wert') ?? 0;
  }

  // Liefert die komplette Ausleihhistorie, neueste zuerst.
  Future<List<Ausleihe>> alleAusleihen() async {
    final db = await datenbank;
    final rows = await db.query(
      'ausleihe',
      orderBy: 'ausleihdatum DESC, id DESC',
    );
    return rows.map((r) => Ausleihe.fromMap(r)).toList();
  }

  // Liefert offene und zurueckgegebene Ausleihen eines Produkts.
  Future<List<Ausleihe>> alleAusleihenFuerProdukt(int produktId) async {
    final db = await datenbank;
    final rows = await db.query(
      'ausleihe',
      where: 'produktId = ?',
      whereArgs: [produktId],
      orderBy: 'ausleihdatum DESC',
    );
    return rows.map((r) => Ausleihe.fromMap(r)).toList();
  }

  // Liefert die offenen Ausleihen eines Produkts, nach Frist sortiert.
  Future<List<Ausleihe>> aktuelleAusleihenFuerProdukt(int produktId) async {
    final db = await datenbank;
    final rows = await db.query(
      'ausleihe',
      where:
          'produktId = ? AND (rueckgabedatum IS NULL OR TRIM(rueckgabedatum) = \'\')',
      whereArgs: [produktId],
      orderBy: 'fristdatum ASC',
    );
    return rows.map((r) => Ausleihe.fromMap(r)).toList();
  }

  // Liefert alle offenen Ausleihen, nach Frist sortiert.
  Future<List<Ausleihe>> alleAktuellenAusleihen() async {
    final db = await datenbank;
    final rows = await db.query(
      'ausleihe',
      where: 'rueckgabedatum IS NULL OR TRIM(rueckgabedatum) = \'\'',
      orderBy: 'fristdatum ASC',
    );
    return rows.map((r) => Ausleihe.fromMap(r)).toList();
  }

  // Setzt ein neues Fristdatum fuer eine Ausleihe.
  Future<int> ausleiheVerlaengern({
    required int ausleiheId,
    required String neueFrist,
  }) async {
    final db = await datenbank;
    return db.update(
      'ausleihe',
      {'fristdatum': neueFrist},
      where: 'id = ?',
      whereArgs: [ausleiheId],
    );
  }

  // Traegt das Rueckgabedatum einer Ausleihe ein.
  Future<int> ausleiheZurueckgeben({
    required int ausleiheId,
    required String rueckgabedatum,
  }) async {
    final db = await datenbank;
    return db.update(
      'ausleihe',
      {'rueckgabedatum': rueckgabedatum},
      where: 'id = ?',
      whereArgs: [ausleiheId],
    );
  }

  // Loescht eine Ausleihe ueber ihre ID.
  Future<int> ausleiheLoeschen(int id) async {
    final db = await datenbank;
    return db.delete('ausleihe', where: 'id = ?', whereArgs: [id]);
  }

  // --- CSV-Restore ---
  /// Fuehrt zusammenhaengende Datenbankarbeiten in einer SQLite-Transaktion aus.
  Future<T> inTransaktion<T>(Future<T> Function(Transaction txn) aktion) async {
    final db = await datenbank;
    return db.transaction<T>(aktion);
  }

  /// Loescht den Datenbestand fuer einen CSV-Import innerhalb derselben Transaktion.
  Future<void> alleDatenLoeschenMit(Transaction txn) async {
    // Reihenfolge ist wichtig:
    // Erst Ausleihen, dann Produkte, danach Lagerplaetze, Lagerorte
    // und Kategorien. Dadurch werden Fremdschluessel nicht verletzt.
    await txn.delete('ausleihe');
    await txn.delete('produkt');
    await txn.delete('lagerplatz');
    await txn.delete('lagerort');
    await txn.delete('kategorie');
  }

  // Baut die Speicher-Map eines Produkts. Begrenzt Stueckzahl und
  // Mindestbestand und entfernt die ID, damit SQLite sie vergibt.
  Map<String, Object?> _produktMapFuerSpeichern(Produkt p) {
    if (p.stueckzahl < 0) {
      p.stueckzahl = 0;
    }
    if (p.mindestBestand < 1) {
      p.mindestBestand = 1;
    }
    final map = p.toMap();
    // Bei INSERT und UPDATE wird die ID ueber whereArgs bzw. SQLite vergeben.
    map.remove('id');
    return map;
  }

  // Baut die Restore-Map eines Produkts und ergaenzt fehlende Zeitstempel.
  Map<String, Object?> _produktMapFuerRestore(Produkt p) {
    final jetzt = DateTime.now().toIso8601String();
    if (p.erstelltAm.trim().isEmpty) {
      p.erstelltAm = jetzt;
    }
    if (p.aktualisiertAm.trim().isEmpty) {
      p.aktualisiertAm = jetzt;
    }
    final map = _produktMapFuerSpeichern(p);
    // Der Foto-Pfad wird so uebernommen, wie ihn der CSV-Import liefert.
    // Der Import prueft vorher, ob die Datei auf diesem Geraet existiert.
    // Nur dann bleibt der Verweis erhalten  ein Restore auf demselben
    // Geraet behaelt damit die Fotos, fremde Pfade verwirft der Import.
    return map;
  }

  /// Schliesst die Datenbank, zum Beispiel beim Testen oder beim Neustart der App.
  Future<void> schliessen() async {
    await _datenbank?.close();
    _datenbank = null;
  }
}
