import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Zeigt die gemeinsame Auswahl fuer Kamera oder Galerie.
///
/// Die Funktion wird in mehreren Scan-Ansichten genutzt. Dadurch steht die
/// Auswahl der Fotoquelle nur an einer Stelle und die Screens bleiben kuerzer.
Future<ImageSource?> waehleFotoQuelle(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Foto aufnehmen'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Aus Galerie waehlen'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}
