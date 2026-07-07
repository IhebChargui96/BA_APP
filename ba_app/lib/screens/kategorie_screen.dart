// Screen zur Verwaltung der Produktkategorien.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/kategorie_controller.dart';
import '../helpers/validatoren.dart';
import '../models/kategorie.dart';

/// Zeigt die Liste der Kategorien und den Dialog zum Anlegen oder Bearbeiten.
class KategorieScreen extends StatelessWidget {
  KategorieScreen({super.key});

  final KategorieController controller = Get.isRegistered<KategorieController>()
      ? Get.find<KategorieController>()
      : Get.put(KategorieController());

  // Baut die Kategorie-Uebersicht mit Liste und Dialog-Button auf.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategorien'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: controller.kategorienLaden,
          ),
        ],
      ),
      // Obx jeweils nur um die reaktiven Teile.
      // Dadurch wird nicht der komplette Scaffold neu gebaut.
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
          Expanded(child: Obx(() => _kategorieListe())),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _kategorieDialogOeffnen(context),
        icon: const Icon(Icons.add),
        label: const Text('Kategorie'),
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
                'Kategorien ordnen Produkte fachlich ein, z. B. Elektronik, '
                'Computer, Werkzeug, Widerstand, Kondensator oder LED.',
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

  // Liste der Kategorien mit Leer-Zustand und Pull-to-Refresh.
  Widget _kategorieListe() {
    if (controller.kategorien.isEmpty && !controller.laedt.value) {
      return const Center(
        child: Text(
          'Noch keine Kategorien vorhanden.\n'
          'Mit "Kategorie" kann eine neue Kategorie angelegt werden.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.kategorienLaden,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: controller.kategorien.length,
        itemBuilder: (context, index) {
          final kategorie = controller.kategorien[index];
          return _kategorieKarte(context, kategorie);
        },
      ),
    );
  }

  // Einzelne Kategorie-Karte mit Bearbeiten- und Loeschen-Menue.
  Widget _kategorieKarte(BuildContext context, Kategorie kategorie) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.category)),
        title: Text(
          kategorie.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          kategorie.id == null
              ? 'Noch nicht gespeichert'
              : 'ID: ${kategorie.id}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (aktion) {
            if (aktion == 'bearbeiten') {
              _kategorieDialogOeffnen(context, kategorie: kategorie);
            }
            if (aktion == 'loeschen') {
              _kategorieLoeschenBestaetigen(context, kategorie);
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

  // Dialog zum Anlegen oder Bearbeiten einer Kategorie und Speichern.
  Future<void> _kategorieDialogOeffnen(
    BuildContext context, {
    Kategorie? kategorie,
  }) async {
    final istBearbeiten = kategorie != null;
    final formKey = GlobalKey<FormState>();
    // Kein TextEditingController im Dialog.
    // Fuer ein einzelnes Textfeld reicht initialValue + onChanged.
    String nameEingabe = kategorie?.name.trim() ?? '';
    void absenden(BuildContext dialogContext) {
      if (formKey.currentState!.validate()) {
        // Tastatur/Fokus schliessen, bevor der Dialog entfernt wird.
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(dialogContext).pop(nameEingabe.trim());
      }
    }

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            istBearbeiten ? 'Kategorie bearbeiten' : 'Kategorie hinzufuegen',
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: nameEingabe,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Widerstand',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (text) {
                nameEingabe = text.trim();
              },
              validator: (text) {
                return Validatoren.pruefePflichtfeld(
                  text ?? '',
                  'einen Kategorienamen',
                );
              },
              onFieldSubmitted: (text) {
                nameEingabe = text.trim();
                absenden(dialogContext);
              },
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
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final neueKategorie = Kategorie(id: kategorie?.id, name: name.trim());
    try {
      if (kategorie == null) {
        await controller.kategorieHinzufuegen(neueKategorie);
      } else {
        await controller.kategorieAktualisieren(neueKategorie);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategorie wurde gespeichert.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategorie konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  // Sicherheitsabfrage vor dem Loeschen einer Kategorie.
  Future<void> _kategorieLoeschenBestaetigen(
    BuildContext context,
    Kategorie kategorie,
  ) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kategorie loeschen'),
          content: Text(
            'Soll die Kategorie "${kategorie.name}" wirklich geloescht werden?',
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
    if (bestaetigt != true || kategorie.id == null) {
      return;
    }
    try {
      await controller.kategorieLoeschen(kategorie.id!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategorie wurde geloescht.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kategorie konnte nicht geloescht werden. '
            'Vielleicht sind noch Produkte zugeordnet.',
          ),
        ),
      );
    }
  }
}
