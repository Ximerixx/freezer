import 'package:flutter/material.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/definitions.dart';
import 'package:freezer/settings.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;

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
    http.Response response = await http.get(url);
    //Parse
    dom.Document document = parse(response.body);
    dom.Element element = document.getElementById('resource');

    //Some are URL encoded
    try {
      return jsonDecode(element.innerHtml);
    } catch (e) {
      return jsonDecode(Uri.decodeComponent(element.innerHtml));
    }
  }

  Future<SpotifyPlaylist> playlist(String uri) async {
    //Load data
    String url = getEmbedUrl(uri);
    Map data = await getEmbedData(url);
    //Parse
    SpotifyPlaylist playlist = SpotifyPlaylist.fromJson(data);
    return playlist;
  }

  //Get Deezer track ID from Spotify URI
  Future<String> convertTrack(String uri) async {
    Map data = await getEmbedData(getEmbedUrl(uri));
    SpotifyTrack track = SpotifyTrack.fromJson(data);
    Map deezer = await deezerAPI.callPublicApi('track/isrc:' + track.isrc);
    return deezer['id'].toString();
  }

  //Get Deezer album ID by UPC
  Future<String> convertAlbum(String uri) async {
    Map data = await getEmbedData(getEmbedUrl(uri));
    SpotifyAlbum album = SpotifyAlbum.fromJson(data);
    Map deezer = await deezerAPI.callPublicApi('album/upc:' + album.upc);
    return deezer['id'].toString();
  }
  
  Future convertPlaylist(SpotifyPlaylist playlist, {bool downloadOnly = false, BuildContext context, AudioQuality quality}) async {
    doneImporting = false;
    importingSpotifyPlaylist = playlist;

    //Create Deezer playlist
    String playlistId;
    if (!downloadOnly)
      playlistId = await deezerAPI.createPlaylist(playlist.name, description: playlist.description);

    //Search for tracks
    List<Track> downloadTracks = [];
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
          downloadTracks.add(Track(id: id));
        track.state = TrackImportState.OK;
      } catch (e) {
        //On error
        track.state = TrackImportState.ERROR;
      }

      //Download
      if (downloadOnly)
        await downloadManager.addOfflinePlaylist(
          Playlist(trackCount: downloadTracks.length, tracks: downloadTracks, title: playlist.name),
          private: false,
          quality: quality
        );

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

class SpotifyAlbum {
  String upc;

  SpotifyAlbum({this.upc});

  //JSON
  factory SpotifyAlbum.fromJson(Map json) => SpotifyAlbum(
    upc: json['external_ids']['upc']
  );
}

enum TrackImportState {
  NONE,
  ERROR,
  OK
}