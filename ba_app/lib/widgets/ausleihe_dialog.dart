// Dialoge fuer Ausleihe-Aktionen.
//
// Die Funktionen werden von Produktformular und Ausleihen-Anzeige genutzt.
// Sie pruefen Eingaben, rufen den AusleiheController auf und geben dem
// aufrufenden Screen zurueck, ob sich Daten geaendert haben.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ausleihe_controller.dart';
import '../models/ausleihe.dart';

/// Formatiert ein Datum kurz fuer die Anzeige in Ausleihe-Dialogen.
String formatDatumKurz(DateTime datum) {
  final tag = datum.day.toString().padLeft(2, '0');
  final monat = datum.month.toString().padLeft(2, '0');
  return '$tag.$monat.${datum.year}';
}

/// Gibt einen kurzen Text zur Frist aus, zum Beispiel heute oder ueberfaellig.
String tageBisFristText(DateTime frist) {
  final heute = _nurDatum(DateTime.now());
  final fristTag = _nurDatum(frist);
  final diff = fristTag.difference(heute).inDays;
  if (diff > 1) return 'in $diff Tagen';
  if (diff == 1) return 'in 1 Tag';
  if (diff == 0) return 'heute faellig';
  final ueberfaellig = diff.abs();
  if (ueberfaellig == 1) return 'seit 1 Tag ueberfaellig';
  return 'seit $ueberfaellig Tagen ueberfaellig';
}

/// Entfernt Uhrzeitanteile, damit nur Kalendertage verglichen werden.
DateTime _nurDatum(DateTime datum) {
  return DateTime(datum.year, datum.month, datum.day);
}

/// Oeffnet den Dialog zum Anlegen einer neuen Ausleihe.
///
/// Vor dem Speichern wird geprueft, wie viele Stueck noch verfuegbar sind.
Future<bool> zeigeNeueAusleiheDialog({
  required BuildContext context,
  required int produktId,
}) async {
  if (!context.mounted) return false;
  final controller = Get.find<AusleiheController>();
  int verfuegbar;
  try {
    verfuegbar = await controller.verfuegbareMengeFuerProdukt(produktId);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verfuegbare Menge konnte nicht geladen werden: $e'),
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  if (verfuegbar <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aktuell ist kein Stueck fuer die Ausleihe verfuegbar.'),
      ),
    );
    return false;
  }
  final formKey = GlobalKey<FormState>();
  String vorname = '';
  String nachname = '';
  String mengeText = '1';
  String notiz = '';
  DateTime ausleihdatum = DateTime.now();
  DateTime fristdatum = DateTime.now().add(const Duration(days: 14));
  String? datumFehler;
  final ergebnis = await showDialog<_NeueAusleiheDialogErgebnis>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          void absenden() {
            if (formKey.currentState?.validate() != true) return;
            if (_nurDatum(fristdatum).isBefore(_nurDatum(ausleihdatum))) {
              setStateDialog(() {
                datumFehler =
                    'Die Frist darf nicht vor dem Ausleihdatum liegen.';
              });
              return;
            }
            final menge = int.tryParse(mengeText.trim());
            if (menge == null || menge < 1 || menge > verfuegbar) return;
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(dialogContext).pop(
              _NeueAusleiheDialogErgebnis(
                vorname: vorname.trim(),
                nachname: nachname.trim(),
                menge: menge,
                ausleihdatum: ausleihdatum,
                fristdatum: fristdatum,
                notiz: notiz.trim().isEmpty ? null : notiz.trim(),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Neue Ausleihe'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verfuegbar: $verfuegbar Stueck',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextFormField(
                      autofocus: true,
                      initialValue: vorname,
                      decoration: const InputDecoration(
                        labelText: 'Vorname *',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (wert) => vorname = wert,
                      validator: (wert) {
                        if (wert == null || wert.trim().isEmpty) {
                          return 'Bitte Vorname eingeben.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: nachname,
                      decoration: const InputDecoration(
                        labelText: 'Nachname *',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (wert) => nachname = wert,
                      validator: (wert) {
                        if (wert == null || wert.trim().isEmpty) {
                          return 'Bitte Nachname eingeben.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: mengeText,
                      decoration: InputDecoration(
                        labelText: 'Menge',
                        helperText: 'Maximal $verfuegbar Stueck verfuegbar.',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (wert) => mengeText = wert,
                      validator: (wert) {
                        final menge = int.tryParse((wert ?? '').trim());
                        if (menge == null || menge < 1) {
                          return 'Mindestens 1.';
                        }
                        if (menge > verfuegbar) {
                          return 'Es sind nur noch $verfuegbar Stueck verfuegbar.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ausleihdatum'),
                      subtitle: Text(formatDatumKurz(ausleihdatum)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final gewaehlt = await showDatePicker(
                          context: dialogContext,
                          initialDate: ausleihdatum,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (!dialogContext.mounted) return;
                        if (gewaehlt != null) {
                          setStateDialog(() {
                            ausleihdatum = gewaehlt;
                            datumFehler = null;
                            if (_nurDatum(
                              fristdatum,
                            ).isBefore(_nurDatum(ausleihdatum))) {
                              fristdatum = ausleihdatum.add(
                                const Duration(days: 14),
                              );
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Frist'),
                      subtitle: Text(formatDatumKurz(fristdatum)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final gewaehlt = await showDatePicker(
                          context: dialogContext,
                          initialDate: fristdatum,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (!dialogContext.mounted) return;
                        if (gewaehlt != null) {
                          setStateDialog(() {
                            fristdatum = gewaehlt;
                            datumFehler = null;
                          });
                        }
                      },
                    ),
                    if (datumFehler != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          datumFehler!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: notiz,
                      decoration: const InputDecoration(
                        labelText: 'Notiz (optional)',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onChanged: (wert) => notiz = wert,
                      onFieldSubmitted: (_) => absenden(),
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
                onPressed: absenden,
                icon: const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
            ],
          );
        },
      );
    },
  );
  if (ergebnis == null) return false;
  try {
    await controller.ausleihen(
      Ausleihe(
        produktId: produktId,
        vorname: ergebnis.vorname,
        nachname: ergebnis.nachname,
        menge: ergebnis.menge,
        ausleihdatum: ergebnis.ausleihdatum.toIso8601String(),
        fristdatum: ergebnis.fristdatum.toIso8601String(),
        notiz: ergebnis.notiz,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ausleihe wurde gespeichert.')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ausleihe konnte nicht gespeichert werden: $e')),
      );
    }
    return false;
  }
}

/// Oeffnet den Dialog zum Verlaengern einer bestehenden Ausleihe.
Future<bool> zeigeVerlaengernDialog({
  required BuildContext context,
  required Ausleihe ausleihe,
}) async {
  if (!context.mounted || ausleihe.id == null) return false;
  final aktuelleFrist = ausleihe.fristdatumParsed ?? DateTime.now();
  final heute = _nurDatum(DateTime.now());
  final vorschlag = aktuelleFrist.add(const Duration(days: 14));
  DateTime neueFrist = _nurDatum(vorschlag).isBefore(heute)
      ? heute.add(const Duration(days: 14))
      : vorschlag;
  final gewaehlt = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            title: const Text('Ausleihe verlaengern'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('An: ${ausleihe.vollerName}'),
                const SizedBox(height: 4),
                Text('Bisherige Frist: ${formatDatumKurz(aktuelleFrist)}'),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Neue Frist'),
                  subtitle: Text(formatDatumKurz(neueFrist)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final datum = await showDatePicker(
                      context: dialogContext,
                      initialDate: neueFrist,
                      firstDate: heute,
                      lastDate: DateTime(2100),
                    );
                    if (!dialogContext.mounted) return;
                    if (datum != null) {
                      setStateDialog(() => neueFrist = datum);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(neueFrist),
                icon: const Icon(Icons.event_repeat),
                label: const Text('Verlaengern'),
              ),
            ],
          );
        },
      );
    },
  );
  if (gewaehlt == null) return false;
  try {
    final controller = Get.find<AusleiheController>();
    await controller.verlaengern(ausleiheId: ausleihe.id!, neueFrist: gewaehlt);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ausleihe wurde verlaengert.')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ausleihe konnte nicht verlaengert werden: $e')),
      );
    }
    return false;
  }
}

/// Fragt nach und markiert eine Ausleihe danach als zurueckgegeben.
Future<bool> zeigeZurueckgebenDialog({
  required BuildContext context,
  required Ausleihe ausleihe,
}) async {
  if (!context.mounted || ausleihe.id == null) return false;
  final bestaetigt = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Ausleihe zurueckgeben'),
        content: Text(
          'Soll die Ausleihe an ${ausleihe.vollerName} '
          '(${ausleihe.menge} Stueck) als zurueckgegeben markiert werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.assignment_returned),
            label: const Text('Zurueckgeben'),
          ),
        ],
      );
    },
  );
  if (bestaetigt != true) return false;
  try {
    final controller = Get.find<AusleiheController>();
    await controller.zurueckgeben(ausleihe.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ausleihe wurde zurueckgegeben.')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ausleihe konnte nicht zurueckgegeben werden: $e'),
        ),
      );
    }
    return false;
  }
}

/// Lokales Ergebnisobjekt fuer den Dialog zum Anlegen einer Ausleihe.
class _NeueAusleiheDialogErgebnis {
  final String vorname;
  final String nachname;
  final int menge;
  final DateTime ausleihdatum;
  final DateTime fristdatum;
  final String? notiz;
  const _NeueAusleiheDialogErgebnis({
    required this.vorname,
    required this.nachname,
    required this.menge,
    required this.ausleihdatum,
    required this.fristdatum,
    this.notiz,
  });
}
