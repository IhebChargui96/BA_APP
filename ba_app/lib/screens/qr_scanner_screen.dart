// QR-Code-Scanner fuer Lagerplaetze.
// Der Screen kann einen Code zurueckgeben oder direkt den passenden Lagerplatz suchen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/lagerplatz_controller.dart';
import '../models/lagerplatz.dart';
import 'lagerplatz_inhalt_screen.dart';

/// Scanansicht fuer QR-Codes von Lagerplaetzen.
class QrScannerScreen extends StatefulWidget {
  /// Wenn true, wird der gescannte QR-Code direkt zurueckgegeben
  /// (zum Zuweisen eines QR-Codes zu einem Lagerplatz).
  /// Sonst wird der QR-Code als Suche behandelt.
  final bool returnRawValue;
  const QrScannerScreen({super.key, this.returnRawValue = false});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final LagerplatzController _lagerplatzController;
  bool _wirdVerarbeitet = false;
  String? _letzterCode;

  // Registriert den LagerplatzController beim Start des Screens.
  @override
  void initState() {
    super.initState();
    _lagerplatzController = Get.isRegistered<LagerplatzController>()
        ? Get.find<LagerplatzController>()
        : Get.put(LagerplatzController());
  }

  // Gibt den Kamera-Scanner beim Schliessen frei.
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // Kamera-Callback: ersten brauchbaren Code lesen, Scanner stoppen und
  // je nach Modus den Code zurueckgeben oder den Lagerplatz suchen.
  // Das _wirdVerarbeitet-Flag verhindert doppelte Verarbeitung.
  Future<void> _qrCodeErkannt(BarcodeCapture capture) async {
    if (_wirdVerarbeitet || capture.barcodes.isEmpty) return;
    final code = _erstenCodeLesen(capture);
    if (code == null) return;
    setState(() {
      _wirdVerarbeitet = true;
      _letzterCode = code;
    });
    await _scannerController.stop();
    if (widget.returnRawValue) {
      Get.back(result: code);
      return;
    }
    await _lagerplatzSuchen(code);
  }

  /// Liefert den ersten nicht-leeren rawValue aus der Capture,
  /// oder null falls keiner brauchbar ist.
  String? _erstenCodeLesen(BarcodeCapture capture) {
    return capture.barcodes
        .map((b) => b.rawValue?.trim())
        .where((w) => w != null && w.isNotEmpty)
        .firstOrNull;
  }

  // Sucht den Lagerplatz zum Code und oeffnet dessen Inhalts-Screen.
  Future<void> _lagerplatzSuchen(String code) async {
    final Lagerplatz? lagerplatz = await _lagerplatzController
        .lagerplatzPerQrCode(code);
    if (!mounted) return;
    if (lagerplatz == null) {
      await _lagerplatzNichtGefunden(code);
      return;
    }
    Get.off(() => LagerplatzInhaltScreen(lagerplatz: lagerplatz));
  }

  // Meldung anzeigen und den Scanner fuer den naechsten Versuch starten.
  Future<void> _lagerplatzNichtGefunden(String code) async {
    Get.snackbar(
      'Nicht gefunden',
      'Kein Lagerplatz mit diesem QR-Code: $code',
      snackPosition: SnackPosition.BOTTOM,
    );
    setState(() => _wirdVerarbeitet = false);
    await _scannerController.start();
  }

  // Setzt den Zustand zurueck und startet die Kamera neu.
  Future<void> _erneutScannen() async {
    setState(() {
      _wirdVerarbeitet = false;
      _letzterCode = null;
    });
    await _scannerController.start();
  }

  /// Fallback, wenn der QR-Code beschaedigt ist oder nicht scannt:
  /// Der Lagerplatz wird ueber seine angezeigte ID gesucht.
  Future<void> _lagerplatzIdEingeben() async {
    final formKey = GlobalKey<FormState>();
    // Kein TextEditingController im Dialog.
    // Ein manuell entsorgter Controller hat frueher waehrend der
    // Dialog-Schlussanimation zum _dependents.isEmpty-Absturz gefuehrt.
    // Fuer ein einzelnes Zahlenfeld reicht initialValue + onChanged.
    String idEingabe = '';
    void absenden(BuildContext dialogContext) {
      if (formKey.currentState?.validate() != true) {
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(dialogContext).pop(int.tryParse(idEingabe.trim()));
    }

    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Lagerplatz-ID eingeben'),
          content: Form(
            key: formKey,
            child: TextFormField(
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID des Lagerplatzes',
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (text) {
                idEingabe = text;
              },
              validator: (text) {
                final wert = int.tryParse((text ?? '').trim());
                if (wert == null || wert <= 0) {
                  return 'Bitte eine gueltige Lagerplatz-ID eingeben.';
                }
                return null;
              },
              onFieldSubmitted: (_) => absenden(dialogContext),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => absenden(dialogContext),
              child: const Text('Anzeigen'),
            ),
          ],
        );
      },
    );
    if (id == null || id <= 0) return;
    await _lagerplatzPerIdSuchen(id);
  }

  // Sucht den Lagerplatz ueber seine angezeigte ID.
  // Laedt die Liste bei Bedarf nach, damit der Fallback auch direkt
  // nach dem App-Start funktioniert.
  Future<void> _lagerplatzPerIdSuchen(int id) async {
    if (_lagerplatzController.lagerplaetze.isEmpty) {
      await _lagerplatzController.lagerplaetzeLaden();
    }
    final lagerplatz = _lagerplatzController.lagerplaetze
        .where((l) => l.id == id)
        .firstOrNull;
    if (!mounted) return;
    if (lagerplatz == null) {
      Get.snackbar(
        'Nicht gefunden',
        'Kein Lagerplatz mit ID $id.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.off(() => LagerplatzInhaltScreen(lagerplatz: lagerplatz));
  }

  // Baut die Scan-Ansicht mit Kamera, Zielrahmen, Hinweis und Lade-Anzeige auf.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _qrCodeErkannt,
          ),
          _scanRahmen(),
          _hinweisUnten(),
          if (_wirdVerarbeitet) _ladeOverlay(),
        ],
      ),
    );
  }

  // App-Leiste mit Taschenlampe und Kamera-Wechsel.
  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: Text(
        widget.returnRawValue ? 'QR-Code zuweisen' : 'QR-Code scannen',
      ),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          tooltip: 'Taschenlampe',
          icon: const Icon(Icons.flashlight_on),
          onPressed: _scannerController.toggleTorch,
        ),
        IconButton(
          tooltip: 'Kamera wechseln',
          icon: const Icon(Icons.cameraswitch),
          onPressed: _scannerController.switchCamera,
        ),
      ],
    );
  }

  // Gruener Zielrahmen in der Bildmitte.
  Widget _scanRahmen() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // Hinweistext unten, der ID-Fallback-Knopf und der letzte Code.
  Widget _hinweisUnten() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.returnRawValue
                  ? 'QR-Code in den Rahmen halten.\nDer Code wird uebernommen.'
                  : 'QR-Code des Lagerplatzes scannen.\n'
                        'Danach wird der Lagerplatz gesucht.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          if (!widget.returnRawValue) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _lagerplatzIdEingeben,
              icon: const Icon(Icons.keyboard),
              label: const Text('QR geht nicht? ID eingeben'),
            ),
          ],
          if (_letzterCode != null) ...[
            const SizedBox(height: 8),
            Text(
              'Letzter Code: $_letzterCode',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // Dunkle Lade-Anzeige, waehrend ein Code verarbeitet wird.
  Widget _ladeOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  widget.returnRawValue
                      ? 'QR-Code wird uebernommen...'
                      : 'Lagerplatz wird gesucht...',
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _erneutScannen,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Erneut scannen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
