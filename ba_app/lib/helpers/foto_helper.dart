import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Hilfsfunktionen fuer Fotoauswahl, Kopieren und Loeschen von Produktfotos.
///
/// Die Datenbank speichert nur den Dateipfad. Die Bilddatei selbst wird in den
/// Dokumentenordner der App kopiert, damit sie spaeter weiter verfuegbar bleibt.
class FotoHelper {
  /// Interner Ordnername fuer Produktfotos.
  ///
  /// Der Name stammt aus einer frueheren Projektphase und bleibt erhalten,
  /// damit bereits gespeicherte Fotos nicht unnoetig verschoben werden.
  static const String fotoOrdnerName = 'electrostock_fotos';

  /// Oeffnet einen Dialog fuer Kamera oder Galerie.
  ///
  /// Zurueckgegeben wird der Pfad des ausgewaehlten Fotos. Bei Abbruch oder
  /// wenn die Ansicht nicht mehr aktiv ist, wird `null` zurueckgegeben.
  static Future<String?> fotoAuswaehlen(BuildContext context) async {
    final quelle = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Foto aufnehmen'),
                onTap: () {
                  Navigator.pop(sheetContext, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Aus Galerie waehlen'),
                onTap: () {
                  Navigator.pop(sheetContext, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Abbrechen'),
                onTap: () {
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
    if (quelle == null) {
      return null;
    }
    if (!context.mounted) {
      return null;
    }
    final picker = ImagePicker();
    final foto = await picker.pickImage(source: quelle, imageQuality: 95);
    return foto?.path;
  }

  /// Kopiert ein Foto in den Fotoordner der App.
  ///
  /// Liegt das Foto bereits dort, wird der vorhandene Pfad zurueckgegeben.
  /// So entstehen keine unnoetigen Kopien beim erneuten Speichern.
  static Future<String> fotoSpeichern(String originalPfad) async {
    final originalDatei = File(originalPfad);
    if (!await originalDatei.exists()) {
      throw Exception('Foto wurde nicht gefunden: $originalPfad');
    }
    final fotoOrdner = await _fotoOrdnerLaden();
    final original = p.normalize(originalPfad);
    final ordner = p.normalize(fotoOrdner.path);
    if (original == ordner || p.isWithin(ordner, original)) {
      return originalPfad;
    }
    final zielPfad = p.join(
      fotoOrdner.path,
      _eindeutigerDateiname(originalPfad),
    );
    final zielDatei = await originalDatei.copy(zielPfad);
    return zielDatei.path;
  }

  /// Laedt den Fotoordner der App und legt ihn bei Bedarf an.
  static Future<Directory> _fotoOrdnerLaden() async {
    final appOrdner = await getApplicationDocumentsDirectory();
    final fotoOrdner = Directory(p.join(appOrdner.path, fotoOrdnerName));
    if (!await fotoOrdner.exists()) {
      await fotoOrdner.create(recursive: true);
    }
    return fotoOrdner;
  }

  /// Baut einen Dateinamen mit Zeitstempel und passender Endung.
  ///
  /// Falls die Originalendung nicht bekannt ist, wird `.jpg` verwendet.
  static String _eindeutigerDateiname(String originalPfad) {
    const erlaubteEndungen = {'.jpg', '.jpeg', '.png', '.webp'};
    final rohEndung = p.extension(originalPfad).toLowerCase();
    final endung = erlaubteEndungen.contains(rohEndung) ? rohEndung : '.jpg';
    final zeitstempel = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return 'produktfoto_$zeitstempel$endung';
  }

  /// Prueft, ob ein gespeicherter Fotopfad noch auf eine vorhandene Datei zeigt.
  static bool fotoExistiert(String? pfad) {
    if (pfad == null || pfad.trim().isEmpty) {
      return false;
    }
    return File(pfad).existsSync();
  }

  /// Loescht eine Fotodatei, falls sie vorhanden ist.
  ///
  /// Die Methode wird defensiv genutzt: Ein leerer Pfad oder eine bereits
  /// fehlende Datei soll keinen Fehler im Verwaltungsablauf erzeugen.
  static Future<void> fotoLoeschenWennVorhanden(String? pfad) async {
    if (pfad == null || pfad.trim().isEmpty) {
      return;
    }
    final datei = File(pfad);
    if (await datei.exists()) {
      await datei.delete();
    }
  }
}
