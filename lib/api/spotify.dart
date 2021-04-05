import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/importer.dart';
import 'package:html/parser.dart';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';
import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class SpotifyScrapper {

  //Parse spotify URL to URI (spotify:track:1234)
  static String parseUrl(String url) {
    Uri uri = Uri.parse(url);
    if (uri.pathSegments.length > 3) return null; //Invalid URL
    if (uri.pathSegments.length == 3) return 'spotify:${uri.pathSegments[1]}:${uri.pathSegments[2]}';
    if (uri.pathSegments.length == 2) return 'spotify:${uri.pathSegments[0]}:${uri.pathSegments[1]}';
    return null;
  }

  //Get spotify embed url from uri
  static String getEmbedUrl(String uri) => 'https://embed.spotify.com/?uri=$uri';

  //https://link.tospotify.com/ or https://spotify.app.link/
  static Future resolveLinkUrl(String url) async {
    http.Response response = await http.get(Uri.parse(url));
    Match match = RegExp(r'window\.top\.location = validate\("(.+)"\);').firstMatch(response.body);
    return match.group(1);
  }

  static Future resolveUrl(String url) async {
    if (url.contains("link.tospotify") || url.contains("spotify.app.link")) {
      return parseUrl(await resolveLinkUrl(url));
    }
    return parseUrl(url);
  }

  //Extract JSON data form spotify embed page
  static Future<Map> getEmbedData(String url) async {
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

  static Future<SpotifyPlaylist> playlist(String uri) async {
    //Load data
    String url = getEmbedUrl(uri);
    Map data = await getEmbedData(url);
    //Parse
    SpotifyPlaylist playlist = SpotifyPlaylist.fromJson(data);
    return playlist;
  }

  //Get Deezer track ID from Spotify URI
  static Future<String> convertTrack(String uri) async {
    Map data = await getEmbedData(getEmbedUrl(uri));
    SpotifyTrack track = SpotifyTrack.fromJson(data);
    Map deezer = await deezerAPI.callPublicApi('track/isrc:' + track.isrc);
    return deezer['id'].toString();
  }

  //Get Deezer album ID by UPC
  static Future<String> convertAlbum(String uri) async {
    Map data = await getEmbedData(getEmbedUrl(uri));
    SpotifyAlbum album = SpotifyAlbum.fromJson(data);
    Map deezer = await deezerAPI.callPublicApi('album/upc:' + album.upc);
    return deezer['id'].toString();
  }

}

class SpotifyTrack {
  String title;
  List<String> artists;
  String isrc;

  SpotifyTrack({this.title, this.artists, this.isrc});

  //JSON
  factory SpotifyTrack.fromJson(Map json) => SpotifyTrack(
    title: json['name'],
    artists: json['artists'].map<String>((a) => a["name"].toString()).toList(),
    isrc: json['external_ids']['isrc']
  );

  //Convert track to importer track
  ImporterTrack toImporter() {
    return ImporterTrack(title, artists, isrc: isrc);
  }

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

  //Convert to importer tracks
  List<ImporterTrack> toImporter() {
    return tracks.map((t) => t.toImporter()).toList();
  }
}

class SpotifyAlbum {
  String upc;

  SpotifyAlbum({this.upc});

  //JSON
  factory SpotifyAlbum.fromJson(Map json) => SpotifyAlbum(
    upc: json['external_ids']['upc']
  );
}


class SpotifyAPIWrapper {

  HttpServer _server;
  SpotifyApi spotify;
  User me;

  Future authorize(String clientId, String clientSecret) async {
    //Spotify
    SpotifyApiCredentials credentials = SpotifyApiCredentials(clientId, clientSecret);
    spotify = SpotifyApi(credentials);
    //Create server
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 42069);
    String responseUri;
    //Get URL
    final grant = SpotifyApi.authorizationCodeGrant(credentials);
    final redirectUri = "http://localhost:42069";
    final scopes = ['user-read-private', 'playlist-read-private', 'playlist-read-collaborative', 'user-library-read'];
    final authUri = grant.getAuthorizationUrl(Uri.parse(redirectUri), scopes: scopes);
    launch(authUri.toString());
    //Wait for code
    await for (HttpRequest request in _server) {
      //Exit window
      request.response.headers.set("Content-Type", "text/html; charset=UTF-8");
      request.response.write("<body><h1>You can close this page and go back to Freezer.</h1></body><script>window.close();</script>");
      request.response.close();
      //Get token
      if (request.uri.queryParameters["code"] != null) {
        _server.close();
        _server = null;
        responseUri = request.uri.toString();
        break;
      }
    }
    //Create spotify
    spotify = SpotifyApi.fromAuthCodeGrant(grant, responseUri);
    me = await spotify.me.get();
  }

  //Cancel authorization
  void cancelAuthorize() {
    if (_server != null) {
      _server.close(force: true);
      _server = null;
    }
  }
}