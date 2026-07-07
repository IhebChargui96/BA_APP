import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Verwaltet das helle und dunkle Design der App.
///
/// Die Umschaltung erfolgt ueber Get.changeTheme aus GetX. Der gewaehlte
/// Modus wird als Text gehalten, damit die Auswahl in der UI markiert
/// werden kann.
///
/// Die Auswahl wird in dieser Version nicht dauerhaft gespeichert. Nach
/// einem Neustart startet die App wieder im hellen Modus.
class ThemeController extends GetxController {
  // Benannte Konstanten vermeiden Tippfehler bei den Modusnamen.
  static const String modusHell = 'hell';
  static const String modusDunkel = 'dunkel';

  final modus = modusHell.obs;

  /// Merkt den gewaehlten Modus und schaltet das Theme um.
  void setzeModus(String neuerModus) {
    modus.value = neuerModus;
    if (neuerModus == modusDunkel) {
      Get.changeTheme(_dunklesThema());
    } else {
      Get.changeTheme(_hellesThema());
    }
  }

  /// Helles Standard-Theme der App.
  ThemeData _hellesThema() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 58, 81, 183),
      ),
      useMaterial3: true,
    );
  }

  /// Dunkles Theme mit derselben Grundfarbe.
  ThemeData _dunklesThema() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color.fromARGB(255, 58, 81, 183),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
