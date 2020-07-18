// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) {
  return Settings(
    downloadPath: json['downloadPath'] as String,
    arl: json['arl'] as String,
  )
    ..wifiQuality =
        _$enumDecodeNullable(_$AudioQualityEnumMap, json['wifiQuality']) ??
            AudioQuality.MP3_320
    ..mobileQuality =
        _$enumDecodeNullable(_$AudioQualityEnumMap, json['mobileQuality']) ??
            AudioQuality.MP3_128
    ..offlineQuality =
        _$enumDecodeNullable(_$AudioQualityEnumMap, json['offlineQuality']) ??
            AudioQuality.FLAC
    ..downloadQuality =
        _$enumDecodeNullable(_$AudioQualityEnumMap, json['downloadQuality']) ??
            AudioQuality.FLAC
    ..downloadNaming =
        _$enumDecodeNullable(_$DownloadNamingEnumMap, json['downloadNaming']) ??
            DownloadNaming.DEFAULT
    ..downloadFolderStructure = json['downloadFolderStructure'] as bool ?? true
    ..theme =
        _$enumDecodeNullable(_$ThemesEnumMap, json['theme']) ?? Themes.Light
    ..primaryColor = Settings._colorFromJson(json['primaryColor'] as int)
    ..useArtColor = json['useArtColor'] as bool ?? false
    ..deezerLanguage = json['deezerLanguage'] as String ?? 'en'
    ..deezerCountry = json['deezerCountry'] as String ?? 'US'
    ..logListen = json['logListen'] as bool ?? false;
}

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'arl': instance.arl,
      'wifiQuality': _$AudioQualityEnumMap[instance.wifiQuality],
      'mobileQuality': _$AudioQualityEnumMap[instance.mobileQuality],
      'offlineQuality': _$AudioQualityEnumMap[instance.offlineQuality],
      'downloadQuality': _$AudioQualityEnumMap[instance.downloadQuality],
      'downloadPath': instance.downloadPath,
      'downloadNaming': _$DownloadNamingEnumMap[instance.downloadNaming],
      'downloadFolderStructure': instance.downloadFolderStructure,
      'theme': _$ThemesEnumMap[instance.theme],
      'primaryColor': Settings._colorToJson(instance.primaryColor),
      'useArtColor': instance.useArtColor,
      'deezerLanguage': instance.deezerLanguage,
      'deezerCountry': instance.deezerCountry,
      'logListen': instance.logListen,
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$AudioQualityEnumMap = {
  AudioQuality.MP3_128: 'MP3_128',
  AudioQuality.MP3_320: 'MP3_320',
  AudioQuality.FLAC: 'FLAC',
};

const _$DownloadNamingEnumMap = {
  DownloadNaming.DEFAULT: 'DEFAULT',
  DownloadNaming.STANDALONE: 'STANDALONE',
};

const _$ThemesEnumMap = {
  Themes.Light: 'Light',
  Themes.Dark: 'Dark',
  Themes.Deezer: 'Deezer',
  Themes.Black: 'Black',
};
