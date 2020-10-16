import 'dart:async';

import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/ui/details_screens.dart';
import 'package:freezer/ui/library.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'dart:io';
import 'dart:convert';

part 'cache.g.dart';

Cache cache;

//Cache for miscellaneous things
@JsonSerializable()
class Cache {

  //ID's of tracks that are in library
  List<String> libraryTracks = [];

  //Track ID of logged track, to prevent duplicates
  @JsonKey(ignore: true)
  String loggedTrackId;

  @JsonKey(defaultValue: [])
  List<Track> history = [];

  //Cache playlist sort type {id: sort}
  @JsonKey(defaultValue: {})
  Map<String, SortType> playlistSort;

  //Sort
  @JsonKey(defaultValue: AlbumSortType.DEFAULT)
  AlbumSortType albumSort;
  @JsonKey(defaultValue: ArtistSortType.DEFAULT)
  ArtistSortType artistSort;
  @JsonKey(defaultValue: PlaylistSortType.DEFAULT)
  PlaylistSortType libraryPlaylistSort;
  @JsonKey(defaultValue: SortType.DEFAULT)
  SortType trackSort;

  //Sleep timer
  @JsonKey(ignore: true)
  DateTime sleepTimerTime;
  @JsonKey(ignore: true)
  StreamSubscription sleepTimer;

  @JsonKey(defaultValue: const [])
  List<String> searchHistory;

  //If download threads warning was shown
  @JsonKey(defaultValue: false)
  bool threadsWarning;

  Cache({this.libraryTracks});

  //Wrapper to test if track is favorite against cache
  bool checkTrackFavorite(Track t) {
    if (t.favorite != null && t.favorite) return true;
    if (libraryTracks == null || libraryTracks.length == 0) return false;
    return libraryTracks.contains(t.id);
  }

  //Save, load
  static Future<String> getPath() async {
    return p.join((await getApplicationDocumentsDirectory()).path, 'metacache.json');
  }

  static Future<Cache> load() async {
    File file = File(await Cache.getPath());
    //Doesn't exist, create new
    if (!(await file.exists())) {
      Cache c = Cache();
      await c.save();
      return c;
    }
    return Cache.fromJson(jsonDecode(await file.readAsString()));
  }

  Future save() async {
    File file = File(await Cache.getPath());
    file.writeAsString(jsonEncode(this.toJson()));
  }

  //JSON
  factory Cache.fromJson(Map<String, dynamic> json) => _$CacheFromJson(json);
  Map<String, dynamic> toJson() => _$CacheToJson(this);
}