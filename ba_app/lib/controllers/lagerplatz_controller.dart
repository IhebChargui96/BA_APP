import 'package:get/get.dart';

import '../models/lagerplatz.dart';
import '../services/datenbank_service.dart';

/// Verwaltet Lagerplaetze und ihre optionalen QR-Codes.
///
/// Ein Lagerplatz beschreibt die genaue Position innerhalb eines Lagerorts,
/// zum Beispiel Kiste, Fach oder Schublade. Ein QR-Code gehoert dabei zum
/// Lagerplatz und nicht zu einem einzelnen Produkt.
class LagerplatzController extends GetxController {
  final lagerplaetze = <Lagerplatz>[].obs;
  final laedt = false.obs;
  final fehlerText = ''.obs;
  final _db = DatenbankService.instanz;

  /// Laedt die Lagerplaetze automatisch beim Start des Controllers.
  @override
  void onInit() {
    super.onInit();
    lagerplaetzeLaden();
  }

  /// Laedt alle Lagerplaetze aus der lokalen Datenbank.
  Future<void> lagerplaetzeLaden() async {
    laedt.value = true;
    fehlerText.value = '';
    try {
      lagerplaetze.assignAll(await _db.alleLagerplaetze());
    } catch (e) {
      fehlerText.value = 'Lagerplaetze konnten nicht geladen werden.';
    } finally {
      laedt.value = false;
    }
  }

  /// Laedt die Lagerplaetze eines bestimmten Lagerorts.
  ///
  /// Das wird im Formular genutzt, wenn erst ein Lagerort und danach der
  /// passende Lagerplatz ausgewaehlt wird.
  Future<List<Lagerplatz>> lagerplaetzeFuerLagerort(int lagerortId) async {
    try {
      return await _db.lagerplaetzeFuerLagerort(lagerortId);
    } catch (e) {
      fehlerText.value = 'Untergeordnete Lagerplaetze nicht geladen: $e';
      return [];
    }
  }

  /// Sucht einen Lagerplatz ueber einen gescannten QR-Code.
  ///
  /// Wenn der Code in der Datenbank nicht hinterlegt ist, wird null
  /// zurueckgegeben und die UI kann einen passenden Hinweis anzeigen.
  Future<Lagerplatz?> lagerplatzPerQrCode(String qrCode) async {
    final code = qrCode.trim();
    if (code.isEmpty) return null;
    try {
      return await _db.lagerplatzPerQrCode(code);
    } catch (e) {
      fehlerText.value = 'QR-Suche fehlgeschlagen: $e';
      return null;
    }
  }

  /// Speichert einen neuen Lagerplatz und prueft vorher den QR-Code.
  Future<int> lagerplatzHinzufuegen(Lagerplatz l) async {
    fehlerText.value = '';
    // Zusaetzliche Pruefung vor dem INSERT, damit bei doppeltem QR-Code
    // ein verstaendlicher Fehlertext angezeigt werden kann.
    if (await _qrCodeKollidiert(l)) {
      fehlerText.value = 'QR-Code ist bereits vergeben.';
      throw Exception('QR-Code bereits vergeben');
    }
    try {
      final id = await _db.lagerplatzEinfuegen(l);
      l.id = id;
      await lagerplaetzeLaden();
      return id;
    } catch (e) {
      fehlerText.value = 'Speichern fehlgeschlagen: $e';
      rethrow;
    }
  }

  /// Speichert Aenderungen an einem Lagerplatz.
  Future<void> lagerplatzAktualisieren(Lagerplatz l) async {
    fehlerText.value = '';
    if (await _qrCodeKollidiert(l)) {
      fehlerText.value = 'QR-Code ist bereits vergeben.';
      throw Exception('QR-Code bereits vergeben');
    }
    try {
      await _db.lagerplatzAktualisieren(l);
      await lagerplaetzeLaden();
    } catch (e) {
      fehlerText.value = 'Aktualisierung fehlgeschlagen: $e';
      rethrow;
    }
  }

  /// Loescht einen Lagerplatz, wenn keine Produkte mehr darauf verweisen.
  Future<void> lagerplatzLoeschen(int id) async {
    try {
      await _db.lagerplatzLoeschen(id);
      await lagerplaetzeLaden();
    } catch (e) {
      fehlerText.value =
          'Lagerplatz kann nicht geloescht werden, '
          'vermutlich sind Produkte zugeordnet.';
      rethrow;
    }
  }

  /// Prueft, ob der QR-Code bereits bei einem anderen Lagerplatz steht.
  ///
  /// Beim Bearbeiten wird der eigene Lagerplatz nicht als Konflikt gewertet.
  Future<bool> _qrCodeKollidiert(Lagerplatz l) async {
    final code = l.qrCode?.trim() ?? '';
    if (code.isEmpty) return false;
    final alle = await _db.alleLagerplaetze();
    for (final eintrag in alle) {
      final eingetragenerCode = (eintrag.qrCode ?? '').trim();
      if (eingetragenerCode == code && eintrag.id != l.id) {
        return true;
      }
    }
    return false;
  }
}
