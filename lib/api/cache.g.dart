// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cache _$CacheFromJson(Map<String, dynamic> json) {
  return Cache(
    libraryTracks:
        (json['libraryTracks'] as List)?.map((e) => e as String)?.toList(),
  )
    ..history = (json['history'] as List)
            ?.map((e) =>
                e == null ? null : Track.fromJson(e as Map<String, dynamic>))
            ?.toList() ??
        []
    ..playlistSort = (json['playlistSort'] as Map<String, dynamic>)?.map(
          (k, e) => MapEntry(k, _$enumDecodeNullable(_$SortTypeEnumMap, e)),
        ) ??
        {};
}

Map<String, dynamic> _$CacheToJson(Cache instance) => <String, dynamic>{
      'libraryTracks': instance.libraryTracks,
      'history': instance.history,
      'playlistSort': instance.playlistSort
          ?.map((k, e) => MapEntry(k, _$SortTypeEnumMap[e])),
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

const _$SortTypeEnumMap = {
  SortType.DEFAULT: 'DEFAULT',
  SortType.REVERSE: 'REVERSE',
  SortType.ALPHABETIC: 'ALPHABETIC',
  SortType.ARTIST: 'ARTIST',
};
