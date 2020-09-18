import 'package:dio/dio.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/definitions.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart';

import 'dart:convert';
import 'dart:async';


SpotifyAPI spotify = SpotifyAPI();

class SpotifyAPI {

  SpotifyPlaylist importingSpotifyPlaylist;
  StreamController importingStream = StreamController.broadcast();
  bool doneImporting;

  //Parse spotify URL to URI (spotify:track:1234)
  String parseUrl(String url) {
    Uri uri = Uri.parse(url);
    if (uri.pathSegments.length > 3) return null; //Invalid URL
    if (uri.pathSegments.length == 3) return 'spotify:${uri.pathSegments[1]}:${uri.pathSegments[2]}';
    if (uri.pathSegments.length == 2) return 'spotify:${uri.pathSegments[0]}:${uri.pathSegments[1]}';
    return null;
  }

  //Get spotify embed url from uri
  String getEmbedUrl(String uri) => 'https://embed.spotify.com/?uri=$uri';

  //Extract JSON data form spotify embed page
  Future<Map> getEmbedData(String url) async {
    //Fetch
    Dio dio = Dio();
    Response response = await dio.get(url);
    //Parse
    Document document = parse(response.data);
    Element element = document.getElementById('resource');
    return jsonDecode(element.innerHtml);
  }

  Future<SpotifyPlaylist> playlist(String uri) async {
    //Load data
    String url = getEmbedUrl(uri);
    Map data = await getEmbedData(url);
    //Parse
    SpotifyPlaylist playlist = SpotifyPlaylist.fromJson(data);
    return playlist;
  }
  
  Future convertPlaylist(SpotifyPlaylist playlist, {bool downloadOnly = false}) async {
    doneImporting = false;
    importingSpotifyPlaylist = playlist;

    //Create Deezer playlist
    String playlistId;
    if (!downloadOnly)
      playlistId = await deezerAPI.createPlaylist(playlist.name, description: playlist.description);

    //Search for tracks
    for (SpotifyTrack track in playlist.tracks) {
      Map deezer;
      try {
        //Search
        deezer = await deezerAPI.callPublicApi('track/isrc:' + track.isrc);
        if (deezer.containsKey('error')) throw Exception();
        String id = deezer['id'].toString();
        //Add
        if (!downloadOnly)
          await deezerAPI.addToPlaylist(id, playlistId);
        if (downloadOnly)
          await downloadManager.addOfflineTrack(Track(id: id), private: false);
        track.state = TrackImportState.OK;
      } catch (e) {
        //On error
        track.state = TrackImportState.ERROR;
      }
      //Add playlist id to stream, stream is for updating ui only
      importingStream.add(playlistId);
      importingSpotifyPlaylist = playlist;
    }
    doneImporting = true;
    //Return DEEZER playlist id
    return playlistId;
  }

}

class SpotifyTrack {
  String title;
  String artists;
  String isrc;
  TrackImportState state = TrackImportState.NONE;

  SpotifyTrack({this.title, this.artists, this.isrc});

  //JSON
  factory SpotifyTrack.fromJson(Map json) => SpotifyTrack(
    title: json['name'],
    artists: json['artists'].map((j) => j['name']).toList().join(', '),
    isrc: json['external_ids']['isrc']
  );
}

class SpotifyPlaylist {
  String name;
  String description;
  List<SpotifyTrack> tracks;
  String image;

  SpotifyPlaylist({this.name, this.description, this.tracks, this.image});

  //JSON
  factory SpotifyPlaylist.fromJson(Map json) => SpotifyPlaylist(
    name: json['name'],
    description: json['description'],
    image: (json['images'].length > 0) ? json['images'][0]['url'] : null,
    tracks: json['tracks']['items'].map<SpotifyTrack>((j) => SpotifyTrack.fromJson(j['track'])).toList()
  );
}

enum TrackImportState {
  NONE,
  ERROR,
  OK
}