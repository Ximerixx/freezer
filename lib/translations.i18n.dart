import 'package:flutter/material.dart';
import 'package:freezer/languages/ar_ar.dart';
import 'package:freezer/languages/de_de.dart';
import 'package:freezer/languages/en_us.dart';
import 'package:freezer/languages/it_it.dart';
import 'package:freezer/languages/pt_br.dart';
import 'package:freezer/languages/ru_ru.dart';
import 'package:i18n_extension/i18n_extension.dart';

const supportedLocales = [
  const Locale('en', 'US'),
  const Locale('ar', 'AR'),
  const Locale('pt', 'BR'),
  const Locale('it', 'IT'),
  const Locale('de', 'DE'),
  const Locale('ru', 'RU')
];

extension Localization on String {
  static var _t = Translations.byLocale("en_US") +
    language_en_us + language_ar_ar + language_pt_br + language_it_it + language_de_de + language_ru_ru;

  String get i18n => localize(this, _t);
}
