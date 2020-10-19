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
    ..language = json['language'] as String
    ..ignoreInterruptions = json['ignoreInterruptions'] as bool ?? false
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
    ..downloadFilename =
        json['downloadFilename'] as String ?? '%artists% - %title%'
    ..albumFolder = json['albumFolder'] as bool ?? true
    ..artistFolder = json['artistFolder'] as bool ?? true
    ..albumDiscFolder = json['albumDiscFolder'] as bool ?? false
    ..overwriteDownload = json['overwriteDownload'] as bool ?? false
    ..downloadThreads = json['downloadThreads'] as int ?? 2
    ..playlistFolder = json['playlistFolder'] as bool ?? false
    ..downloadLyrics = json['downloadLyrics'] as bool ?? true
    ..trackCover = json['trackCover'] as bool ?? false
    ..albumCover = json['albumCover'] as bool ?? true
    ..nomediaFiles = json['nomediaFiles'] as bool ?? false
    ..theme =
        _$enumDecodeNullable(_$ThemesEnumMap, json['theme']) ?? Themes.Dark
    ..useSystemTheme = json['useSystemTheme'] as bool ?? false
    ..primaryColor = Settings._colorFromJson(json['primaryColor'] as int)
    ..useArtColor = json['useArtColor'] as bool ?? false
    ..deezerLanguage = json['deezerLanguage'] as String ?? 'en'
    ..deezerCountry = json['deezerCountry'] as String ?? 'US'
    ..logListen = json['logListen'] as bool ?? false
    ..proxyAddress = json['proxyAddress'] as String;
}

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'language': instance.language,
      'ignoreInterruptions': instance.ignoreInterruptions,
      'arl': instance.arl,
      'wifiQuality': _$AudioQualityEnumMap[instance.wifiQuality],
      'mobileQuality': _$AudioQualityEnumMap[instance.mobileQuality],
      'offlineQuality': _$AudioQualityEnumMap[instance.offlineQuality],
      'downloadQuality': _$AudioQualityEnumMap[instance.downloadQuality],
      'downloadPath': instance.downloadPath,
      'downloadFilename': instance.downloadFilename,
      'albumFolder': instance.albumFolder,
      'artistFolder': instance.artistFolder,
      'albumDiscFolder': instance.albumDiscFolder,
      'overwriteDownload': instance.overwriteDownload,
      'downloadThreads': instance.downloadThreads,
      'playlistFolder': instance.playlistFolder,
      'downloadLyrics': instance.downloadLyrics,
      'trackCover': instance.trackCover,
      'albumCover': instance.albumCover,
      'nomediaFiles': instance.nomediaFiles,
      'theme': _$ThemesEnumMap[instance.theme],
      'useSystemTheme': instance.useSystemTheme,
      'primaryColor': Settings._colorToJson(instance.primaryColor),
      'useArtColor': instance.useArtColor,
      'deezerLanguage': instance.deezerLanguage,
      'deezerCountry': instance.deezerCountry,
      'logListen': instance.logListen,
      'proxyAddress': instance.proxyAddress,
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
  AudioQuality.ASK: 'ASK',
};

const _$ThemesEnumMap = {
  Themes.Light: 'Light',
  Themes.Dark: 'Dark',
  Themes.Deezer: 'Deezer',
  Themes.Black: 'Black',
};
