import 'package:get/get.dart';

import '../models/produkt.dart';
import '../services/datenbank_service.dart';

/// Verwaltet die Produktliste der Inventarverwaltung.
///
/// Der Controller laedt Produkte aus der lokalen Datenbank, verarbeitet die
/// Suche und setzt den Filter fuer niedrige Bestaende. Nach Aenderungen wird
/// die Liste neu geladen, damit UI und Datenbank denselben Stand zeigen.
class ProduktController extends GetxController {
  final _db = DatenbankService.instanz;
  final produkte = <Produkt>[].obs;
  final laedt = false.obs;
  final suchtext = ''.obs;
  final nurNiedrigeBestaende = false.obs;
  final fehlerText = ''.obs;

  /// Laedt die Produktliste automatisch beim Start des Controllers.
  @override
  void onInit() {
    super.onInit();
    produkteLaden();
  }

  /// Laedt die Liste mit aktuellem Suchtext und Filter neu.
  Future<void> produkteLaden() => _neuLaden();

  /// Liefert alle Produkte ohne Such- und Bestandsfilter.
  /// Wird vom CSV-Export verwendet, damit immer der komplette
  /// Datenbestand exportiert wird - unabhaengig davon, welche
  /// Filter gerade in der Inventar-Ansicht aktiv sind.
  Future<List<Produkt>> alleProdukteUngefiltert() => _db.alleProdukte();

  /// Setzt den Suchtext und laedt die Liste neu.
  Future<void> suchen(String text) async {
    suchtext.value = text;
    await _neuLaden();
  }

  /// Schaltet den Filter "nur niedrige Bestaende" und laedt neu.
  Future<void> filterNiedrigeBestaendeSetzen(bool wert) async {
    nurNiedrigeBestaende.value = wert;
    await _neuLaden();
  }

  /// Speichert ein neues Produkt und liefert die vergebene ID.
  Future<int> produktHinzufuegen(Produkt p) async {
    try {
      fehlerText.value = '';
      final id = await _db.produktEinfuegen(p);
      p.id = id;
      await _neuLaden();
      return id;
    } catch (e) {
      fehlerText.value = 'Speichern fehlgeschlagen: $e';
      rethrow;
    }
  }

  /// Speichert Aenderungen an einem bestehenden Produkt.
  Future<void> produktAktualisieren(Produkt p) async {
    try {
      fehlerText.value = '';
      await _db.produktAktualisieren(p);
      await _neuLaden();
    } catch (e) {
      fehlerText.value = 'Aktualisierung fehlgeschlagen: $e';
      rethrow;
    }
  }

  /// Loescht ein Produkt. Zugehoerige Ausleihen entfernt die Datenbank
  /// automatisch per ON DELETE CASCADE.
  Future<void> produktLoeschen(int id) async {
    try {
      fehlerText.value = '';
      await _db.produktLoeschen(id);
      await _neuLaden();
    } catch (e) {
      fehlerText.value = 'Loeschen fehlgeschlagen.';
      rethrow;
    }
  }

  /// Erhoeht die gespeicherte Stueckzahl um 1.
  ///
  /// Produkte ohne ID koennen noch nicht in der Datenbank stehen. In diesem
  /// Fall wird ohne Fehlermeldung abgebrochen.
  Future<void> stueckzahlErhoehen(Produkt p) async {
    if (p.id == null) return;
    try {
      fehlerText.value = '';
      await _db.stueckzahlErhoehen(produktId: p.id!);
      await _neuLaden();
    } catch (e) {
      fehlerText.value = 'Stueckzahl konnte nicht erhoeht werden.';
      rethrow;
    }
  }

  /// Verringert die Stueckzahl um 1 (Entnahme).
  /// Werte unter 0 verhindert die Datenbank mit MAX(0, ...).
  Future<void> stueckzahlVerringern(Produkt p) async {
    if (p.id == null) return;
    try {
      fehlerText.value = '';
      await _db.stueckzahlVerringern(produktId: p.id!);
      await _neuLaden();
    } catch (e) {
      fehlerText.value = 'Stueckzahl konnte nicht verringert werden.';
      rethrow;
    }
  }

  /// Setzt die Stueckzahl direkt auf einen vom Nutzer eingegebenen Wert.
  Future<void> stueckzahlSetzen(Produkt p, int neueZahl) async {
    if (p.id == null || neueZahl < 0) return;
    try {
      fehlerText.value = '';
      await _db.stueckzahlSetzen(produktId: p.id!, stueckzahl: neueZahl);
      await _neuLaden();
    } catch (e) {
      fehlerText.value = 'Stueckzahl konnte nicht gesetzt werden.';
      rethrow;
    }
  }

  /// Liste neu aus der Datenbank holen.
  /// Beruecksichtigt Suchtext und Bestandsfilter.
  Future<void> _neuLaden() async {
    laedt.value = true;
    fehlerText.value = '';
    try {
      final text = suchtext.value.trim();
      List<Produkt> liste;
      if (text.isNotEmpty) {
        liste = await _db.produkteSuchen(text);
      } else {
        liste = await _db.alleProdukte();
      }
      // Niedriger Bestand gilt nur, wenn die Stueckzahl kleiner als der
      // gespeicherte Mindestbestand ist. In der Oberflaeche heisst dieser
      // Wert Mindestmenge. Beispiel: 1 von 1 ist noch nicht niedrig.
      if (nurNiedrigeBestaende.value) {
        liste = liste.where((p) => p.istBestandNiedrig).toList();
      }
      produkte.assignAll(liste);
    } catch (e) {
      fehlerText.value = 'Laden fehlgeschlagen: $e';
    } finally {
      laedt.value = false;
    }
  }
}
