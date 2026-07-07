import 'package:get/get.dart';

import '../models/lagerort.dart';
import '../services/datenbank_service.dart';

/// Verwaltet die Lagerorte der App, zum Beispiel Raum, Werkstatt oder Regal.
///
/// Die Pruefung von HsH-Raumcodes liegt im Validatoren-Helper. Dadurch kann
/// dieselbe Eingabepruefung im Formular wiederverwendet werden.
class LagerortController extends GetxController {
  final lagerorte = <Lagerort>[].obs;
  final laedt = false.obs;
  final fehlerText = ''.obs;
  final DatenbankService _db = DatenbankService.instanz;

  /// Laedt die Lagerorte automatisch beim Start des Controllers.
  @override
  void onInit() {
    super.onInit();
    lagerorteLaden();
  }

  /// Laedt alle Lagerorte alphabetisch sortiert aus der Datenbank.
  Future<void> lagerorteLaden() async {
    fehlerText.value = '';
    laedt.value = true;
    try {
      final liste = await _db.alleLagerorte();
      lagerorte.assignAll(liste);
    } catch (e) {
      fehlerText.value = 'Lagerorte laden fehlgeschlagen: $e';
    } finally {
      laedt.value = false;
    }
  }

  /// Speichert einen neuen Lagerort und liefert die vergebene ID.
  Future<int> lagerortHinzufuegen(Lagerort l) async {
    try {
      fehlerText.value = '';
      final id = await _db.lagerortEinfuegen(l);
      l.id = id;
      await lagerorteLaden();
      return id;
    } catch (e) {
      fehlerText.value = 'Lagerort konnte nicht gespeichert werden.';
      rethrow;
    }
  }

  /// Speichert Aenderungen an einem bestehenden Lagerort.
  Future<void> lagerortAktualisieren(Lagerort l) async {
    try {
      fehlerText.value = '';
      await _db.lagerortAktualisieren(l);
      await lagerorteLaden();
    } catch (e) {
      fehlerText.value = 'Lagerort konnte nicht aktualisiert werden.';
      rethrow;
    }
  }

  /// Loescht einen Lagerort, wenn keine Lagerplaetze mehr zugeordnet sind.
  ///
  /// Die eigentliche Absicherung erfolgt in der Datenbank ueber die
  /// Fremdschluesselbeziehung.
  Future<void> lagerortLoeschen(int id) async {
    try {
      fehlerText.value = '';
      await _db.lagerortLoeschen(id);
      await lagerorteLaden();
    } catch (e) {
      fehlerText.value =
          'Lagerort kann nicht geloescht werden, '
          'vermutlich sind Lagerplaetze zugeordnet.';
      rethrow;
    }
  }
}
