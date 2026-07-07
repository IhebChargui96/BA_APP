import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/statistik_controller.dart';

// Dashboard mit Kennzahlen zur lokalen Inventarverwaltung.
//
// Enthalten:
// - Kopfkarte mit Gesamtstatus
// - Kennzahl-Karten
// - einfache Balkenanzeige ohne externes Chart-Paket
// - kurze Tabelle fuer wichtige Bestandswerte

/// Zeigt Kennzahlen, Bestandsstatus und einfache Balkenanzeigen.
class StatistikScreen extends StatelessWidget {
  const StatistikScreen({super.key});

  // Baut das Dashboard mit Statuskarte, Kennzahlen, Balken und Tabelle auf.
  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<StatistikController>()
        ? Get.find<StatistikController>()
        : Get.put(StatistikController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uebersicht'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: controller.datenAktualisieren,
          ),
        ],
      ),
      body: Obx(
        () => RefreshIndicator(
          onRefresh: controller.datenAktualisieren,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (controller.laedt) const LinearProgressIndicator(),
              if (controller.laedt) const SizedBox(height: 12),
              _statusKarte(context, controller),
              const SizedBox(height: 12),
              _kennzahlenRaster(context, controller),
              const SizedBox(height: 12),
              _balkenDiagramm(context, controller),
              const SizedBox(height: 12),
              _tabelle(context, controller),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Kopfkarte mit Gesamtstatus des Inventars.
  Widget _statusKarte(BuildContext context, StatistikController controller) {
    final farben = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: farben.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.dashboard_outlined,
              color: farben.onPrimaryContainer,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'InventarScan Dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: farben.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.anzahlProdukte} Produkte · '
              '${controller.gesamtStueckzahl} Stueck gesamt · '
              '${controller.verlieheneStueckzahl} verliehen',
              style: TextStyle(color: farben.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            _statusHinweis(context, controller),
          ],
        ),
      ),
    );
  }

  // Zeigt, ob der Inventarstatus unkritisch ist oder Warnungen vorliegen.
  Widget _statusHinweis(BuildContext context, StatistikController controller) {
    final kritisch = controller.anzahlNiedrigerBestand;
    final ueberfaellig = controller.anzahlUeberfaellig;
    String text;
    IconData icon;
    if (kritisch == 0 && ueberfaellig == 0) {
      text = 'Inventarstatus unkritisch.';
      icon = Icons.check_circle_outline;
    } else {
      text =
          '$kritisch Produkte unter Mindestmenge'
          '${ueberfaellig > 0 ? ' · $ueberfaellig Ausleihen ueberfaellig' : ''}.';
      icon = Icons.warning_amber;
    }
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  // Raster mit allen Kennzahl-Karten (2 oder 3 Spalten je nach Breite).
  Widget _kennzahlenRaster(
    BuildContext context,
    StatistikController controller,
  ) {
    final kennzahlen = [
      _Kennzahl(
        titel: 'Produkte',
        wert: controller.anzahlProdukte,
        icon: Icons.inventory_2,
      ),
      _Kennzahl(
        titel: 'Stueck gesamt',
        wert: controller.gesamtStueckzahl,
        icon: Icons.numbers,
      ),
      _Kennzahl(
        titel: 'Verfuegbar',
        wert: controller.verfuegbareStueckzahl,
        icon: Icons.check_circle_outline,
      ),
      _Kennzahl(
        titel: 'Verliehene Stueck',
        wert: controller.verlieheneStueckzahl,
        icon: Icons.handshake,
      ),
      _Kennzahl(
        titel: 'Kategorien',
        wert: controller.anzahlKategorien,
        icon: Icons.category,
      ),
      _Kennzahl(
        titel: 'Lagerorte',
        wert: controller.anzahlLagerorte,
        icon: Icons.place,
      ),
      _Kennzahl(
        titel: 'Lagerplaetze',
        wert: controller.anzahlLagerplaetze,
        icon: Icons.grid_view,
      ),
      _Kennzahl(
        titel: 'Unter Mindestmenge',
        wert: controller.anzahlNiedrigerBestand,
        icon: Icons.warning_amber,
      ),
      _Kennzahl(
        titel: 'Offene Ausleihen',
        wert: controller.anzahlOffeneAusleihen,
        icon: Icons.assignment_outlined,
      ),
      _Kennzahl(
        titel: 'Ueberfaellig',
        wert: controller.anzahlUeberfaellig,
        icon: Icons.priority_high,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final spalten = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kennzahlen.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: spalten,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            return _kennzahlKarte(context, kennzahlen[index]);
          },
        );
      },
    );
  }

  // Einzelne Kennzahl-Karte mit Symbol, Wert und Titel.
  Widget _kennzahlKarte(BuildContext context, _Kennzahl kennzahl) {
    final farben = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(kennzahl.icon, size: 30, color: farben.primary),
            const SizedBox(height: 8),
            Text(
              '${kennzahl.wert}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              kennzahl.titel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // Karte mit einfachen Balken fuer den Bestandsstatus (ohne Chart-Paket).
  Widget _balkenDiagramm(BuildContext context, StatistikController controller) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bereichTitel(
              context,
              icon: Icons.bar_chart,
              titel: 'Bestandsstatus',
            ),
            const SizedBox(height: 12),
            _balkenZeile(
              context,
              titel: 'Verfuegbar',
              wert: controller.verfuegbareStueckzahl,
              gesamt: controller.gesamtStueckzahl,
            ),
            const SizedBox(height: 12),
            _balkenZeile(
              context,
              titel: 'Verliehen',
              wert: controller.verlieheneStueckzahl,
              gesamt: controller.gesamtStueckzahl,
            ),
            const SizedBox(height: 12),
            _balkenZeile(
              context,
              titel: 'Unter Mindestmenge',
              wert: controller.anzahlNiedrigerBestand,
              gesamt: controller.anzahlProdukte,
            ),
          ],
        ),
      ),
    );
  }

  // Einzelne Balkenzeile mit Titel, Werteangabe und Fortschrittsbalken.
  Widget _balkenZeile(
    BuildContext context, {
    required String titel,
    required int wert,
    required int gesamt,
  }) {
    final anteil = _anteil(wert, gesamt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titel)),
            Text('$wert / $gesamt'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: anteil,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  // Karte mit einer kurzen Auswertungstabelle.
  Widget _tabelle(BuildContext context, StatistikController controller) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bereichTitel(
              context,
              icon: Icons.table_chart,
              titel: 'Kurze Auswertung',
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Wert')),
                  DataColumn(label: Text('Bedeutung')),
                ],
                rows: [
                  _datenZeile(
                    status: 'Gesamtbestand',
                    wert: '${controller.gesamtStueckzahl}',
                    bedeutung: 'alle eingetragenen Stueckzahlen',
                  ),
                  _datenZeile(
                    status: 'Verfuegbar',
                    wert: '${controller.verfuegbareStueckzahl}',
                    bedeutung: 'nicht aktuell ausgeliehen',
                  ),
                  _datenZeile(
                    status: 'Verliehen',
                    wert: '${controller.verlieheneStueckzahl}',
                    bedeutung: 'Summe offener Ausleihen',
                  ),
                  _datenZeile(
                    status: 'Kritisch',
                    wert: '${controller.anzahlNiedrigerBestand}',
                    bedeutung: 'unter Mindestmenge',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Einzelne Tabellenzeile (Status, Wert, Bedeutung).
  DataRow _datenZeile({
    required String status,
    required String wert,
    required String bedeutung,
  }) {
    return DataRow(
      cells: [
        DataCell(Text(status)),
        DataCell(Text(wert)),
        DataCell(Text(bedeutung)),
      ],
    );
  }

  // Ueberschrift eines Karten-Abschnitts mit Symbol.
  Widget _bereichTitel(
    BuildContext context, {
    required IconData icon,
    required String titel,
  }) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(
          titel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Rechnet einen Anteil zwischen 0 und 1 fuer die Balken aus.
  // Division durch 0 und Werte ausserhalb 0 bis 1 werden abgefangen.
  double _anteil(int wert, int gesamt) {
    if (gesamt <= 0) {
      return 0;
    }
    final anteil = wert / gesamt;
    if (anteil < 0) {
      return 0;
    }
    if (anteil > 1) {
      return 1;
    }
    return anteil;
  }
}

// Datenobjekt fuer eine Kennzahl-Karte (Titel, Wert, Symbol).
class _Kennzahl {
  final String titel;
  final int wert;
  final IconData icon;
  const _Kennzahl({
    required this.titel,
    required this.wert,
    required this.icon,
  });
}
