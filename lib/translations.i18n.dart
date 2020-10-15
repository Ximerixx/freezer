import 'package:flutter/material.dart';
import 'package:freezer/languages/crowdin.dart';
import 'package:freezer/languages/en_us.dart';
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
  const Locale('tr', 'TR'),
  const Locale('ro', 'RO'),
  const Locale('id', 'ID'),
  const Locale('fa', 'IR'),
  const Locale('pl', 'PL'),
  const Locale('fil', 'PH')
];

extension Localization on String {
  static var _t = Translations.byLocale("en_US") + language_en_us + crowdin;

  String get i18n => localize(this, _t);
}
