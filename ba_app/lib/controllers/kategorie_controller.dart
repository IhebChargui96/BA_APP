import 'package:get/get.dart';

import '../models/kategorie.dart';
import '../services/datenbank_service.dart';

/// Verwaltet die Produktkategorien der App.
///
/// Kategorien dienen nur zur fachlichen Ordnung der Produkte. Die Pruefung
/// der Eingaben findet im Formular statt, damit der Controller schlank bleibt.
class KategorieController extends GetxController {
  final kategorien = <Kategorie>[].obs;
  final laedt = false.obs;
  final fehlerText = ''.obs;
  final _db = DatenbankService.instanz;

  /// Laedt die Kategorien automatisch beim Start des Controllers.
  @override
  void onInit() {
    super.onInit();
    kategorienLaden();
  }

  /// Laedt alle Kategorien aus der lokalen Datenbank.
  Future<void> kategorienLaden() async {
    laedt.value = true;
    fehlerText.value = '';
    try {
      kategorien.assignAll(await _db.alleKategorien());
    } catch (e) {
      fehlerText.value = 'Kategorien konnten nicht geladen werden.';
    } finally {
      laedt.value = false;
    }
  }

  /// Speichert eine neue Kategorie und liefert ihre Datenbank-ID.
  Future<int> kategorieHinzufuegen(Kategorie k) async {
    try {
      final id = await _db.kategorieEinfuegen(k);
      k.id = id;
      await kategorienLaden();
      return id;
    } catch (e) {
      fehlerText.value = 'Kategorie konnte nicht gespeichert werden.';
      rethrow;
    }
  }

  /// Speichert Aenderungen an einer bestehenden Kategorie.
  Future<void> kategorieAktualisieren(Kategorie k) async {
    try {
      await _db.kategorieAktualisieren(k);
      await kategorienLaden();
    } catch (e) {
      fehlerText.value = 'Kategorie konnte nicht aktualisiert werden.';
      rethrow;
    }
  }

  /// Loescht eine Kategorie, wenn sie nicht mehr von Produkten genutzt wird.
  Future<void> kategorieLoeschen(int id) async {
    try {
      await _db.kategorieLoeschen(id);
      await kategorienLaden();
    } catch (e) {
      // Haeufige Ursache: Produkte sind noch dieser Kategorie zugeordnet.
      fehlerText.value =
          'Kategorie konnte nicht geloescht werden. '
          'Vielleicht sind noch Produkte zugeordnet.';
      rethrow;
    }
  }
}
