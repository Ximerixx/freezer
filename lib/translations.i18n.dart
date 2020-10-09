import 'package:flutter/material.dart';
import 'package:freezer/languages/ar_ar.dart';
import 'package:freezer/languages/de_de.dart';
import 'package:freezer/languages/el_gr.dart';
import 'package:freezer/languages/en_us.dart';
import 'package:freezer/languages/es_es.dart';
import 'package:freezer/languages/fil_ph.dart';
import 'package:freezer/languages/fr_fr.dart';
import 'package:freezer/languages/he_il.dart';
import 'package:freezer/languages/hr_hr.dart';
import 'package:freezer/languages/it_it.dart';
import 'package:freezer/languages/ko_ko.dart';
import 'package:freezer/languages/pt_br.dart';
import 'package:freezer/languages/ru_ru.dart';
import 'package:i18n_extension/i18n_extension.dart';

const supportedLocales = [
  const Locale('en', 'US'),
  const Locale('ar', 'AR'),
  const Locale('pt', 'BR'),
  const Locale('it', 'IT'),
  const Locale('de', 'DE'),
  const Locale('ru', 'RU'),
  const Locale('es', 'ES'),
  const Locale('hr', 'HR'),
  const Locale('el', 'GR'),
  const Locale('ko', 'KO'),
  const Locale('fr', 'FR'),
  const Locale('he', 'IL'),
  const Locale('fil', 'PH')
];

extension Localization on String {
  static var _t = Translations.byLocale("en_US") +
    language_en_us + language_ar_ar + language_pt_br + language_it_it + language_de_de + language_ru_ru +
    language_fil_ph + language_es_es + language_el_gr + language_hr_hr + language_ko_ko + language_fr_fr +
    language_he_il;

  String get i18n => localize(this, _t);
}
