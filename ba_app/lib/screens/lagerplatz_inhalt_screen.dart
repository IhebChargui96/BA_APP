// Screen fuer den Inhalt eines Lagerplatzes.
// Er zeigt die zugeordneten Produkte und erlaubt das Bearbeiten eines Produkts.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/lagerplatz_inhalt_controller.dart';
import '../models/lagerplatz.dart';
import '../models/produkt.dart';
import 'produkt_form_screen.dart';

/// Zeigt die Produkte, die einem bestimmten Lagerplatz zugeordnet sind.
class LagerplatzInhaltScreen extends StatefulWidget {
  final Lagerplatz lagerplatz;
  const LagerplatzInhaltScreen({super.key, required this.lagerplatz});

  @override
  State<LagerplatzInhaltScreen> createState() => _LagerplatzInhaltScreenState();
}

class _LagerplatzInhaltScreenState extends State<LagerplatzInhaltScreen> {
  late final LagerplatzInhaltController controller;

  // Erstellt den Controller fuer diesen Lagerplatz beim Start.
  @override
  void initState() {
    super.initState();
    controller = Get.put(
      LagerplatzInhaltController(lagerplatz: widget.lagerplatz),
    );
  }

  // Gibt den Controller beim Schliessen des Screens wieder frei.
  @override
  void dispose() {
    if (Get.isRegistered<LagerplatzInhaltController>()) {
      Get.delete<LagerplatzInhaltController>();
    }
    super.dispose();
  }

  // Baut die Oberflaeche mit Info-Karte und Produktliste auf.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context),
      body: Obx(
        () => Column(
          children: [
            _infoKarte(),
            if (controller.fehlerText.value.isNotEmpty)
              _fehlerAnzeige(controller.fehlerText.value),
            if (controller.laedt.value) const LinearProgressIndicator(),
            Expanded(child: _produktBereich()),
          ],
        ),
      ),
    );
  }

  // App-Leiste mit Lagerplatz-Name, ID und Neu-laden-Button.
  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: Text(
        'Inhalt: ${widget.lagerplatz.name} (ID ${widget.lagerplatz.id ?? "-"})',
      ),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        IconButton(
          tooltip: 'Neu laden',
          icon: const Icon(Icons.refresh),
          onPressed: controller.produkteLaden,
        ),
      ],
    );
  }

  // Gruene Info-Karte mit den Eckdaten des Lagerplatzes.
  Widget _infoKarte() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Lagerplatz gefunden',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoZeile(Icons.inventory_2, 'Lagerplatz', widget.lagerplatz.name),
          const SizedBox(height: 6),
          _infoZeile(
            Icons.numbers,
            'ID',
            widget.lagerplatz.id?.toString() ?? '-',
          ),
          const SizedBox(height: 6),
          _infoZeile(Icons.qr_code_2, 'QR-Code', controller.qrCodeText),
          const SizedBox(height: 6),
          _infoZeile(Icons.list_alt, 'Inhalt', controller.produktAnzahlText),
        ],
      ),
    );
  }

  // Einzelne Zeile der Info-Karte (Symbol, Label, Wert).
  Widget _infoZeile(IconData icon, String label, String wert) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(wert)),
      ],
    );
  }

  // Roter Hinweiskasten fuer Fehlertexte aus dem Controller.
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

  // Produktliste mit Lade-, Leer- und Pull-to-Refresh-Zustand.
  Widget _produktBereich() {
    if (controller.laedt.value && controller.produkte.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.produkte.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Keine Produkte an diesem Lagerplatz.\n'
            'Produkte koennen im Produktformular zugeordnet werden.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.produkteLaden,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: controller.produkte.length,
        itemBuilder: (context, index) {
          return _produktKarte(controller.produkte[index]);
        },
      ),
    );
  }

  // Einzelne Produkt-Karte mit Foto, Titel und Untertitel.
  Widget _produktKarte(Produkt produkt) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _produktFoto(produkt),
        title: Text(
          produkt.titel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: _produktUntertitel(produkt),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _produktBearbeiten(produkt),
      ),
    );
  }

  // Untertitel mit Stueckzahl, Mindestmenge, Wert und Ringfarben.
  Widget _produktUntertitel(Produkt produkt) {
    final wert = produkt.widerstandsWert?.trim();
    final ringe = produkt.ringFarben?.trim();
    final toleranz = produkt.toleranz?.trim() ?? '';
    final zeilen = [
      'Stueckzahl: ${produkt.stueckzahl}',
      if (produkt.mindestBestand > 0) 'Mindestmenge: ${produkt.mindestBestand}',
      if (wert != null && wert.isNotEmpty) 'Wert: $wert $toleranz'.trim(),
      if (ringe != null && ringe.isNotEmpty) 'Ringe: $ringe',
    ];
    return Text(zeilen.join('\n'));
  }

  // Produktfoto oder Platzhalter-Symbol, wenn kein Foto vorhanden ist.
  Widget _produktFoto(Produkt produkt) {
    final pfad = produkt.fotoPfad;
    if (pfad != null && pfad.trim().isNotEmpty) {
      final datei = File(pfad);
      if (datei.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          // BoxFit.contain statt cover: hohe oder schmale Produkte
          // (z. B. eine Flasche) sollen komplett sichtbar sein,
          // wie auch in der Produktkarte des Inventars.
          child: Container(
            width: 52,
            height: 52,
            color: Colors.white,
            alignment: Alignment.center,
            child: Image.file(datei, fit: BoxFit.contain),
          ),
        );
      }
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.inventory_2, color: Colors.grey),
    );
  }

  // Oeffnet das Produktformular und laedt danach den Inhalt neu.
  Future<void> _produktBearbeiten(Produkt produkt) async {
    await Get.to(() => ProduktFormScreen(produkt: produkt));
    await controller.produkteLaden();
  }
}
