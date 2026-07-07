// Karte fuer die Ausleihen im Produktformular.
//
// Die Karte zeigt offene Ausleihen eines Produkts und bietet die Aktionen
// neu anlegen, verlaengern und zurueckgeben. Die eigentliche Aenderung laeuft
// ueber die Dialogfunktionen und den AusleiheController.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ausleihe_controller.dart';
import '../models/ausleihe.dart';
import 'ausleihe_dialog.dart';

/// Zeigt die offenen Ausleihen zu einem Produkt im Produktformular.
class AusleiheKarte extends StatelessWidget {
  /// Produkt, dessen offene Ausleihen angezeigt werden.
  final int produktId;
  const AusleiheKarte({super.key, required this.produktId});

  // Baut die Karte mit den offenen Ausleihen und dem Button fuer neue Ausleihen.
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AusleiheController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Obx(() {
          final offeneAusleihen = controller.aktuelleAusleihen
              .where((ausleihe) => ausleihe.produktId == produktId)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.handshake),
                  SizedBox(width: 8),
                  Text(
                    'Ausleihe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (offeneAusleihen.isEmpty)
                const Text(
                  'Aktuell nicht ausgeliehen.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...offeneAusleihen.map((ausleihe) {
                  return _ausleihZeile(context, ausleihe);
                }),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await zeigeNeueAusleiheDialog(
                    context: context,
                    produktId: produktId,
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Neue Ausleihe'),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Baut eine einzelne Ausleihe-Zeile mit Frist, Notiz und Aktionen.
  Widget _ausleihZeile(BuildContext context, Ausleihe ausleihe) {
    final frist = ausleihe.fristdatumParsed;
    final ueberfaellig = ausleihe.istUeberfaellig;
    final farbe = ueberfaellig ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.06),
        border: Border.all(color: farbe.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (ueberfaellig)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.warning_amber, size: 16, color: Colors.red),
                ),
              Expanded(
                child: Text(
                  '${ausleihe.vollerName} - ${ausleihe.menge} Stueck',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (frist != null) ...[
            const SizedBox(height: 4),
            Text(
              'Frist: ${formatDatumKurz(frist)} '
              '(${tageBisFristText(frist)})',
              style: TextStyle(color: ueberfaellig ? Colors.red : null),
            ),
          ],
          if (ausleihe.notiz != null && ausleihe.notiz!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Notiz: ${ausleihe.notiz}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await zeigeVerlaengernDialog(
                      context: context,
                      ausleihe: ausleihe,
                    );
                  },
                  icon: const Icon(Icons.event_repeat, size: 16),
                  label: const Text('Verlaengern'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await zeigeZurueckgebenDialog(
                      context: context,
                      ausleihe: ausleihe,
                    );
                  },
                  icon: const Icon(Icons.assignment_returned, size: 16),
                  label: const Text('Zurueck'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
