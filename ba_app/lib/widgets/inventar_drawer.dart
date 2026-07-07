// Navigations-Drawer der Hauptseite.
//
// Enthaelt:
// - Kopfbereich mit Produktanzahl und Bestandswarnung
// - Navigation zu Uebersicht, Scan, QR-Scanner und Verwaltung
// - CSV-Export und CSV-Import
// - Umschalter Hell/Dunkel
//
// Die Navigation passiert direkt hier im Widget (Get.to), weil sie
// keinen Zustand des Inventar-Screens braucht. Nur drei Dinge gehen
// als Callbacks zurueck an den Screen: das Neuladen der Daten nach
// einem Verwaltungs-Screen sowie CSV-Export und -Import, weil diese
// Ablaeufe Zugriff auf die Controller und Dialoge des Screens brauchen.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../screens/kategorie_screen.dart';
import '../screens/lagerort_screen.dart';
import '../screens/lagerplatz_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/scan_auswahl_screen.dart';
import '../screens/statistik_screen.dart';

/// Seitliches Menue der Hauptseite mit Navigation und CSV-Aktionen.
class InventarDrawer extends StatelessWidget {
  // Kennzahlen fuer den Kopfbereich. Der Screen liefert sie fertig,
  // damit der Drawer keinen ProduktController braucht.
  final int anzahlProdukte;
  final int anzahlNiedrigeBestaende;
  // Wird nach dem Besuch eines Verwaltungs-Screens aufgerufen,
  // damit die Inventar-Liste geaenderte Kategorien, Lagerorte
  // oder Lagerplaetze sofort anzeigt.
  final Future<void> Function() onDatenNeuLaden;
  // CSV-Aktionen laufen im Inventar-Screen, weil sie dessen
  // Controller, Dialoge und Snackbars verwenden.
  final VoidCallback onCsvExport;
  final VoidCallback onCsvImport;

  const InventarDrawer({
    super.key,
    required this.anzahlProdukte,
    required this.anzahlNiedrigeBestaende,
    required this.onDatenNeuLaden,
    required this.onCsvExport,
    required this.onCsvImport,
  });

  // Holt den ThemeController fuer den Hell/Dunkel-Umschalter.
  // Existiert er schon (Registrierung in main.dart), wird die
  // vorhandene Instanz wiederverwendet, sonst angelegt.
  ThemeController get _themeController => Get.isRegistered<ThemeController>()
      ? Get.find<ThemeController>()
      : Get.put(ThemeController());

  // Baut den Drawer mit Kopfbereich, Navigation, CSV-Aktionen und Darstellungs-Umschalter auf.
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _drawerHeader(context),
          _drawerEintrag(
            icon: Icons.inventory_2,
            titel: 'Inventar',
            onTap: () => Get.back(),
          ),
          _drawerEintrag(
            icon: Icons.bar_chart,
            titel: 'Uebersicht',
            untertitel: 'Kennzahlen',
            onTap: () {
              Get.back();
              Get.to(() => const StatistikScreen());
            },
          ),
          const Divider(),
          _drawerEintrag(
            icon: Icons.search,
            titel: 'Widerstand scannen',
            untertitel: 'Methode auswaehlen',
            onTap: () {
              Get.back();
              Get.to(() => const ScanAuswahlScreen());
            },
          ),
          _drawerEintrag(
            icon: Icons.qr_code_scanner,
            titel: 'QR-Code scannen',
            untertitel: 'Lagerplatz finden',
            onTap: () {
              Get.back();
              Get.to(() => const QrScannerScreen());
            },
          ),
          const Divider(),
          // Nach den Verwaltungs-Screens werden die Daten neu geladen,
          // damit geaenderte Namen sofort in den Produktkarten stehen.
          _drawerEintrag(
            icon: Icons.category,
            titel: 'Kategorien',
            onTap: () async {
              Get.back();
              await Get.to(() => KategorieScreen());
              await onDatenNeuLaden();
            },
          ),
          _drawerEintrag(
            icon: Icons.place,
            titel: 'Lagerorte',
            onTap: () async {
              Get.back();
              await Get.to(() => LagerortScreen());
              await onDatenNeuLaden();
            },
          ),
          _drawerEintrag(
            icon: Icons.inventory,
            titel: 'Lagerplaetze',
            onTap: () async {
              Get.back();
              await Get.to(() => LagerplatzScreen());
              await onDatenNeuLaden();
            },
          ),
          const Divider(),
          _drawerEintrag(
            icon: Icons.share,
            titel: 'CSV exportieren',
            untertitel: 'Inventar und Ausleihen sichern',
            onTap: () {
              Get.back();
              onCsvExport();
            },
          ),
          _drawerEintrag(
            icon: Icons.file_upload,
            titel: 'CSV importieren',
            untertitel: 'Datenbestand ersetzen',
            onTap: () {
              Get.back();
              onCsvImport();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.brightness_6),
                SizedBox(width: 16),
                Text('Darstellung'),
              ],
            ),
          ),
          // Hell/Dunkel-Umschalter. Obx umfasst nur diesen Bereich,
          // weil sich hier nur der Darstellungsmodus aendert.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Obx(
              () => SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: ThemeController.modusHell,
                    label: Text('Hell'),
                  ),
                  ButtonSegment(
                    value: ThemeController.modusDunkel,
                    label: Text('Dunkel'),
                  ),
                ],
                selected: {_themeController.modus.value},
                onSelectionChanged: (auswahl) =>
                    _themeController.setzeModus(auswahl.first),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kopfbereich mit App-Name, Produktanzahl und - falls vorhanden -
  /// der Anzahl der Produkte unter Mindestmenge in Rot.
  Widget _drawerHeader(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inversePrimary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'InventarScan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Produkte: $anzahlProdukte'),
          if (anzahlNiedrigeBestaende > 0)
            Text(
              'Wenig auf Lager: $anzahlNiedrigeBestaende',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  /// Einheitlicher Menue-Eintrag mit Symbol, Titel und optionalem Untertitel.
  Widget _drawerEintrag({
    required IconData icon,
    required String titel,
    String? untertitel,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(titel),
      subtitle: untertitel == null ? null : Text(untertitel),
      onTap: onTap,
    );
  }
}
