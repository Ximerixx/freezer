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
        {}
    ..albumSort =
        _$enumDecodeNullable(_$AlbumSortTypeEnumMap, json['albumSort']) ??
            AlbumSortType.DEFAULT
    ..artistSort =
        _$enumDecodeNullable(_$ArtistSortTypeEnumMap, json['artistSort']) ??
            ArtistSortType.DEFAULT
    ..libraryPlaylistSort = _$enumDecodeNullable(
            _$PlaylistSortTypeEnumMap, json['libraryPlaylistSort']) ??
        PlaylistSortType.DEFAULT
    ..trackSort = _$enumDecodeNullable(_$SortTypeEnumMap, json['trackSort']) ??
        SortType.DEFAULT
    ..threadsWarning = json['threadsWarning'] as bool ?? false;
}

Map<String, dynamic> _$CacheToJson(Cache instance) => <String, dynamic>{
      'libraryTracks': instance.libraryTracks,
      'history': instance.history,
      'playlistSort': instance.playlistSort
          ?.map((k, e) => MapEntry(k, _$SortTypeEnumMap[e])),
      'albumSort': _$AlbumSortTypeEnumMap[instance.albumSort],
      'artistSort': _$ArtistSortTypeEnumMap[instance.artistSort],
      'libraryPlaylistSort':
          _$PlaylistSortTypeEnumMap[instance.libraryPlaylistSort],
      'trackSort': _$SortTypeEnumMap[instance.trackSort],
      'threadsWarning': instance.threadsWarning,
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

const _$AlbumSortTypeEnumMap = {
  AlbumSortType.DEFAULT: 'DEFAULT',
  AlbumSortType.REVERSE: 'REVERSE',
  AlbumSortType.ALPHABETIC: 'ALPHABETIC',
  AlbumSortType.ARTIST: 'ARTIST',
};

const _$ArtistSortTypeEnumMap = {
  ArtistSortType.DEFAULT: 'DEFAULT',
  ArtistSortType.REVERSE: 'REVERSE',
  ArtistSortType.POPULARITY: 'POPULARITY',
  ArtistSortType.ALPHABETIC: 'ALPHABETIC',
};

const _$PlaylistSortTypeEnumMap = {
  PlaylistSortType.DEFAULT: 'DEFAULT',
  PlaylistSortType.REVERSE: 'REVERSE',
  PlaylistSortType.ALPHABETIC: 'ALPHABETIC',
  PlaylistSortType.USER: 'USER',
  PlaylistSortType.TRACK_COUNT: 'TRACK_COUNT',
};
