import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Dekodiert ein Bild und richtet es nach der gespeicherten Drehung auf.
///
/// Smartphone-Fotos speichern die Drehung oft nur als Zusatz-Angabe
/// (EXIF-Tag), ohne die Pixel selbst zu drehen. Ohne diesen Schritt kann
/// ein Foto im Scanbereich gedreht erscheinen.
img.Image? dekodiereMitOrientierung(Uint8List bytes) {
  final rohBild = img.decodeImage(bytes);
  if (rohBild == null) {
    return null;
  }
  return img.bakeOrientation(rohBild);
}
