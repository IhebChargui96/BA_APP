// Farbauswahl fuer einen gemessenen Widerstandsring.
//
// Die Auswertung laeuft in zwei Stufen:
// Zuerst werden einfache BGR-Regeln fuer klare Faelle geprueft.
// Wenn keine Regel passt, wird die Farbe mit den Referenzfarben der
// Farbtafel im L*a*b*-Farbraum verglichen.
//
// Zusaetzlich wird beruecksichtigt, welche Farben an der jeweiligen
// Ringposition nach IEC 60062 sinnvoll sind.

import 'bgr_farbe.dart';
import 'farb_heuristik.dart';
import 'iec_ringfarben.dart';
import 'lab_konvertierung.dart';

/// Bestimmt den Farbnamen eines gemessenen Ringpixels.
///
/// Die Positionsregel verhindert zum Beispiel, dass Schwarz als Toleranzring
/// verwendet wird. Danach folgen die BGR-Regeln. Der L*a*b*-Vergleich mit der
/// Farbtafel ist die Rueckfallloesung, wenn keine Regel eindeutig passt.
String findeFarbe({
  required BgrFarbe pixel,
  required int position,
  required int gesamtRinge,
  required List<BgrFarbe> referenzFarben,
}) {
  final erlaubt = erlaubteFarbenFuerPosition(
    position: position,
    gesamtRinge: gesamtRinge,
  );

  final istLetzterRing = position == gesamtRinge;
  final istMultiplikatorRing =
      (gesamtRinge == 4 && position == 3) ||
      (gesamtRinge == 5 && position == 4);

  // Schwarz ist in der verwendeten Teilmenge kein Toleranzring.
  if (!istLetzterRing && erlaubt.contains('Schwarz') && istDunkel(pixel)) {
    return 'Schwarz';
  }

  // Beim Multiplikator- und Toleranzring treten Gold und Silber auf.
  // Gelb wird vor Gold geprueft, weil beide im Foto nah beieinander liegen
  // koennen.
  if (istMultiplikatorRing || istLetzterRing) {
    if (erlaubt.contains('Silber') && istSilber(pixel)) {
      return 'Silber';
    }

    if (erlaubt.contains('Gelb') && istGelb(pixel)) {
      return 'Gelb';
    }

    if (erlaubt.contains('Gold') && istGold(pixel)) {
      return 'Gold';
    }
  }

  if (erlaubt.contains('Blau') && istBlau(pixel)) {
    return 'Blau';
  }

  // Gruen wird vor Gelb geprueft, weil gelbgruen wirkende Messwerte
  // sonst schnell als Gelb enden koennen.
  if (erlaubt.contains('Gruen') && istGruen(pixel)) {
    return 'Gruen';
  }

  if (erlaubt.contains('Gelb') && istGelb(pixel)) {
    return 'Gelb';
  }

  if (erlaubt.contains('Violett') && istViolett(pixel)) {
    return 'Violett';
  }

  if (erlaubt.contains('Orange') && istOrange(pixel)) {
    return 'Orange';
  }

  if (erlaubt.contains('Rot') && istRot(pixel)) {
    return 'Rot';
  }

  if (erlaubt.contains('Braun') && istBraun(pixel)) {
    return 'Braun';
  }

  // Wenn keine BGR-Regel gepasst hat, entscheidet der L*a*b*-Vergleich
  // mit den Referenzfarben aus derselben Aufnahme.
  return naechsteFarbeUeberLab(
    pixel: pixel,
    erlaubt: erlaubt,
    referenzFarben: referenzFarben,
  );
}
