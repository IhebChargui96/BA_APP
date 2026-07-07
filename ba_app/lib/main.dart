// Einstiegspunkt der App InventarScan.
//
// Diese Datei richtet die App beim Start ein. Dazu gehoeren die
// Bildschirmausrichtung, die dauerhaft benoetigten Controller und der
// YOLO/TFLite-Service fuer den Scanbereich.
//
// Das YOLO-Modell wird nur vorbereitet. Die Berechnung des Widerstandswerts
// erfolgt spaeter getrennt in der Farbringauswertung.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'controllers/ausleihe_controller.dart';
import 'controllers/kategorie_controller.dart';
import 'controllers/lagerort_controller.dart';
import 'controllers/lagerplatz_controller.dart';
import 'controllers/produkt_controller.dart';
import 'controllers/theme_controller.dart';
import 'screens/inventar_screen.dart';
import 'services/yolo_tflite_service.dart';

/// Startet die App und registriert die zentralen Controller.
///
/// Die Controller bleiben dauerhaft in GetX registriert, damit Produktdaten,
/// Lagerdaten, Ausleihen und Theme-Einstellungen beim Wechsel zwischen
/// verschiedenen Screens erhalten bleiben.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Die Oberflaeche wurde fuer die Hochformat-Nutzung aufgebaut.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Zentrale Controller der Inventarverwaltung.
  // permanent: true bedeutet, dass GetX sie nicht automatisch entfernt,
  // wenn zwischen Screens gewechselt wird.
  Get.put(KategorieController(), permanent: true);
  Get.put(LagerortController(), permanent: true);
  Get.put(LagerplatzController(), permanent: true);
  Get.put(ProduktController(), permanent: true);
  Get.put(AusleiheController(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  // Der YOLO/TFLite-Service wird appweit bereitgestellt.
  // Er lokalisiert spaeter Widerstand und Farbreferenz im Scanbild.
  final yolo = YoloTfliteService();
  Get.put<YoloTfliteService>(yolo, permanent: true);
  // Kein await an dieser Stelle:
  // Die App kann starten, waehrend das Modell im Hintergrund geladen wird.
  unawaited(_yoloImHintergrundLaden(yolo));
  runApp(const InventarScanApp());
}

/// Laedt das YOLO-Modell im Hintergrund.
///
/// Wenn das Laden beim Start fehlschlaegt, bleibt die App trotzdem nutzbar.
/// Der Fehler betrifft dann nur den Scanbereich und kann dort behandelt werden.
Future<void> _yoloImHintergrundLaden(YoloTfliteService yolo) async {
  try {
    await yolo.modellLaden();
  } catch (e) {
    debugPrint('YOLO-Modell konnte beim App-Start nicht geladen werden: $e');
  }
}

/// Wurzel-Widget der App InventarScan.
///
/// Hier wird GetX als Routing- und Zustandsumgebung eingerichtet. Die erste
/// angezeigte Ansicht ist die Inventaransicht.
class InventarScanApp extends StatelessWidget {
  const InventarScanApp({super.key});

  // Richtet GetMaterialApp mit Titel, hellem Startthema und Inventaransicht ein.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'InventarScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 58, 81, 183),
        ),
        useMaterial3: true,
      ),
      home: const InventarScreen(),
    );
  }
}
