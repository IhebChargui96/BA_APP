import 'package:get/get.dart';

import '../models/ausleihe.dart';
import '../services/datenbank_service.dart';

/// Verwaltet die Ausleihen der App.
///
/// Der Controller haelt die offenen Ausleihen als reaktive Liste und ruft
/// die passenden Datenbankmethoden zum Ausleihen, Verlaengern und
/// Zurueckgeben auf. Nach einer Aenderung wird die Liste neu geladen.
///
/// Die Ausleihe reduziert nicht direkt die gespeicherte Produktstueckzahl.
/// Die verfuegbare Menge wird aus Gesamtbestand minus offenen Ausleihen
/// berechnet. So bleibt der gespeicherte Bestand nachvollziehbar.
class AusleiheController extends GetxController {
  final DatenbankService _db = DatenbankService.instanz;

  final aktuelleAusleihen = <Ausleihe>[].obs;
  final laedt = false.obs;
  final fehlerText = ''.obs;

  /// Anzahl der aktuell offenen Ausleihen, deren Frist abgelaufen ist.
  int get anzahlUeberfaellig {
    return aktuelleAusleihen.where((a) => a.istUeberfaellig).length;
  }

  @override
  void onInit() {
    super.onInit();
    aktuelleAusleihenLaden();
  }

  /// Laedt alle offenen Ausleihen fuer die Uebersicht neu.
  Future<void> aktuelleAusleihenLaden() async {
    laedt.value = true;
    fehlerText.value = '';

    try {
      final liste = await _db.alleAktuellenAusleihen();
      aktuelleAusleihen.assignAll(liste);
    } catch (e) {
      fehlerText.value = 'Ausleihen konnten nicht geladen werden: $e';
    } finally {
      laedt.value = false;
    }
  }

  /// Liefert die komplette Ausleihhistorie.
  Future<List<Ausleihe>> alleAusleihen() async {
    try {
      fehlerText.value = '';
      return await _db.alleAusleihen();
    } catch (e) {
      fehlerText.value = 'Ausleihen konnten nicht geladen werden: $e';
      rethrow;
    }
  }

  /// Liefert die offenen Ausleihen zu einem bestimmten Produkt.
  Future<List<Ausleihe>> aktuelleAusleihenFuerProdukt(int produktId) async {
    try {
      return await _db.aktuelleAusleihenFuerProdukt(produktId);
    } catch (e) {
      fehlerText.value = 'Ausleihen fuer Produkt konnten nicht geladen werden.';
      rethrow;
    }
  }

  /// Liefert offene und bereits zurueckgegebene Ausleihen zu einem Produkt.
  Future<List<Ausleihe>> alleAusleihenFuerProdukt(int produktId) async {
    try {
      return await _db.alleAusleihenFuerProdukt(produktId);
    } catch (e) {
      fehlerText.value = 'Ausleih-Historie konnte nicht geladen werden.';
      rethrow;
    }
  }

  /// Summiert die aktuell ausgeliehene Menge eines Produkts.
  Future<int> offenAusgelieheneMengeFuerProdukt(int produktId) async {
    if (produktId <= 0) {
      throw Exception('Produkt-ID ist ungueltig.');
    }

    return _db.offeneAusleihMengeFuerProdukt(produktId);
  }

  /// Berechnet, wie viele Stueck eines Produkts noch verfuegbar sind.
  ///
  /// Negative Werte werden auf 0 begrenzt, falls Daten einmal nicht mehr
  /// sauber zusammenpassen.
  Future<int> verfuegbareMengeFuerProdukt(int produktId) async {
    if (produktId <= 0) {
      throw Exception('Produkt-ID ist ungueltig.');
    }

    final produkt = await _db.produktMitId(produktId);

    if (produkt == null) {
      throw Exception('Produkt wurde nicht gefunden.');
    }

    final offenAusgeliehen = await _db.offeneAusleihMengeFuerProdukt(produktId);

    final verfuegbar = produkt.stueckzahl - offenAusgeliehen;

    if (verfuegbar < 0) {
      return 0;
    }

    return verfuegbar;
  }

  /// Speichert eine neue Ausleihe, wenn die Menge noch verfuegbar ist.
  Future<void> ausleihen(Ausleihe ausleihe) async {
    if (ausleihe.produktId <= 0) {
      throw Exception('Produkt-ID fuer Ausleihe ist ungueltig.');
    }

    if (ausleihe.menge < 1) {
      throw Exception('Ausleihmenge muss mindestens 1 sein.');
    }

    if (ausleihe.vorname.trim().isEmpty || ausleihe.nachname.trim().isEmpty) {
      throw Exception('Vorname und Nachname muessen angegeben werden.');
    }

    final verfuegbar = await verfuegbareMengeFuerProdukt(ausleihe.produktId);

    if (ausleihe.menge > verfuegbar) {
      throw Exception('Es sind nur noch $verfuegbar Stueck verfuegbar.');
    }

    try {
      fehlerText.value = '';
      await _db.ausleiheEinfuegen(ausleihe);
      await aktuelleAusleihenLaden();
    } catch (e) {
      fehlerText.value = 'Ausleihe konnte nicht gespeichert werden: $e';
      rethrow;
    }
  }

  /// Setzt fuer eine offene Ausleihe ein neues Fristdatum.
  Future<void> verlaengern({
    required int ausleiheId,
    required DateTime neueFrist,
  }) async {
    if (ausleiheId <= 0) {
      throw Exception('Ausleihe-ID ist ungueltig.');
    }

    try {
      fehlerText.value = '';

      await _db.ausleiheVerlaengern(
        ausleiheId: ausleiheId,
        neueFrist: neueFrist.toIso8601String(),
      );

      await aktuelleAusleihenLaden();
    } catch (e) {
      fehlerText.value = 'Ausleihe konnte nicht verlaengert werden: $e';
      rethrow;
    }
  }

  /// Traegt das aktuelle Datum als Rueckgabedatum ein.
  Future<void> zurueckgeben(int ausleiheId) async {
    if (ausleiheId <= 0) {
      throw Exception('Ausleihe-ID ist ungueltig.');
    }

    try {
      fehlerText.value = '';

      await _db.ausleiheZurueckgeben(
        ausleiheId: ausleiheId,
        rueckgabedatum: DateTime.now().toIso8601String(),
      );

      await aktuelleAusleihenLaden();
    } catch (e) {
      fehlerText.value = 'Ausleihe konnte nicht zurueckgegeben werden: $e';
      rethrow;
    }
  }

  /// Loescht einen Ausleiheintrag dauerhaft.
  Future<void> ausleiheLoeschen(int ausleiheId) async {
    if (ausleiheId <= 0) {
      throw Exception('Ausleihe-ID ist ungueltig.');
    }

    try {
      fehlerText.value = '';

      await _db.ausleiheLoeschen(ausleiheId);
      await aktuelleAusleihenLaden();
    } catch (e) {
      fehlerText.value = 'Ausleihe konnte nicht geloescht werden: $e';
      rethrow;
    }
  }
}
