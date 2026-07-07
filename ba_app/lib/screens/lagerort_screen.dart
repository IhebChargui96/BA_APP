// Screen zur Verwaltung der Lagerorte.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/lagerort_controller.dart';
import '../helpers/validatoren.dart';
import '../models/lagerort.dart';

/// Verwaltet Lagerorte wie Raum, Schrank, Regal oder freien Ort.
class LagerortScreen extends StatelessWidget {
  LagerortScreen({super.key});

  final LagerortController controller = Get.isRegistered<LagerortController>()
      ? Get.find<LagerortController>()
      : Get.put(LagerortController());

  // Baut die Lagerort-Uebersicht mit Liste und Dialog-Button auf.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lagerorte'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: controller.lagerorteLaden,
          ),
        ],
      ),
      // Obx nur um die reaktiven Teile.
      // Dadurch wird nicht der komplette Scaffold neu aufgebaut.
      body: Column(
        children: [
          _hinweisKarte(),
          Obx(
            () => controller.fehlerText.value.isEmpty
                ? const SizedBox.shrink()
                : _fehlerAnzeige(controller.fehlerText.value),
          ),
          Obx(
            () => controller.laedt.value
                ? const LinearProgressIndicator()
                : const SizedBox.shrink(),
          ),
          Expanded(child: Obx(() => _lagerortListe())),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _lagerortDialogOeffnen(context),
        icon: const Icon(Icons.add),
        label: const Text('Lagerort'),
      ),
    );
  }

  // Info-Karte am Kopf der Seite.
  Widget _hinweisKarte() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lagerorte sind grobe Orte, z. B. Labor, Arbeitszimmer '
                'oder Werkstatt. HsH-Raumcodes wie 1B.0.29 werden erkannt.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Roter Hinweiskasten fuer Fehlertexte aus dem Controller.
  Widget _fehlerAnzeige(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(text, style: TextStyle(color: Colors.red.shade900)),
    );
  }

  // Liste der Lagerorte mit Leer-Zustand und Pull-to-Refresh.
  Widget _lagerortListe() {
    if (controller.lagerorte.isEmpty && !controller.laedt.value) {
      return const Center(
        child: Text(
          'Noch keine Lagerorte vorhanden.\n'
          'Mit „Lagerort“ kann ein neuer Lagerort angelegt werden.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.lagerorteLaden,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: controller.lagerorte.length,
        itemBuilder: (context, index) {
          final lagerort = controller.lagerorte[index];
          return _lagerortKarte(context, lagerort);
        },
      ),
    );
  }

  // Einzelne Lagerort-Karte. Zeigt bei erkanntem HsH-Raumcode ein anderes Icon.
  Widget _lagerortKarte(BuildContext context, Lagerort lagerort) {
    final beschreibung = lagerort.beschreibung?.trim();
    final hatBeschreibung = beschreibung != null && beschreibung.isNotEmpty;
    final hatRaumcode = Validatoren.enthaeltRaumCode(lagerort.name);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(hatRaumcode ? Icons.meeting_room : Icons.place),
        ),
        title: Text(
          lagerort.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          hatBeschreibung
              ? beschreibung
              : hatRaumcode
              ? 'HsH-Raumcode'
              : 'Freier Lagerort',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (aktion) {
            if (aktion == 'bearbeiten') {
              _lagerortDialogOeffnen(context, lagerort: lagerort);
            }
            if (aktion == 'loeschen') {
              _lagerortLoeschenBestaetigen(context, lagerort);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'bearbeiten',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Bearbeiten'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'loeschen',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Loeschen'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog zum Anlegen oder Bearbeiten eines Lagerorts (Name und Beschreibung).
  Future<void> _lagerortDialogOeffnen(
    BuildContext context, {
    Lagerort? lagerort,
  }) async {
    final istBearbeiten = lagerort != null;
    final formKey = GlobalKey<FormState>();
    // Kein TextEditingController im Dialog.
    // Fuer diese zwei Felder reichen initialValue + onChanged.
    String nameEingabe = lagerort?.name ?? '';
    String beschreibungEingabe = lagerort?.beschreibung ?? '';
    void absenden(BuildContext dialogContext) {
      if (formKey.currentState?.validate() != true) {
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      final name = Validatoren.formatiereLagerort(nameEingabe);
      final beschreibungText = beschreibungEingabe.trim();
      Navigator.of(dialogContext).pop(
        _LagerortDialogErgebnis(
          name: name,
          beschreibung: beschreibungText.isEmpty ? null : beschreibungText,
        ),
      );
    }

    final ergebnis = await showDialog<_LagerortDialogErgebnis>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            istBearbeiten ? 'Lagerort bearbeiten' : 'Lagerort hinzufuegen',
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: nameEingabe,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'z. B. Labor 1B.0.29 oder Arbeitszimmer',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (text) {
                      nameEingabe = text;
                    },
                    validator: (text) {
                      return Validatoren.pruefeLagerortName(text ?? '');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: beschreibungEingabe,
                    decoration: const InputDecoration(
                      labelText: 'Beschreibung optional',
                      hintText: 'z. B. Schrank neben dem Arbeitsplatz',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 3,
                    onChanged: (text) {
                      beschreibungEingabe = text;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Beispiele: Labor 1B.0.29, Werkstatt, Arbeitszimmer',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              onPressed: () => absenden(dialogContext),
              icon: const Icon(Icons.save),
              label: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    if (ergebnis == null || ergebnis.name.trim().isEmpty) {
      return;
    }
    final neuerLagerort = Lagerort(
      id: lagerort?.id,
      name: ergebnis.name,
      beschreibung: ergebnis.beschreibung,
    );
    try {
      if (lagerort == null) {
        await controller.lagerortHinzufuegen(neuerLagerort);
      } else {
        await controller.lagerortAktualisieren(neuerLagerort);
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lagerort wurde gespeichert.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lagerort konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  // Sicherheitsabfrage vor dem Loeschen eines Lagerorts.
  Future<void> _lagerortLoeschenBestaetigen(
    BuildContext context,
    Lagerort lagerort,
  ) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Lagerort loeschen'),
          content: Text(
            'Soll der Lagerort "${lagerort.name}" wirklich geloescht werden?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete),
              label: const Text('Loeschen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
    if (bestaetigt != true || lagerort.id == null) {
      return;
    }
    try {
      await controller.lagerortLoeschen(lagerort.id!);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lagerort wurde geloescht.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lagerort konnte nicht geloescht werden. '
            'Vielleicht sind noch Lagerplaetze zugeordnet.',
          ),
        ),
      );
    }
  }
}

// Ergebnis des Lagerort-Dialogs: Name und optionale Beschreibung.
class _LagerortDialogErgebnis {
  final String name;
  final String? beschreibung;
  const _LagerortDialogErgebnis({required this.name, this.beschreibung});
}
