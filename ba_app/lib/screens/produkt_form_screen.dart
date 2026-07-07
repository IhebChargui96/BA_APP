// Formular zum Anlegen und Bearbeiten von Produkten.
// Optional koennen Scan-Daten eines Widerstands uebernommen werden.
// Im Bearbeiten-Modus wird zusaetzlich die Ausleih-Karte angezeigt.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/kategorie_controller.dart';
import '../controllers/lagerort_controller.dart';
import '../controllers/lagerplatz_controller.dart';
import '../controllers/produkt_controller.dart';
import '../helpers/foto_helper.dart';
import '../helpers/validatoren.dart';
import '../models/kategorie.dart';
import '../models/lagerplatz.dart';
import '../models/produkt.dart';
import '../models/scan_ergebnis.dart';
import '../widgets/ausleihe_karte.dart';
import 'qr_scanner_screen.dart';

/// Formular zum Anlegen oder Bearbeiten eines Produkts.
class ProduktFormScreen extends StatefulWidget {
  final Produkt? produkt;
  final ScanErgebnis? scanErgebnis;
  const ProduktFormScreen({super.key, this.produkt, this.scanErgebnis});

  @override
  State<ProduktFormScreen> createState() => _ProduktFormScreenState();
}

class _ProduktFormScreenState extends State<ProduktFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titelController = TextEditingController();
  final _beschreibungController = TextEditingController();
  final _stueckzahlController = TextEditingController(text: '1');
  final _mindestBestandController = TextEditingController(text: '1');
  late final ProduktController _produktController;
  late final KategorieController _kategorieController;
  late final LagerortController _lagerortController;
  late final LagerplatzController _lagerplatzController;
  String? _fotoPfad;
  String? _ringFarben;
  String? _widerstandsWert;
  String? _toleranz;
  String? _scanHinweis;
  int? _kategorieId;
  int? _lagerortId;
  int? _lagerplatzId;
  List<Lagerplatz> _lagerplaetzeImLagerort = [];
  bool _datenWerdenGeladen = true;
  bool _wirdGespeichert = false;
  // True, wenn ein bestehendes Produkt bearbeitet wird (sonst Neuanlage).
  bool get _istBearbeitenModus => widget.produkt != null;
  // True, wenn Scan-Daten (Farbringe) vorliegen und angezeigt werden sollen.
  bool get _hatScanDaten =>
      _ringFarben != null && _ringFarben!.trim().isNotEmpty;

  // Registriert die benoetigten Controller und startet das Laden der Daten.
  @override
  void initState() {
    super.initState();
    _produktController = Get.isRegistered<ProduktController>()
        ? Get.find<ProduktController>()
        : Get.put(ProduktController());
    _kategorieController = Get.isRegistered<KategorieController>()
        ? Get.find<KategorieController>()
        : Get.put(KategorieController());
    _lagerortController = Get.isRegistered<LagerortController>()
        ? Get.find<LagerortController>()
        : Get.put(LagerortController());
    _lagerplatzController = Get.isRegistered<LagerplatzController>()
        ? Get.find<LagerplatzController>()
        : Get.put(LagerplatzController());
    _datenLadenUndFormularFuellen();
  }

  // Laedt die Stammdaten und fuellt das Formular je nach Modus vor.
  Future<void> _datenLadenUndFormularFuellen() async {
    setState(() => _datenWerdenGeladen = true);
    // Stammdaten parallel laden - die drei Aufrufe haengen nicht
    // voneinander ab, also kein Grund sie zu serialisieren.
    await Future.wait([
      _kategorieController.kategorienLaden(),
      _lagerortController.lagerorteLaden(),
      _lagerplatzController.lagerplaetzeLaden(),
    ]);
    if (_istBearbeitenModus) {
      _bestehendesProduktUebernehmen();
    } else if (widget.scanErgebnis != null) {
      _scanErgebnisUebernehmen();
    }
    _lagerplaetzeImLagerortAktualisieren();
    if (mounted) {
      setState(() => _datenWerdenGeladen = false);
    }
  }

  // Uebernimmt die Werte des zu bearbeitenden Produkts in das Formular.
  void _bestehendesProduktUebernehmen() {
    final produkt = widget.produkt!;
    _titelController.text = produkt.titel;
    _beschreibungController.text = produkt.beschreibung ?? '';
    _stueckzahlController.text = produkt.stueckzahl.toString();
    _mindestBestandController.text = produkt.mindestBestand.toString();
    _fotoPfad = produkt.fotoPfad;
    _ringFarben = produkt.ringFarben;
    _widerstandsWert = produkt.widerstandsWert;
    _toleranz = produkt.toleranz;
    _kategorieId = produkt.kategorieId;
    _lagerplatzId = produkt.lagerplatzId;
    final lagerplatz = _lagerplatzMitId(_lagerplatzId);
    _lagerortId = lagerplatz?.lagerortId;
  }

  // Uebernimmt die Scan-Daten in das Formular und schlaegt eine Kategorie vor.
  void _scanErgebnisUebernehmen() {
    final scan = widget.scanErgebnis!;
    _fotoPfad = scan.fotoPfad;
    _ringFarben = scan.ringFarben;
    _widerstandsWert = scan.widerstandsWert;
    _toleranz = scan.toleranz;
    _scanHinweis = scan.hinweis;
    _titelController.text = scan.titelVorschlag;
    _beschreibungController.text = scan.beschreibungVorschlag;
    _stueckzahlController.text = '1';
    _mindestBestandController.text = '1';
    // Suche nach einer Kategorie, deren Name "widerstand" enthaelt.
    // Wenn vorhanden, wird sie automatisch vorausgewaehlt - der
    // Nutzer kann sie aber im Dropdown ueberschreiben.
    final widerstandKategorie = _kategorieMitNameTeil('widerstand');
    _kategorieId = widerstandKategorie?.id;
  }

  // Filtert die Lagerplaetze auf den gewaehlten Lagerort und prueft die Auswahl.
  void _lagerplaetzeImLagerortAktualisieren() {
    if (_lagerortId == null) {
      _lagerplaetzeImLagerort = [];
      _lagerplatzId = null;
      return;
    }
    _lagerplaetzeImLagerort = _lagerplatzController.lagerplaetze
        .where((l) => l.lagerortId == _lagerortId)
        .toList();
    // Wenn der vorher gewaehlte Lagerplatz nicht mehr in der neuen
    // Liste enthalten ist (Lagerort wurde gewechselt), Auswahl zuruecksetzen.
    final lagerplatzNochVorhanden = _lagerplaetzeImLagerort.any(
      (l) => l.id == _lagerplatzId,
    );
    if (!lagerplatzNochVorhanden) {
      _lagerplatzId = null;
    }
  }

  // Reaktion auf einen Lagerort-Wechsel: Lagerplatz-Auswahl neu aufbauen.
  void _lagerortGeaendert(int? lagerortId) {
    setState(() {
      _lagerortId = lagerortId;
      _lagerplatzId = null;
      _lagerplaetzeImLagerortAktualisieren();
    });
  }

  // Reaktion auf einen Lagerplatz-Wechsel.
  void _lagerplatzGeaendert(int? lagerplatzId) {
    setState(() => _lagerplatzId = lagerplatzId);
  }

  // Oeffnet die Foto-Auswahl und uebernimmt den gewaehlten Pfad.
  Future<void> _fotoAuswaehlen() async {
    final pfad = await FotoHelper.fotoAuswaehlen(context);
    if (pfad == null) return;
    if (!mounted) return;
    setState(() => _fotoPfad = pfad);
  }

  // Scannt einen QR-Code und waehlt den passenden Lagerplatz samt Lagerort.
  Future<void> _lagerplatzPerQrCodeAuswaehlen() async {
    // Navigator.push<String> statt Get.to, weil der Scanner einen Wert
    // zurueckgibt - genau wie im Lagerplatz-Screen.
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScannerScreen(returnRawValue: true),
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    await _lagerplatzController.lagerplaetzeLaden();
    final lagerplatz = await _lagerplatzController.lagerplatzPerQrCode(
      code.trim(),
    );
    if (!mounted) return;
    if (lagerplatz == null) {
      Get.snackbar(
        'Nicht gefunden',
        'Kein Lagerplatz mit diesem QR-Code gefunden.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final plaetzeImLagerort = _lagerplatzController.lagerplaetze
        .where((l) => l.lagerortId == lagerplatz.lagerortId)
        .toList();
    // Sicherheit: falls der gefundene Lagerplatz noch nicht in der
    // Controller-Liste steht, wird er trotzdem im Dropdown angezeigt.
    if (!plaetzeImLagerort.any((l) => l.id == lagerplatz.id)) {
      plaetzeImLagerort.add(lagerplatz);
    }
    setState(() {
      _lagerortId = lagerplatz.lagerortId;
      _lagerplaetzeImLagerort = plaetzeImLagerort;
      _lagerplatzId = lagerplatz.id;
    });
    Get.snackbar(
      'Lagerplatz gefunden',
      lagerplatz.name,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // Prueft das Formular, erstellt das Produkt und speichert es ueber den Controller.
  Future<void> _speichern() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _wirdGespeichert = true);
    try {
      final produkt = await _produktAusFormularErstellen();
      if (_istBearbeitenModus) {
        await _produktController.produktAktualisieren(produkt);
      } else {
        await _produktController.produktHinzufuegen(produkt);
      }
      Get.back();
      Get.snackbar(
        'Gespeichert',
        _istBearbeitenModus
            ? 'Produkt wurde aktualisiert.'
            : 'Produkt wurde angelegt.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Fehler',
        'Speichern fehlgeschlagen: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _wirdGespeichert = false);
      }
    }
  }

  // Baut aus den Formularwerten ein Produkt-Objekt (Neuanlage oder Mutation).
  Future<Produkt> _produktAusFormularErstellen() async {
    final titel = _titelController.text.trim();
    final beschreibung = _beschreibungController.text.trim();
    // Stueckzahl darf 0 sein, z. B. wenn ein Produkt leer ist.
    // Mindestmenge bleibt mindestens 1, weil sie als Warnschwelle dient.
    final stueckzahl = _zahlMindestensNull(_stueckzahlController.text);
    final mindestBestand = _zahlMindestensEins(_mindestBestandController.text);
    // Foto in App-Verzeichnis kopieren, falls noch nicht dort.
    String? finalerFotoPfad = _fotoPfad;
    if (finalerFotoPfad != null && finalerFotoPfad.trim().isNotEmpty) {
      finalerFotoPfad = await FotoHelper.fotoSpeichern(finalerFotoPfad);
    }
    if (_istBearbeitenModus) {
      // Bestehendes Objekt mutieren - id und erstelltAm bleiben so erhalten.
      final produkt = widget.produkt!;
      produkt.titel = titel;
      produkt.beschreibung = beschreibung;
      produkt.stueckzahl = stueckzahl;
      produkt.mindestBestand = mindestBestand;
      produkt.fotoPfad = finalerFotoPfad;
      produkt.kategorieId = _kategorieId;
      produkt.lagerplatzId = _lagerplatzId;
      produkt.ringFarben = _ringFarben;
      produkt.widerstandsWert = _widerstandsWert;
      produkt.toleranz = _toleranz;
      return produkt;
    }
    return Produkt(
      titel: titel,
      beschreibung: beschreibung,
      stueckzahl: stueckzahl,
      mindestBestand: mindestBestand,
      fotoPfad: finalerFotoPfad,
      kategorieId: _kategorieId,
      lagerplatzId: _lagerplatzId,
      ringFarben: _ringFarben,
      widerstandsWert: _widerstandsWert,
      toleranz: _toleranz,
    );
  }

  // Wandelt Text in eine ganze Zahl um, mindestens 0 (fuer die Stueckzahl).
  int _zahlMindestensNull(String text) {
    final wert = int.tryParse(text.trim());
    if (wert == null || wert < 0) {
      return 0;
    }
    return wert;
  }

  // Wandelt Text in eine ganze Zahl um, mindestens 1 (fuer die Mindestmenge).
  int _zahlMindestensEins(String text) {
    final wert = int.tryParse(text.trim());
    if (wert == null || wert < 1) {
      return 1;
    }
    return wert;
  }

  // Sucht die erste Kategorie, deren Name den angegebenen Teil enthaelt.
  Kategorie? _kategorieMitNameTeil(String nameTeil) {
    final suchtext = nameTeil.toLowerCase();
    return _kategorieController.kategorien
        .where((k) => k.name.toLowerCase().contains(suchtext))
        .firstOrNull;
  }

  // Liefert den Lagerplatz zu einer ID, oder null.
  Lagerplatz? _lagerplatzMitId(int? id) {
    if (id == null) return null;
    return _lagerplatzController.lagerplaetze
        .where((l) => l.id == id)
        .firstOrNull;
  }

  // Prueft, ob die Kategorie-ID noch in der Liste vorhanden ist.
  bool _kategorieExistiert(int? id) {
    if (id == null) return false;
    return _kategorieController.kategorien.any((k) => k.id == id);
  }

  // Prueft, ob die Lagerort-ID noch in der Liste vorhanden ist.
  bool _lagerortExistiert(int? id) {
    if (id == null) return false;
    return _lagerortController.lagerorte.any((l) => l.id == id);
  }

  // Prueft, ob die Lagerplatz-ID im gewaehlten Lagerort vorhanden ist.
  bool _lagerplatzExistiert(int? id) {
    if (id == null) return false;
    return _lagerplaetzeImLagerort.any((l) => l.id == id);
  }

  // Gibt alle Text-Controller frei, wenn der Screen geschlossen wird.
  @override
  void dispose() {
    _titelController.dispose();
    _beschreibungController.dispose();
    _stueckzahlController.dispose();
    _mindestBestandController.dispose();
    super.dispose();
  }

  // Aufbau des Formulars.
  @override
  Widget build(BuildContext context) {
    if (_datenWerdenGeladen) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: _appBar(context),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _fotoBereich(),
              if (_hatScanDaten) ...[
                const SizedBox(height: 16),
                _scanInfoKarte(),
              ],
              const SizedBox(height: 16),
              _grunddatenBereich(),
              const SizedBox(height: 16),
              _kategorieBereich(),
              const SizedBox(height: 16),
              _lagerBereich(),
              if (_istBearbeitenModus && widget.produkt?.id != null) ...[
                const SizedBox(height: 16),
                AusleiheKarte(produktId: widget.produkt!.id!),
              ],
              const SizedBox(height: 24),
              _speichernButton(),
            ],
          ),
        ),
      ),
    );
  }

  // App-Leiste mit Titel je nach Modus und Speichern-Button.
  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: Text(_istBearbeitenModus ? 'Produkt bearbeiten' : 'Neues Produkt'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          tooltip: 'Speichern',
          onPressed: _wirdGespeichert ? null : _speichern,
          icon: _wirdGespeichert
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
        ),
      ],
    );
  }

  // Karte fuer die Foto-Auswahl mit Vorschau.
  Widget _fotoBereich() {
    return _formularKarte(
      titel: 'Foto',
      icon: Icons.photo_camera,
      children: [
        GestureDetector(
          onTap: _fotoAuswaehlen,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _fotoInhalt(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Das Foto wird beim Speichern in das App-Verzeichnis kopiert.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // Zeigt das gewaehlte Foto oder einen Platzhalter zum Auswaehlen.
  Widget _fotoInhalt() {
    if (_fotoPfad != null && File(_fotoPfad!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Image.file(
            File(_fotoPfad!),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 48),
        SizedBox(height: 8),
        Text('Foto auswaehlen'),
      ],
    );
  }

  // Karte mit den uebernommenen Scan-Daten (Farbringe, Wert, Toleranz).
  Widget _scanInfoKarte() {
    return _formularKarte(
      titel: 'Scan-Ergebnis',
      icon: Icons.memory,
      children: [
        _infoZeile('Farbringe', _ringFarben ?? '-'),
        _infoZeile('Widerstandswert', _widerstandsWert ?? '-'),
        _infoZeile('Toleranz', _toleranz ?? '-'),
        if (_scanHinweis != null && _scanHinweis!.trim().isNotEmpty)
          _infoZeile('Hinweis', _scanHinweis!),
      ],
    );
  }

  // Karte mit Titel, Beschreibung, Stueckzahl und Mindestmenge.
  Widget _grunddatenBereich() {
    return _formularKarte(
      titel: 'Grunddaten',
      icon: Icons.edit_note,
      children: [
        TextFormField(
          controller: _titelController,
          decoration: const InputDecoration(
            labelText: 'Titel *',
            hintText: 'z. B. Widerstand 4,7 kΩ',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          validator: (text) =>
              Validatoren.pruefePflichtfeld(text ?? '', 'einen Titel'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _beschreibungController,
          decoration: const InputDecoration(
            labelText: 'Beschreibung',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _stueckzahlController,
                decoration: const InputDecoration(
                  labelText: 'Stueckzahl',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (text) => Validatoren.pruefeStueckzahl(text ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _mindestBestandController,
                decoration: const InputDecoration(
                  labelText: 'Mindestmenge',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (text) =>
                    Validatoren.pruefeMindestBestand(text ?? ''),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Karte mit der Kategorie-Auswahl.
  Widget _kategorieBereich() {
    return _formularKarte(
      titel: 'Kategorie',
      icon: Icons.category,
      children: [
        if (_kategorieController.kategorien.isEmpty)
          const Text(
            'Keine Kategorien vorhanden. Bitte zuerst Kategorien anlegen.',
            style: TextStyle(color: Colors.grey),
          )
        else
          DropdownButtonFormField<int?>(
            initialValue: _kategorieExistiert(_kategorieId)
                ? _kategorieId
                : null,
            decoration: const InputDecoration(
              labelText: 'Kategorie',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Keine Kategorie'),
              ),
              ..._kategorieController.kategorien.map(
                (kategorie) => DropdownMenuItem<int?>(
                  value: kategorie.id,
                  child: Text(kategorie.name),
                ),
              ),
            ],
            onChanged: (wert) => setState(() => _kategorieId = wert),
          ),
      ],
    );
  }

  // Karte mit Lagerort- und Lagerplatz-Auswahl sowie QR-Code-Button.
  Widget _lagerBereich() {
    return _formularKarte(
      titel: 'Lagerung',
      icon: Icons.inventory_2,
      children: [
        if (_lagerortController.lagerorte.isEmpty)
          const Text(
            'Keine Lagerorte vorhanden. Bitte zuerst Lagerorte anlegen.',
            style: TextStyle(color: Colors.grey),
          )
        else
          DropdownButtonFormField<int?>(
            key: ValueKey('lagerort-$_lagerortId'),
            initialValue: _lagerortExistiert(_lagerortId) ? _lagerortId : null,
            decoration: const InputDecoration(
              labelText: 'Lagerort',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.place),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Kein Lagerort'),
              ),
              ..._lagerortController.lagerorte.map(
                (lagerort) => DropdownMenuItem<int?>(
                  value: lagerort.id,
                  child: Text(lagerort.name),
                ),
              ),
            ],
            onChanged: _lagerortGeaendert,
          ),
        const SizedBox(height: 12),
        _lagerplatzAuswahl(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _lagerplatzPerQrCodeAuswaehlen,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Lagerplatz per QR-Code waehlen'),
        ),
      ],
    );
  }

  // Lagerplatz-Dropdown oder Hinweis, wenn kein Lagerort oder Platz vorhanden ist.
  Widget _lagerplatzAuswahl() {
    if (_lagerortId == null) {
      return _hinweisBox(
        icon: Icons.info_outline,
        text: 'Bitte zuerst einen Lagerort waehlen.',
        farbe: Colors.grey,
      );
    }
    if (_lagerplaetzeImLagerort.isEmpty) {
      return _hinweisBox(
        icon: Icons.warning_amber,
        text: 'Keine Lagerplaetze in diesem Lagerort vorhanden.',
        farbe: Colors.orange,
      );
    }
    return DropdownButtonFormField<int?>(
      key: ValueKey(
        'lagerplatz-$_lagerortId-$_lagerplatzId-${_lagerplaetzeImLagerort.length}',
      ),
      initialValue: _lagerplatzExistiert(_lagerplatzId) ? _lagerplatzId : null,
      decoration: const InputDecoration(
        labelText: 'Lagerplatz',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.inventory),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Kein Lagerplatz'),
        ),
        ..._lagerplaetzeImLagerort.map(
          (lagerplatz) => DropdownMenuItem<int?>(
            value: lagerplatz.id,
            child: Text(lagerplatz.name),
          ),
        ),
      ],
      onChanged: _lagerplatzGeaendert,
    );
  }

  // Grosser Speichern-Button am Ende des Formulars.
  Widget _speichernButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _wirdGespeichert ? null : _speichern,
        icon: _wirdGespeichert
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_wirdGespeichert ? 'Speichere...' : 'Speichern'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // Einheitliche Karte fuer einen Formular-Abschnitt (Titel, Icon, Inhalt).
  Widget _formularKarte({
    required String titel,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  titel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // Einzelne Label-Wert-Zeile in den Info-Karten.
  Widget _infoZeile(String label, String wert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(wert)),
        ],
      ),
    );
  }

  // Farbiger Hinweiskasten fuer die Lagerplatz-Auswahl.
  Widget _hinweisBox({
    required IconData icon,
    required String text,
    required Color farbe,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: farbe.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: farbe),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: farbe)),
          ),
        ],
      ),
    );
  }
}
