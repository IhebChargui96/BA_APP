// Zusaetzliche BGR-Regeln fuer die Ringfarbenerkennung.
//
// Die Regeln sind keine Normwerte. Sie wurden aus den eigenen Testbildern
// der Python-Vorarbeit abgeleitet und fuer den getesteten Stand der Dart-App
// angepasst. Sie helfen bei typischen Verwechslungen, zum Beispiel
// Rot/Braun, Orange/Rot oder Gelb/Gold.
//
// Ein einzelner Grenzwert entscheidet dabei nicht allein. Meist werden mehrere
// Bedingungen zusammen geprueft: ein Mindestwert eines Kanals, ein Abstand
// zwischen zwei Kanaelen und der Unterschied zwischen hellstem und dunkelstem Kanal.
//
// Wenn keine Regel passt, wird in farb_finder.dart der Vergleich mit den
// Referenzfarben der Farbtafel im L*a*b*-Farbraum verwendet.

import 'bgr_farbe.dart';

// Rot: Der Rotanteil muss hell genug sein und deutlich ueber Gruen und Blau liegen.
const int rotMinRotanteil = 80;
const int rotMinAbstandRotZuGruen = 30;
const int rotMinAbstandRotZuBlau = 30;
// Ab dieser Rot-Helligkeit wird Rot ohne die Zusatzbedingung b > g angenommen.
const int rotMinRotanteilFuerSichereErkennung = 145;

// Braun: ebenfalls roetlich, aber dunkler und weniger klar als Rot.
const int braunMinAbstandRotZuGruen = 10;
const int braunMinAbstandRotZuBlau = 10;
const int braunMaxRotanteil = 130;
const int braunMaxAbstandGruenZuBlau = 30;

// Orange: Rot hoch, Gruen vorhanden, Blau eher niedrig.
const int orangeMinRotanteil = 100;
const int orangeMinGruenanteil = 40;
const int orangeMaxBlauanteil = 80;
const int orangeMaxGruenanteil = 100;
const int orangeMinAbstandRotZuGruen = 40;
const int orangeMinAbstandGruenZuBlau = 10;

// Gelb: Rot und Gruen hoch, Blau deutlich kleiner.
const int gelbMinRotanteil = 130;
const int gelbMinGruenanteil = 110;
const int gelbMinAbstandGruenZuBlau = 60;
const int gelbMaxAbstandRotZuGruen = 50;

// Gruen: G muss klar ueber R und B liegen.
// Die Werte sind in der Dart-App strenger als in der Python-Vorarbeit.
// Sie gehoeren zum getesteten Stand der App.
const int gruenMinGruenanteil = 90;
const int gruenMinAbstandGruenZuRot = 25;
const int gruenMinAbstandGruenZuBlau = 35;

// Blau: B muss klar ueber R liegen.
const int blauMinBlauanteil = 80;
const int blauMinAbstandBlauZuRot = 30;

// Violett: R und B sichtbar, G niedriger.
const int violettMinRotanteil = 60;
const int violettMinBlauanteil = 50;
const int violettMaxUnterschiedRotZuBlau = 25;
const int violettMinAbstandRotZuGruen = 10;
const int violettMinAbstandBlauZuGruen = 10;

// Gold: Rot liegt ueber Gruen, Gruen liegt ueber Blau, aber Gruen nicht so hoch wie bei Gelb.
const int goldMinRotanteil = 90;
const int goldMinAbstandRotZuGruen = 20;
const int goldMinAbstandGruenZuBlau = 12;
const int goldMaxGruenanteil = 130;

// Silber: hell und fast grau, also Kanaele nah beieinander.
const int silberMinHellsterKanal = 105;
const int silberMaxKanalUnterschied = 18;

// Schwarz: dunkel und Kanaele nah beieinander.
const int schwarzMaxHellsterKanal = 80;
const int schwarzMaxKanalUnterschied = 18;

/// Prueft, ob ein BGR-Wert als Schwarz gewertet werden kann.
///
/// Schwarz soll dunkel sein und keine starke Farbrichtung haben. Ein dunkles
/// Rot oder Braun wird deshalb vorher ausgeschlossen.
bool istDunkel(BgrFarbe farbe) {
  final maximum = _max3(farbe.b, farbe.g, farbe.r);
  final minimum = _min3(farbe.b, farbe.g, farbe.r);

  final rotDominant = (farbe.r - farbe.g) >= 10 && (farbe.r - farbe.b) >= 10;

  if (rotDominant) {
    return false;
  }

  return maximum < schwarzMaxHellsterKanal &&
      (maximum - minimum) <= schwarzMaxKanalUnterschied;
}

/// Prueft, ob ein BGR-Wert als Rot gewertet werden kann.
bool istRot(BgrFarbe farbe) {
  final rotDominant =
      farbe.r >= rotMinRotanteil &&
      (farbe.r - farbe.g) >= rotMinAbstandRotZuGruen &&
      (farbe.r - farbe.b) >= rotMinAbstandRotZuBlau;

  if (!rotDominant) {
    return false;
  }

  // Helles Rot wird direkt akzeptiert. Bei dunklerem Rot hilft b > g,
  // damit braune Messwerte nicht zu schnell als Rot gelten.
  return farbe.r >= rotMinRotanteilFuerSichereErkennung || farbe.b > farbe.g;
}

/// Prueft, ob ein BGR-Wert als Braun gewertet werden kann.
bool istBraun(BgrFarbe farbe) {
  final rotDominant =
      (farbe.r - farbe.g) >= braunMinAbstandRotZuGruen &&
      (farbe.r - farbe.b) >= braunMinAbstandRotZuBlau;

  final nichtZuHell = farbe.r < braunMaxRotanteil;
  final nichtGold = (farbe.g - farbe.b) < braunMaxAbstandGruenZuBlau;
  final gruenNichtUnterBlau = farbe.g >= farbe.b;

  return rotDominant && nichtZuHell && nichtGold && gruenNichtUnterBlau;
}

/// Prueft, ob ein BGR-Wert als Orange gewertet werden kann.
bool istOrange(BgrFarbe farbe) {
  // G-B >= 10 verhindert, dass rote Ringe zu schnell als Orange gelten.
  return farbe.r >= orangeMinRotanteil &&
      farbe.g >= orangeMinGruenanteil &&
      farbe.b <= orangeMaxBlauanteil &&
      farbe.g < orangeMaxGruenanteil &&
      (farbe.r - farbe.g) >= orangeMinAbstandRotZuGruen &&
      (farbe.g - farbe.b) >= orangeMinAbstandGruenZuBlau;
}

/// Prueft, ob ein BGR-Wert als Gelb gewertet werden kann.
bool istGelb(BgrFarbe farbe) {
  return farbe.g >= gelbMinGruenanteil &&
      farbe.r >= gelbMinRotanteil &&
      (farbe.g - farbe.b) >= gelbMinAbstandGruenZuBlau &&
      (farbe.r - farbe.g) <= gelbMaxAbstandRotZuGruen;
}

/// Prueft, ob ein BGR-Wert als Gruen gewertet werden kann.
bool istGruen(BgrFarbe farbe) {
  return farbe.g >= gruenMinGruenanteil &&
      (farbe.g - farbe.r) >= gruenMinAbstandGruenZuRot &&
      (farbe.g - farbe.b) >= gruenMinAbstandGruenZuBlau;
}

/// Prueft, ob ein BGR-Wert als Blau gewertet werden kann.
bool istBlau(BgrFarbe farbe) {
  return farbe.b >= blauMinBlauanteil &&
      farbe.b > farbe.r &&
      (farbe.b - farbe.r) >= blauMinAbstandBlauZuRot;
}

/// Prueft, ob ein BGR-Wert als Violett gewertet werden kann.
bool istViolett(BgrFarbe farbe) {
  // Die Abstaende zu Gruen trennen Violett besser von dunklem Braun.
  return farbe.r >= violettMinRotanteil &&
      farbe.b >= violettMinBlauanteil &&
      (farbe.r - farbe.g) >= violettMinAbstandRotZuGruen &&
      (farbe.b - farbe.g) >= violettMinAbstandBlauZuGruen &&
      (farbe.r - farbe.b).abs() <= violettMaxUnterschiedRotZuBlau;
}

/// Prueft, ob ein BGR-Wert als Gold gewertet werden kann.
bool istGold(BgrFarbe farbe) {
  return farbe.r >= goldMinRotanteil &&
      (farbe.r - farbe.g) >= goldMinAbstandRotZuGruen &&
      (farbe.g - farbe.b) >= goldMinAbstandGruenZuBlau &&
      farbe.g < goldMaxGruenanteil;
}

/// Prueft, ob ein BGR-Wert als Silber gewertet werden kann.
bool istSilber(BgrFarbe farbe) {
  final maximum = _max3(farbe.b, farbe.g, farbe.r);
  final minimum = _min3(farbe.b, farbe.g, farbe.r);

  return maximum >= silberMinHellsterKanal &&
      (maximum - minimum) <= silberMaxKanalUnterschied;
}

// Groesster der drei Kanalwerte.
int _max3(int a, int b, int c) {
  int m = a;

  if (b > m) {
    m = b;
  }

  if (c > m) {
    m = c;
  }

  return m;
}

// Kleinster der drei Kanalwerte.
int _min3(int a, int b, int c) {
  int m = a;

  if (b < m) {
    m = b;
  }

  if (c < m) {
    m = c;
  }

  return m;
}
