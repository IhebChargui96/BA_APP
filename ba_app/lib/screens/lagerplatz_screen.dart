// Screen zur Verwaltung der Lagerplaetze.
// Lagerplaetze koennen einem Lagerort zugeordnet und per QR-Code geoeffnet werden.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/lagerort_controller.dart';
import '../controllers/lagerplatz_controller.dart';
import '../helpers/validatoren.dart';
import '../models/lagerplatz.dart';
import 'lagerplatz_inhalt_screen.dart';
import 'qr_scanner_screen.dart';

/// Verwaltet Lagerplaetze und deren Zuordnung zu Lagerorten und QR-Codes.
class LagerplatzScreen extends StatelessWidget {
  LagerplatzScreen({super.key});

  final LagerplatzController lagerplatzController =
      Get.isRegistered<LagerplatzController>()
      ? Get.find<LagerplatzController>()
      : Get.put(LagerplatzController());
  final LagerortController lagerortController =
      Get.isRegistered<LagerortController>()
      ? Get.find<LagerortController>()
      : Get.put(LagerortController());

  // Baut die Lagerplatz-Uebersicht mit Suche, Liste und Dialog-Button auf.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lagerplaetze'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Lagerplatz-ID suchen',
            icon: const Icon(Icons.search),
            onPressed: () => _lagerplatzPerIdSuchen(context),
          ),
          IconButton(
            tooltip: 'Neu laden',
            icon: const Icon(Icons.refresh),
            onPressed: _datenNeuLaden,
          ),
        ],
      ),
      body: Column(
        children: [
          _hinweisKarte(),
          Obx(
            () => lagerplatzController.fehlerText.value.isEmpty
                ? const SizedBox.shrink()
                : _fehlerAnzeige(lagerplatzController.fehlerText.value),
          ),
          Obx(
            () => lagerortController.fehlerText.value.isEmpty
                ? const SizedBox.shrink()
                : _fehlerAnzeige(lagerortController.fehlerText.value),
          ),
          Obx(
            () =>
                lagerplatzController.laedt.value ||
                    lagerortController.laedt.value
                ? const LinearProgressIndicator()
                : const SizedBox.shrink(),
          ),
          Expanded(child: Obx(() => _lagerplatzListe(context))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _lagerplatzDialogOeffnen(context),
        icon: const Icon(Icons.add),
        label: const Text('Lagerplatz'),
      ),
    );
  }

  // Beide parallel laden - im Screen werden Lagerort-Namen direkt
  // angezeigt, also macht sequentielles Laden keinen Sinn.
  Future<void> _datenNeuLaden() async {
    await Future.wait([
      lagerortController.lagerorteLaden(),
      lagerplatzController.lagerplaetzeLaden(),
    ]);
  }

  // Sucht einen Lagerplatz ueber seine Datenbank-ID.
  //
  // Zweck:
  // Falls der QR-Code nicht gelesen werden kann, kann der Nutzer die
  // sichtbare ID aus der Lagerplatzliste eingeben. Danach wird derselbe
  // Inhalt-Screen geoeffnet wie beim Antippen oder QR-Code-Scan.
  Future<void> _lagerplatzPerIdSuchen(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String idEingabe = '';
    void absenden(BuildContext dialogContext) {
      if (formKey.currentState?.validate() != true) {
        return;
      }
      final id = int.tryParse(idEingabe.trim());
      if (id == null || id <= 0) {
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(dialogContext).pop(id);
    }

    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Lagerplatz-ID suchen'),
          content: Form(
            key: formKey,
            child: TextFormField(
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lagerplatz-ID',
                hintText: 'z. B. 3',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (text) {
                idEingabe = text;
              },
              validator: (text) {
                final id = int.tryParse((text ?? '').trim());
                if (id == null || id <= 0) {
                  return 'Bitte eine gueltige Lagerplatz-ID eingeben.';
                }
                return null;
              },
              onFieldSubmitted: (_) => absenden(dialogContext),
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
              icon: const Icon(Icons.search),
              label: const Text('Suchen'),
            ),
          ],
        );
      },
    );
    if (id == null) {
      return;
    }
    await lagerplatzController.lagerplaetzeLaden();
    if (!context.mounted) {
      return;
    }
    final lagerplatz = lagerplatzController.lagerplaetze
        .where((l) => l.id == id)
        .firstOrNull;
    if (lagerplatz == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kein Lagerplatz mit der ID $id gefunden.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LagerplatzInhaltScreen(lagerplatz: lagerplatz),
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
                'Lagerplaetze sind konkrete Stellen, z. B. Kiste 1, '
                'Schublade A oder Fach 3. Optional kann ein QR-Code '
                'hinterlegt werden. Der Inhalt kann per QR-Code, '
                'ID-Suche oder durch Antippen des Lagerplatzes angezeigt werden.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Roter Hinweiskasten fuer Fehlertexte aus den Controllern.
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

  // Liste der Lagerplaetze mit Leer-Zustand und Pull-to-Refresh.
  Widget _lagerplatzListe(BuildContext context) {
    if (lagerplatzController.lagerplaetze.isEmpty &&
        !lagerplatzController.laedt.value) {
      return const Center(
        child: Text(
          'Noch keine Lagerplaetze vorhanden.\n'
          'Mit „Lagerplatz“ kann ein neuer Lagerplatz angelegt werden.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _datenNeuLaden,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        itemCount: lagerplatzController.lagerplaetze.length,
        itemBuilder: (context, index) {
          return _lagerplatzKarte(
            context,
            lagerplatzController.lagerplaetze[index],
          );
        },
      ),
    );
  }

  // Einzelne Lagerplatz-Karte mit Lagerort, QR-Code und Aktions-Menue.
  Widget _lagerplatzKarte(BuildContext context, Lagerplatz lagerplatz) {
    final lagerortName = _lagerortName(lagerplatz.lagerortId);
    final qrCode = lagerplatz.qrCode?.trim();
    final hatQrCode = qrCode != null && qrCode.isNotEmpty;
    return Card(
      child: ListTile(
        // Tippen zeigt den Inhalt des Lagerplatzes an. Dies ist der
        // ID-basierte Weg, falls der QR-Code nicht gescannt werden kann.
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LagerplatzInhaltScreen(lagerplatz: lagerplatz),
            ),
          );
        },
        leading: CircleAvatar(
          child: Icon(hatQrCode ? Icons.qr_code_2 : Icons.inventory_2),
        ),
        title: Text(
          lagerplatz.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'ID: ${lagerplatz.id ?? "-"}\n'
          'Lagerort: $lagerortName\n'
          'QR-Code: ${hatQrCode ? qrCode : "nicht hinterlegt"}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (aktion) {
            if (aktion == 'bearbeiten') {
              _lagerplatzDialogOeffnen(context, lagerplatz: lagerplatz);
            }
            if (aktion == 'loeschen') {
              _lagerplatzLoeschenBestaetigen(context, lagerplatz);
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

  // Uebersetzt eine Lagerort-ID in den Namen fuer die Anzeige.
  String _lagerortName(int? lagerortId) {
    if (lagerortId == null) return 'kein Lagerort';
    final lagerort = lagerortController.lagerorte
        .where((l) => l.id == lagerortId)
        .firstOrNull;
    return lagerort?.name ?? 'unbekannter Lagerort';
  }

  // Dialog zum Anlegen oder Bearbeiten eines Lagerplatzes.
  // Erfasst Name, Lagerort und optionalen QR-Code (auch per Scan) und speichert.
  Future<void> _lagerplatzDialogOeffnen(
    BuildContext context, {
    Lagerplatz? lagerplatz,
  }) async {
    await lagerortController.lagerorteLaden();
    if (!context.mounted) {
      return;
    }
    final istBearbeiten = lagerplatz != null;
    final formKey = GlobalKey<FormState>();
    String nameEingabe = lagerplatz?.name ?? '';
    String qrEingabe = lagerplatz?.qrCode ?? '';
    int? ausgewaehlterLagerortId = lagerplatz?.lagerortId;
    void absenden(BuildContext dialogContext) {
      if (formKey.currentState?.validate() != true) {
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      final qrText = qrEingabe.trim();
      Navigator.of(dialogContext).pop(
        _LagerplatzDialogErgebnis(
          name: nameEingabe.trim(),
          qrCode: qrText.isEmpty ? null : qrText,
          lagerortId: ausgewaehlterLagerortId,
        ),
      );
    }

    final ergebnis = await showDialog<_LagerplatzDialogErgebnis>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(
                istBearbeiten
                    ? 'Lagerplatz bearbeiten'
                    : 'Lagerplatz hinzufuegen',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (istBearbeiten) ...[
                        TextFormField(
                          initialValue: lagerplatz.id?.toString() ?? '-',
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Die ID wird nach dem Speichern automatisch vergeben '
                            'und danach in der Liste angezeigt.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        key: ValueKey('name-$nameEingabe'),
                        initialValue: nameEingabe,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'z. B. Kiste 1, Schublade A, Fach 3',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (text) {
                          nameEingabe = text;
                        },
                        validator: (text) => Validatoren.pruefePflichtfeld(
                          text ?? '',
                          'einen Namen',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _lagerortAuswahl(
                        ausgewaehlterLagerortId: ausgewaehlterLagerortId,
                        onChanged: (wert) {
                          setStateDialog(() {
                            ausgewaehlterLagerortId = wert;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('qr-$qrEingabe'),
                        initialValue: qrEingabe,
                        decoration: const InputDecoration(
                          labelText: 'QR-Code optional',
                          hintText: 'z. B. LP-001 oder KISTE-1',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (text) {
                          qrEingabe = text;
                        },
                        onFieldSubmitted: (_) => absenden(dialogContext),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final code = await Navigator.of(dialogContext)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => const QrScannerScreen(
                                      returnRawValue: true,
                                    ),
                                  ),
                                );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            if (code != null && code.trim().isNotEmpty) {
                              final text = code.trim();
                              setStateDialog(() {
                                qrEingabe = text;
                                // Wenn noch kein Name eingetragen wurde,
                                // wird der QR-Code-Inhalt auch als Name
                                // verwendet, z. B. REGAL-A.
                                if (nameEingabe.trim().isEmpty) {
                                  nameEingabe = text;
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('QR-Code scannen'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'QR-Code scannen oder manuell eintippen. '
                          'Wenn der Name leer ist, wird der QR-Code-Inhalt '
                          'auch als Name uebernommen.',
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
      },
    );
    if (ergebnis == null || ergebnis.name.trim().isEmpty) {
      return;
    }
    final neuerLagerplatz = Lagerplatz(
      id: lagerplatz?.id,
      name: ergebnis.name,
      qrCode: ergebnis.qrCode,
      lagerortId: ergebnis.lagerortId,
    );
    try {
      int? gespeicherteId;
      if (lagerplatz == null) {
        gespeicherteId = await lagerplatzController.lagerplatzHinzufuegen(
          neuerLagerplatz,
        );
      } else {
        await lagerplatzController.lagerplatzAktualisieren(neuerLagerplatz);
        gespeicherteId = lagerplatz.id;
      }
      await _datenNeuLaden();
      if (!context.mounted) {
        return;
      }
      final idText = gespeicherteId == null ? '' : ' ID: $gespeicherteId';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lagerplatz wurde gespeichert.$idText')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lagerplatz konnte nicht gespeichert werden.'),
        ),
      );
    }
  }

  // Dropdown zur Auswahl des Lagerorts im Dialog.
  Widget _lagerortAuswahl({
    required int? ausgewaehlterLagerortId,
    required ValueChanged<int?> onChanged,
  }) {
    // Nur Lagerorte mit Id koennen referenziert werden.
    final lagerorteMitId = lagerortController.lagerorte
        .where((l) => l.id != null)
        .toList();
    final dropdownWert = _lagerortExistiert(ausgewaehlterLagerortId)
        ? ausgewaehlterLagerortId
        : null;
    return DropdownButtonFormField<int?>(
      initialValue: dropdownWert,
      decoration: const InputDecoration(
        labelText: 'Lagerort',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Kein Lagerort')),
        ...lagerorteMitId.map(
          (lagerort) => DropdownMenuItem<int?>(
            value: lagerort.id,
            child: Text(lagerort.name),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  // Prueft, ob der gewaehlte Lagerort noch vorhanden ist (z. B. nicht geloescht).
  bool _lagerortExistiert(int? id) {
    if (id == null) return false;
    return lagerortController.lagerorte.any((l) => l.id == id);
  }

  // Sicherheitsabfrage vor dem Loeschen eines Lagerplatzes.
  Future<void> _lagerplatzLoeschenBestaetigen(
    BuildContext context,
    Lagerplatz lagerplatz,
  ) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Lagerplatz loeschen'),
          content: Text(
            'Soll der Lagerplatz "${lagerplatz.name}" wirklich geloescht werden?',
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
    if (bestaetigt != true || lagerplatz.id == null) {
      return;
    }
    try {
      await lagerplatzController.lagerplatzLoeschen(lagerplatz.id!);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lagerplatz wurde geloescht.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lagerplatz konnte nicht geloescht werden. '
            'Vielleicht sind noch Produkte zugeordnet.',
          ),
        ),
      );
    }
  }
}

// Rueckgabe des Dialogs: Name, optionaler QR-Code und Lagerort-ID.
class _LagerplatzDialogErgebnis {
  final String name;
  final String? qrCode;
  final int? lagerortId;
  const _LagerplatzDialogErgebnis({
    required this.name,
    this.qrCode,
    this.lagerortId,
  });
}
