// Produktkarte fuer die Inventar-Liste.
//
// Zeigt ein Produkt als Karte mit Foto, Stammdaten, Widerstandsdaten,
// Bestandswarnung, offenen Ausleihen und den Schnellaktionen rechts.
//
// Die Karte ist als reines Anzeige-Widget gehalten:
// Alle Daten kommen fertig aufbereitet als Parameter herein
// (z. B. die Namen von Kategorie und Lagerplatz als Text statt als IDs),
// und alle Aktionen gehen als Callbacks an den Inventar-Screen zurueck.
// Dadurch enthaelt die Karte keine Controller- oder Datenbank-Zugriffe
// und laesst sich unabhaengig vom Screen verstehen und testen.

import 'dart:io';

import 'package:flutter/material.dart';

import '../models/ausleihe.dart';
import '../models/produkt.dart';
import 'ausleihe_dialog.dart';

/// Zeigt ein Produkt in der Inventarliste mit Foto, Lagerdaten und Aktionen.
class ProduktKarte extends StatelessWidget {
  // Das anzuzeigende Produkt.
  final Produkt produkt;
  // Offene Ausleihen nur dieses Produkts (bereits vorgefiltert).
  final List<Ausleihe> offeneAusleihen;
  // Aufgeloeste Anzeigenamen. Der Screen uebersetzt die IDs des Produkts
  // in Namen, damit die Karte keine Controller braucht. "-" bedeutet:
  // nicht zugeordnet.
  final String kategorieName;
  final String lagerplatzName;
  final String lagerortName;
  // Aktionen, die der Inventar-Screen ausfuehrt.
  final VoidCallback onBearbeiten;
  final VoidCallback onStueckzahlAendern;
  final VoidCallback onErhoehen;
  final VoidCallback onVerringern;
  final VoidCallback onLoeschen;

  const ProduktKarte({
    super.key,
    required this.produkt,
    required this.offeneAusleihen,
    required this.kategorieName,
    required this.lagerplatzName,
    required this.lagerortName,
    required this.onBearbeiten,
    required this.onStueckzahlAendern,
    required this.onErhoehen,
    required this.onVerringern,
    required this.onLoeschen,
  });

  /// Baut die Karte auf: links Foto, Mitte Texte, rechts Aktionen.
  /// Bei niedrigem Bestand bekommt die Karte einen roten Rahmen,
  /// damit die Warnung schon in der Liste auffaellt.
  @override
  Widget build(BuildContext context) {
    final bestandNiedrig = produkt.istBestandNiedrig;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: bestandNiedrig
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onBearbeiten,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _produktFoto(),
              const SizedBox(width: 12),
              Expanded(child: _produktTextBereich()),
              _produktAktionen(),
            ],
          ),
        ),
      ),
    );
  }

  /// Zeigt das Produktfoto, falls die Datei existiert.
  /// Sonst einen grauen Platzhalter mit Inventar-Symbol.
  /// Die Existenz wird geprueft, weil Foto-Pfade nach einem CSV-Import
  /// oder App-Neuinstallation ungueltig sein koennen.
  Widget _produktFoto() {
    final pfad = produkt.fotoPfad;
    if (pfad != null && pfad.trim().isNotEmpty) {
      final datei = File(pfad);
      if (datei.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            height: 64,
            color: Colors.white,
            alignment: Alignment.center,
            child: Image.file(datei, fit: BoxFit.contain),
          ),
        );
      }
    }
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2, color: Colors.grey),
    );
  }

  // Mittlerer Textbereich: Titel, Stueckzahl (antippbar zum Aendern),
  // Mindestmenge, Widerstandsdaten, Zuordnungen, Anlegedatum,
  // Bestandswarnung und offene Ausleihen.
  Widget _produktTextBereich() {
    final bestandNiedrig = produkt.istBestandNiedrig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (bestandNiedrig) ...[
              const Icon(Icons.warning, color: Colors.red, size: 18),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                produkt.titel.trim().isEmpty ? 'Ohne Name' : produkt.titel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: bestandNiedrig ? Colors.red.shade800 : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Die Stueckzahl ist direkt antippbar - das ist der schnellste
        // Weg, einen Bestand zu korrigieren, ohne das Formular zu oeffnen.
        InkWell(
          onTap: onStueckzahlAendern,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stueckzahl: ${produkt.stueckzahl}'),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 14, color: Colors.grey),
            ],
          ),
        ),
        Text('Mindestmenge: ${produkt.mindestBestand}'),
        if (produkt.istWiderstand) Text(_widerstandsText()),
        Text('Kategorie: $kategorieName'),
        Text('Lagerplatz: $lagerplatzName'),
        Text('Lagerort: $lagerortName'),
        _hinzugefuegtZeile(),
        if (bestandNiedrig)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Wenig auf Lager',
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        _ausleiheBereich(),
      ],
    );
  }

  // Zeigt das Anlegedatum des Produkts.
  // Laesst sich das gespeicherte Datum nicht parsen (z. B. nach einem
  // fehlerhaften Import), wird die Zeile einfach weggelassen.
  Widget _hinzugefuegtZeile() {
    final datum = DateTime.tryParse(produkt.erstelltAm);
    if (datum == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Hinzugefuegt: ${formatDatumKurz(datum)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  // Listet alle offenen Ausleihen dieses Produkts auf.
  // Ohne offene Ausleihen wird nichts angezeigt.
  Widget _ausleiheBereich() {
    if (offeneAusleihen.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: offeneAusleihen.map(_ausleiheZeile).toList(),
      ),
    );
  }

  // Eine Zeile pro Ausleihe: an wen, wie viele Stueck, Frist.
  // Ueberfaellige Ausleihen werden rot mit Warnsymbol dargestellt,
  // laufende gruen mit Handschlag-Symbol.
  Widget _ausleiheZeile(Ausleihe ausleihe) {
    final ueberfaellig = ausleihe.istUeberfaellig;
    final frist = ausleihe.fristdatumParsed;
    final farbe = ueberfaellig ? Colors.red.shade800 : Colors.green.shade800;
    final fristText = frist == null
        ? ausleihe.fristdatum
        : '${formatDatumKurz(frist)} (${tageBisFristText(frist)})';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ueberfaellig ? Icons.warning_amber : Icons.handshake,
            size: 14,
            color: farbe,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Verliehen an ${ausleihe.vollerName} '
              '(${ausleihe.menge} Stueck), zurueck bis $fristText',
              style: TextStyle(fontSize: 12, color: farbe),
            ),
          ),
        ],
      ),
    );
  }

  // Schnellaktionen rechts: Stueckzahl +1 / -1 und Loeschen.
  // Plus und Minus sind die schnelle Aufnahme/Entnahme einzelner Teile
  // direkt aus der Liste (Kernanforderung aus der Aufgabenstellung).
  Widget _produktAktionen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Stueckzahl erhoehen',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onErhoehen,
        ),
        IconButton(
          tooltip: 'Stueckzahl verringern',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onVerringern,
        ),
        IconButton(
          tooltip: 'Produkt loeschen',
          icon: const Icon(Icons.delete_outline),
          color: Colors.red,
          onPressed: onLoeschen,
        ),
      ],
    );
  }

  // Baut die Widerstands-Zeile aus Wert, Toleranz und Ringfarben.
  // Es werden nur die Teile angezeigt, die wirklich vorhanden sind.
  String _widerstandsText() {
    final wert = produkt.widerstandsWert?.trim() ?? '';
    final toleranz = produkt.toleranz?.trim() ?? '';
    final ringe = produkt.ringFarben?.trim() ?? '';
    final teile = [
      if (wert.isNotEmpty) 'Wert: $wert $toleranz'.trim(),
      if (ringe.isNotEmpty) 'Ringe: $ringe',
    ];
    return teile.join(' | ');
  }
}
