import 'package:get/get.dart';

import '../models/produkt.dart';
import '../services/datenbank_service.dart';
import 'ausleihe_controller.dart';
import 'kategorie_controller.dart';
import 'lagerort_controller.dart';
import 'lagerplatz_controller.dart';

/// Liefert Kennzahlen fuer den Statistik-Screen.
///
/// Die Produktliste wird hier direkt und ungefiltert aus der Datenbank
/// geladen. Der ProduktController kann gerade durch Suche oder Filter nur
/// einen Teil des Inventars anzeigen. Fuer Kennzahlen muss aber der gesamte
/// Datenbestand betrachtet werden.
///
/// Wichtige Rechnungen:
/// - Gesamtbestand = Summe aller Produktstueckzahlen
/// - Verliehene Stueck = Summe der offenen Ausleihmengen
/// - Verfuegbar = Gesamtbestand minus verliehene Stueck
class StatistikController extends GetxController {
  final DatenbankService _db = DatenbankService.instanz;

  // Ungefilterte Produktliste nur fuer die Statistik.
  final produkteGesamt = <Produkt>[].obs;
  final laedtProdukte = false.obs;
  final fehlerText = ''.obs;

  final KategorieController _kategorien =
      Get.isRegistered<KategorieController>()
      ? Get.find<KategorieController>()
      : Get.put(KategorieController());
  final LagerortController _lagerorte = Get.isRegistered<LagerortController>()
      ? Get.find<LagerortController>()
      : Get.put(LagerortController());
  final LagerplatzController _lagerplaetze =
      Get.isRegistered<LagerplatzController>()
      ? Get.find<LagerplatzController>()
      : Get.put(LagerplatzController());
  final AusleiheController _ausleihen = Get.isRegistered<AusleiheController>()
      ? Get.find<AusleiheController>()
      : Get.put(AusleiheController());

  /// Laedt die Statistik-Daten automatisch beim Start des Controllers.
  @override
  void onInit() {
    super.onInit();
    datenAktualisieren();
  }

  /// Laedt alle Daten neu, aus denen die Kennzahlen berechnet werden.
  Future<void> datenAktualisieren() async {
    await Future.wait([
      _produkteGesamtLaden(),
      _kategorien.kategorienLaden(),
      _lagerorte.lagerorteLaden(),
      _lagerplaetze.lagerplaetzeLaden(),
      _ausleihen.aktuelleAusleihenLaden(),
    ]);
  }

  /// Laedt alle Produkte ohne Such- oder Bestandsfilter.
  Future<void> _produkteGesamtLaden() async {
    laedtProdukte.value = true;
    fehlerText.value = '';
    try {
      produkteGesamt.assignAll(await _db.alleProdukte());
    } catch (e) {
      fehlerText.value = 'Produkte konnten nicht geladen werden.';
    } finally {
      laedtProdukte.value = false;
    }
  }

  /// Gesamt-Ladezustand fuer den Statistik-Screen.
  bool get laedt {
    return laedtProdukte.value ||
        _kategorien.laedt.value ||
        _lagerorte.laedt.value ||
        _lagerplaetze.laedt.value ||
        _ausleihen.laedt.value;
  }

  /// Anzahl aller Produkte im Inventar.
  int get anzahlProdukte => produkteGesamt.length;

  /// Summe der gespeicherten Stueckzahlen aller Produkte.
  int get gesamtStueckzahl {
    return produkteGesamt.fold(
      0,
      (summe, produkt) => summe + produkt.stueckzahl,
    );
  }

  /// Anzahl der angelegten Kategorien.
  int get anzahlKategorien => _kategorien.kategorien.length;

  /// Anzahl der angelegten Lagerorte.
  int get anzahlLagerorte => _lagerorte.lagerorte.length;

  /// Anzahl der angelegten Lagerplaetze.
  int get anzahlLagerplaetze => _lagerplaetze.lagerplaetze.length;

  /// Anzahl der Produkte, deren Stueckzahl unter dem Mindestbestand liegt.
  /// In der Oberflaeche wird dieser Wert als Mindestmenge angezeigt.
  int get anzahlNiedrigerBestand {
    return produkteGesamt.where((produkt) => produkt.istBestandNiedrig).length;
  }

  /// Anzahl der aktuell offenen Ausleihen.
  int get anzahlOffeneAusleihen => _ausleihen.aktuelleAusleihen.length;

  /// Anzahl der offenen Ausleihen mit abgelaufener Frist.
  int get anzahlUeberfaellig {
    return _ausleihen.aktuelleAusleihen
        .where((ausleihe) => ausleihe.istUeberfaellig)
        .length;
  }

  /// Summe aller aktuell ausgeliehenen Stueckzahlen.
  int get verlieheneStueckzahl {
    return _ausleihen.aktuelleAusleihen.fold(
      0,
      (summe, ausleihe) => summe + ausleihe.menge,
    );
  }

  /// Bestand, der nach Abzug der offenen Ausleihen verfuegbar ist.
  int get verfuegbareStueckzahl {
    final wert = gesamtStueckzahl - verlieheneStueckzahl;
    return wert < 0 ? 0 : wert;
  }

  /// Anteil der ausgeliehenen Stuecke am Gesamtbestand.
  double get anteilVerliehen {
    if (gesamtStueckzahl <= 0) {
      return 0;
    }
    return verlieheneStueckzahl / gesamtStueckzahl;
  }

  /// Anteil der Produkte mit niedrigem Bestand.
  double get anteilKritisch {
    if (anzahlProdukte <= 0) {
      return 0;
    }
    return anzahlNiedrigerBestand / anzahlProdukte;
  }
}
