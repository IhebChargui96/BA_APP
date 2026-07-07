// Hauptseite der Inventarverwaltung.
// Zeigt Produktliste, Suche, Bestandsfilter, Navigation und CSV-Funktionen.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ausleihe_controller.dart';
import '../controllers/kategorie_controller.dart';
import '../controllers/lagerort_controller.dart';
import '../controllers/lagerplatz_controller.dart';
import '../controllers/produkt_controller.dart';
import '../helpers/csv_export.dart';
import '../helpers/csv_import.dart';
import '../models/produkt.dart';
import '../widgets/inventar_drawer.dart';
import '../widgets/produkt_karte.dart';
import 'produkt_form_screen.dart';
import 'qr_scanner_screen.dart';

/// Hauptansicht der App fuer die Produkt- und Bestandsverwaltung.
class InventarScreen extends StatefulWidget {
  const InventarScreen({super.key});

  @override
  State<InventarScreen> createState() => _InventarScreenState();
}

class _InventarScreenState extends State<InventarScreen> {
  final TextEditingController _suchController = TextEditingController();
  late final ProduktController _produktController;
  late final KategorieController _kategorieController;
  late final LagerortController _lagerortController;
  late final LagerplatzController _lagerplatzController;
  AusleiheController get _ausleiheController =>
      Get.isRegistered<AusleiheController>()
      ? Get.find<AusleiheController>()
      : Get.put(AusleiheController());
  _SortModus _sortierung = _SortModus.nameAufsteigend;
  int _kategorieFilterId = 0;

  // Registriert die benoetigten Controller und laedt die Daten beim Start.
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
    _alleDatenLaden();
  }

  // Laedt Produkte, Kategorien, Lagerorte, Lagerplaetze und Ausleihen neu.
  // Wird beim Start, beim Herunterziehen der Liste und nach Aenderungen
  // in anderen Screens aufgerufen.
  Future<void> _alleDatenLaden() async {
    await Future.wait([
      _produktController.produkteLaden(),
      _kategorieController.kategorienLaden(),
      _lagerortController.lagerorteLaden(),
      _lagerplatzController.lagerplaetzeLaden(),
      _ausleiheController.aktuelleAusleihenLaden(),
    ]);
  }

  // Gibt den Such-Controller frei, wenn der Screen geschlossen wird.
  @override
  void dispose() {
    _suchController.dispose();
    super.dispose();
  }

  // Baut die Oberflaeche der Hauptseite auf und aktualisiert sie reaktiv (Obx).
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        appBar: _appBar(context),
        drawer: InventarDrawer(
          anzahlProdukte: _produktController.produkte.length,
          anzahlNiedrigeBestaende: _anzahlNiedrigeBestaende(),
          onDatenNeuLaden: _alleDatenLaden,
          onCsvExport: _csvExportierenUndTeilen,
          onCsvImport: _csvImportieren,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _suchBereich(context),
              if (_produktController.nurNiedrigeBestaende.value)
                _filterHinweis(),
              if (_produktController.fehlerText.value.isNotEmpty)
                _fehlerAnzeige(_produktController.fehlerText.value),
              // Ladebalken nur beim ersten Laden anzeigen.
              // Wenn schon Produkte sichtbar sind, bleibt die Liste ruhig.
              if (_produktController.laedt.value &&
                  _produktController.produkte.isEmpty)
                const LinearProgressIndicator(),
              Expanded(child: _produktBereich()),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _neuesProduktOeffnen,
          icon: const Icon(Icons.add),
          label: const Text('Neu'),
        ),
      ),
    );
  }

  // App-Leiste der Hauptseite mit den Listen-Aktionen.
  AppBar _appBar(BuildContext context) {
    final filterAktiv = _produktController.nurNiedrigeBestaende.value;
    return AppBar(
      title: const Text('Inventar'),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          tooltip: filterAktiv
              ? 'Alle Produkte anzeigen'
              : 'Nur niedrige Menge anzeigen',
          icon: Icon(
            filterAktiv ? Icons.filter_alt : Icons.filter_alt_outlined,
            color: filterAktiv ? Colors.red : null,
          ),
          onPressed: _filterUmschalten,
        ),
        PopupMenuButton<_SortModus>(
          tooltip: 'Sortieren',
          icon: const Icon(Icons.sort),
          initialValue: _sortierung,
          onSelected: (modus) => setState(() => _sortierung = modus),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _SortModus.nameAufsteigend,
              child: Text('Name (A-Z)'),
            ),
            PopupMenuItem(
              value: _SortModus.bestandAufsteigend,
              child: Text('Menge aufsteigend'),
            ),
            PopupMenuItem(
              value: _SortModus.bestandAbsteigend,
              child: Text('Menge absteigend'),
            ),
            PopupMenuItem(
              value: _SortModus.neueste,
              child: Text('Neueste zuerst'),
            ),
          ],
        ),
        PopupMenuButton<int>(
          tooltip: 'Nach Kategorie filtern',
          icon: Icon(
            _kategorieFilterId == 0 ? Icons.category_outlined : Icons.category,
            color: _kategorieFilterId == 0 ? null : Colors.blue,
          ),
          onSelected: (id) => setState(() => _kategorieFilterId = id),
          itemBuilder: (context) => [
            const PopupMenuItem<int>(value: 0, child: Text('Alle Kategorien')),
            ..._kategorieController.kategorien.map(
              (kategorie) => PopupMenuItem<int>(
                value: kategorie.id ?? 0,
                child: Text(kategorie.name),
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'QR-Code scannen',
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () => Get.to(() => const QrScannerScreen()),
        ),
        IconButton(
          tooltip: 'Neu laden',
          icon: const Icon(Icons.refresh),
          onPressed: _alleDatenLaden,
        ),
      ],
    );
  }

  // Suchfeld ueber der Produktliste.
  Widget _suchBereich(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _suchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          labelText: 'Suchen',
          hintText: 'Produkt, Wert oder Farbringe',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _suchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Suche leeren',
                  icon: const Icon(Icons.clear),
                  onPressed: _sucheLeeren,
                ),
          border: const OutlineInputBorder(),
        ),
        onChanged: (text) {
          setState(() {});
          _produktController.suchen(text);
        },
      ),
    );
  }

  // Hinweisleiste, solange der Bestandsfilter aktiv ist.
  Widget _filterHinweis() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filter aktiv: niedrige Menge',
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }

  // Roter Hinweiskasten fuer Fehlertexte aus den Controllern.
  Widget _fehlerAnzeige(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(text, style: TextStyle(color: Colors.red.shade900)),
    );
  }

  // Wendet Kategorie-Filter und Sortierung auf die Controller-Liste an.
  // Reine Anzeige-Logik: Suche und Bestandsfilter laufen im Controller,
  // damit sie fuer alle Ansichten gleich funktionieren.
  List<Produkt> _sichtbareProdukte() {
    var liste = _produktController.produkte.toList();
    if (_kategorieFilterId != 0) {
      liste = liste
          .where((produkt) => produkt.kategorieId == _kategorieFilterId)
          .toList();
    }
    liste.sort(_produkteVergleichen);
    return liste;
  }

  // Vergleichsfunktion fuer die gewaehlte Sortierung.
  int _produkteVergleichen(Produkt a, Produkt b) {
    switch (_sortierung) {
      case _SortModus.nameAufsteigend:
        return a.titel.toLowerCase().compareTo(b.titel.toLowerCase());
      case _SortModus.bestandAufsteigend:
        return a.stueckzahl.compareTo(b.stueckzahl);
      case _SortModus.bestandAbsteigend:
        return b.stueckzahl.compareTo(a.stueckzahl);
      case _SortModus.neueste:
        return (b.id ?? 0).compareTo(a.id ?? 0);
    }
  }

  // Produktliste mit Lade-, Leer- und Pull-to-Refresh-Zustand.
  Widget _produktBereich() {
    if (_produktController.laedt.value && _produktController.produkte.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_produktController.produkte.isEmpty) {
      return _leereAnzeige();
    }
    final offeneAusleihen = _ausleiheController.aktuelleAusleihen.toList();
    final sichtbar = _sichtbareProdukte();
    if (sichtbar.isEmpty) {
      return _leereAnzeige();
    }
    return RefreshIndicator(
      onRefresh: _alleDatenLaden,
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
        itemCount: sichtbar.length,
        itemBuilder: (context, index) {
          final produkt = sichtbar[index];
          final ausleihen = offeneAusleihen
              .where((ausleihe) => ausleihe.produktId == produkt.id)
              .toList();
          // Die Karte bekommt fertig aufgeloeste Namen und Callbacks.
          // Dadurch bleibt sie ein reines Anzeige-Widget ohne
          // Controller-Zugriffe (siehe widgets/produkt_karte.dart).
          return ProduktKarte(
            produkt: produkt,
            offeneAusleihen: ausleihen,
            kategorieName: _kategorieName(produkt.kategorieId),
            lagerplatzName: _lagerplatzName(produkt.lagerplatzId),
            lagerortName: _lagerortNameZuLagerplatz(produkt.lagerplatzId),
            onBearbeiten: () => _produktBearbeiten(produkt),
            onStueckzahlAendern: () => _stueckzahlSetzenDialog(produkt),
            onErhoehen: () => _produktController.stueckzahlErhoehen(produkt),
            onVerringern: () =>
                _produktController.stueckzahlVerringern(produkt),
            onLoeschen: () => _produktLoeschenBestaetigen(produkt),
          );
        },
      ),
    );
  }

  // Hinweistext, wenn keine Produkte zur aktuellen Ansicht passen.
  // Der Text unterscheidet leeres Inventar, leere Suche und leeren Filter.
  Widget _leereAnzeige() {
    final suchtext = _produktController.suchtext.value.trim();
    final filterAktiv = _produktController.nurNiedrigeBestaende.value;
    String text =
        'Noch keine Produkte vorhanden.\n'
        'Mit „Neu" kann ein Produkt angelegt werden.';
    if (suchtext.isNotEmpty) {
      text = 'Keine Produkte zur Suche "$suchtext" gefunden.';
    }
    if (filterAktiv) {
      text = 'Keine Produkte mit niedriger Menge gefunden.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  // Schaltet den Filter "nur niedrige Bestaende" um.
  Future<void> _filterUmschalten() async {
    final neuerWert = !_produktController.nurNiedrigeBestaende.value;
    await _produktController.filterNiedrigeBestaendeSetzen(neuerWert);
  }

  // Leert das Suchfeld und den Suchtext im Controller.
  Future<void> _sucheLeeren() async {
    _suchController.clear();
    setState(() {});
    await _produktController.suchen('');
  }

  // Oeffnet das leere Produktformular und laedt danach die Daten neu.
  Future<void> _neuesProduktOeffnen() async {
    await Get.to(() => const ProduktFormScreen());
    await _alleDatenLaden();
  }

  // Oeffnet das Produktformular mit den Daten des gewaehlten Produkts.
  Future<void> _produktBearbeiten(Produkt produkt) async {
    await Get.to(() => ProduktFormScreen(produkt: produkt));
    await _alleDatenLaden();
  }

  // Dialog zum direkten Setzen der Stueckzahl (Tippen auf die Zahl).
  Future<void> _stueckzahlSetzenDialog(Produkt produkt) async {
    if (produkt.id == null) return;
    final formKey = GlobalKey<FormState>();
    // Kein TextEditingController im Dialog.
    // Ein manuell entsorgter Controller hat frueher waehrend der
    // Dialog-Schlussanimation zum _dependents.isEmpty-Absturz gefuehrt.
    // Fuer ein einzelnes Zahlenfeld reicht initialValue + onChanged.
    String mengeEingabe = produkt.stueckzahl.toString();
    void absenden(BuildContext dialogContext) {
      if (formKey.currentState?.validate() != true) {
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(dialogContext).pop(int.tryParse(mengeEingabe.trim()));
    }

    final neueZahl = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Stueckzahl aendern'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: mengeEingabe,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Neue Stueckzahl'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (text) {
                mengeEingabe = text;
              },
              validator: (text) {
                final wert = int.tryParse((text ?? '').trim());
                if (wert == null || wert < 0) {
                  return 'Bitte eine ganze Zahl ab 0 eingeben.';
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
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    if (neueZahl == null || neueZahl < 0) return;
    await _produktController.stueckzahlSetzen(produkt, neueZahl);
  }

  // Sicherheitsabfrage vor dem Loeschen eines Produkts.
  Future<void> _produktLoeschenBestaetigen(Produkt produkt) async {
    if (produkt.id == null) return;
    final bestaetigt = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Produkt loeschen'),
        content: Text(
          'Soll das Produkt "${produkt.titel}" wirklich geloescht werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.delete),
            label: const Text('Loeschen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (bestaetigt != true) return;
    await _produktController.produktLoeschen(produkt.id!);
  }

  // Exportiert den kompletten Datenbestand als CSV-Datei und oeffnet
  // den System-Teilen-Dialog.
  Future<void> _csvExportierenUndTeilen() async {
    try {
      await _alleDatenLaden();
      // Fuer den Export immer den kompletten Datenbestand laden.
      // Die Controller-Liste kann durch Suche oder Bestandsfilter
      // eingeschraenkt sein. Ein Teilexport waere gefaehrlich, weil
      // der Import den Datenbestand vollstaendig ersetzt - aus einem
      // gefilterten Export wuerden beim Wiedereinspielen alle nicht
      // exportierten Produkte verloren gehen.
      final produkteGesamt = await _produktController.alleProdukteUngefiltert();
      if (produkteGesamt.isEmpty) {
        Get.snackbar(
          'Hinweis',
          'Keine Produkte zum Exportieren vorhanden.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final ausleihen = await _ausleiheController.alleAusleihen();
      final pfad = await CsvExport.exportiereUndTeile(
        produkte: produkteGesamt,
        kategorien: _kategorieController.kategorien.toList(),
        lagerorte: _lagerortController.lagerorte.toList(),
        lagerplaetze: _lagerplatzController.lagerplaetze.toList(),
        ausleihen: ausleihen,
      );
      Get.snackbar(
        'Export erstellt',
        pfad,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Fehler',
        'CSV-Export fehlgeschlagen: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Waehlt eine CSV-Datei, fragt nach Bestaetigung und ersetzt damit
  // den kompletten Datenbestand (Restore).
  Future<void> _csvImportieren() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;
      final pfad = result.files.first.path;
      if (pfad == null) {
        Get.snackbar(
          'Fehler',
          'Dateipfad konnte nicht gelesen werden.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final bestaetigt = await _csvImportBestaetigen();
      if (bestaetigt != true) return;
      final ergebnis = await CsvImport.importiere(pfad);
      await _alleDatenLaden();
      _csvImportErgebnisAnzeigen(ergebnis);
    } catch (e) {
      Get.snackbar(
        'Fehler',
        'CSV-Import fehlgeschlagen: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Warn-Dialog vor dem Import: Der aktuelle Bestand wird ersetzt.
  Future<bool?> _csvImportBestaetigen() {
    return Get.dialog<bool>(
      AlertDialog(
        title: const Text('CSV importieren?'),
        content: const SingleChildScrollView(
          child: Text(
            'Der Import ersetzt den vorhandenen Datenbestand vollstaendig.\n\n'
            'Dabei werden geloescht und aus der CSV neu aufgebaut:\n'
            '- Produkte\n'
            '- Kategorien\n'
            '- Lagerorte\n'
            '- Lagerplaetze\n'
            '- Ausleihen\n\n'
            'Leere oder ungueltige Datumsfelder werden durch die App ergaenzt.\n'
            'Produktfotos werden nicht aus der CSV wiederhergestellt.\n\n'
            'Fortfahren?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.file_upload),
            label: const Text('Import starten'),
          ),
        ],
      ),
    );
  }

  // Zeigt die Import-Zusammenfassung mit Zaehlern und Hinweisen
  // (jede automatische Korrektur wird mit Zeilennummer gemeldet).
  void _csvImportErgebnisAnzeigen(CsvImportErgebnis ergebnis) {
    Get.dialog(
      AlertDialog(
        title: const Text('Import fertig'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Produkte importiert: ${ergebnis.produkteImportiert}'),
              Text('Produkte uebersprungen: ${ergebnis.produkteUebersprungen}'),
              const SizedBox(height: 8),
              Text('Kategorien erstellt: ${ergebnis.kategorienErstellt}'),
              Text('Lagerorte erstellt: ${ergebnis.lagerorteErstellt}'),
              Text('Lagerplaetze erstellt: ${ergebnis.lagerplaetzeErstellt}'),
              const SizedBox(height: 8),
              Text('Ausleihen importiert: ${ergebnis.ausleihenImportiert}'),
              Text(
                'Ausleihen uebersprungen: '
                '${ergebnis.ausleihenUebersprungen}',
              ),
              if (ergebnis.hinweise.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Hinweise:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...ergebnis.hinweise
                    .take(8)
                    .map(
                      (hinweis) => Text(
                        '- $hinweis',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                if (ergebnis.hinweise.length > 8)
                  Text(
                    '... und ${ergebnis.hinweise.length - 8} weitere',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }

  // Zaehlt Produkte unter Mindestmenge fuer den Drawer-Kopf.
  int _anzahlNiedrigeBestaende() {
    return _produktController.produkte.where((p) => p.istBestandNiedrig).length;
  }

  // Uebersetzt eine Kategorie-ID in den Namen ("-" ohne Zuordnung).
  String _kategorieName(int? kategorieId) {
    if (kategorieId == null) return '-';
    final kategorie = _kategorieController.kategorien
        .where((k) => k.id == kategorieId)
        .firstOrNull;
    return kategorie?.name ?? '-';
  }

  // Uebersetzt eine Lagerplatz-ID in den Namen ("-" ohne Zuordnung).
  String _lagerplatzName(int? lagerplatzId) {
    if (lagerplatzId == null) return '-';
    final lagerplatz = _lagerplatzController.lagerplaetze
        .where((l) => l.id == lagerplatzId)
        .firstOrNull;
    return lagerplatz?.name ?? '-';
  }

  // Ermittelt ueber den Lagerplatz den Namen des zugehoerigen Lagerorts.
  String _lagerortNameZuLagerplatz(int? lagerplatzId) {
    if (lagerplatzId == null) return '-';
    final lagerplatz = _lagerplatzController.lagerplaetze
        .where((l) => l.id == lagerplatzId)
        .firstOrNull;
    final lagerortId = lagerplatz?.lagerortId;
    if (lagerortId == null) return '-';
    final lagerort = _lagerortController.lagerorte
        .where((l) => l.id == lagerortId)
        .firstOrNull;
    return lagerort?.name ?? '-';
  }
}

enum _SortModus {
  nameAufsteigend,
  bestandAufsteigend,
  bestandAbsteigend,
  neueste,
}
