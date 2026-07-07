import 'package:get/get.dart';

import '../models/lagerplatz.dart';
import '../models/produkt.dart';
import '../services/datenbank_service.dart';

/// Laedt und verwaltet die Produkte eines einzelnen Lagerplatzes.
///
/// Der Controller wird verwendet, wenn ein Lagerplatz ueber die Liste, eine
/// ID oder einen QR-Code geoeffnet wird.
class LagerplatzInhaltController extends GetxController {
  final Lagerplatz lagerplatz;
  LagerplatzInhaltController({required this.lagerplatz});

  final produkte = <Produkt>[].obs;
  final laedt = false.obs;
  final fehlerText = ''.obs;
  final _db = DatenbankService.instanz;

  /// Laedt den Inhalt des Lagerplatzes automatisch beim Start des Controllers.
  @override
  void onInit() {
    super.onInit();
    produkteLaden();
  }

  /// Laedt alle Produkte, die diesem Lagerplatz zugeordnet sind.
  Future<void> produkteLaden() async {
    final id = lagerplatz.id;
    if (id == null) {
      fehlerText.value = 'Lagerplatz hat keine ID.';
      return;
    }
    laedt.value = true;
    fehlerText.value = '';
    try {
      produkte.assignAll(await _db.produkteAmLagerplatz(id));
    } catch (e) {
      fehlerText.value = 'Inhalt konnte nicht geladen werden: $e';
    }
    laedt.value = false;
  }

  /// Anzeigetext fuer die Anzahl der Produkte am Lagerplatz.
  String get produktAnzahlText =>
      produkte.length == 1 ? '1 Produkt' : '${produkte.length} Produkte';

  /// Gibt an, ob dem Lagerplatz ein QR-Code hinterlegt ist.
  bool get hatQrCode => (lagerplatz.qrCode ?? '').trim().isNotEmpty;

  /// Anzeigetext fuer den QR-Code oder ein Hinweis, wenn keiner hinterlegt ist.
  String get qrCodeText {
    final code = lagerplatz.qrCode?.trim() ?? '';
    return code.isEmpty ? 'kein QR-Code hinterlegt' : code;
  }
}
