import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'dart:io';
import 'dart:convert';

import '../settings.dart';
import 'definitions.dart';

DeezerAPI deezerAPI = DeezerAPI();

class DeezerAPI {

  String arl;

  DeezerAPI({this.arl});

  String token;
  String userId;
  String favoritesPlaylistId;
  String privateUrl = 'http://www.deezer.com/ajax/gw-light.php';
  Map<String, String> headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36",
    "Content-Language": '${settings.deezerLanguage??"en"}-${settings.deezerCountry??'US'}',
    "Cache-Control": "max-age=0",
    "Accept": "*/*",
    "Accept-Charset": "utf-8,ISO-8859-1;q=0.7,*;q=0.3",
    "Accept-Language": "${settings.deezerLanguage??"en"}-${settings.deezerCountry??'US'},${settings.deezerLanguage??"en"};q=0.9,en-US;q=0.8,en;q=0.7",
    "Connection": "keep-alive"
  };
  Future _authorizing;

  CookieJar _cookieJar = new CookieJar();

  //Call private api
  Future<Map<dynamic, dynamic>> callApi(String method, {Map<dynamic, dynamic> params, String gatewayInput}) async {
    Dio dio = Dio();

    //Add headers
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options) {
        options.headers = this.headers;
        return options;
      }
    ));
    //Add cookies
    List<Cookie> cookies = [Cookie('arl', this.arl)];
    _cookieJar.saveFromResponse(Uri.parse(this.privateUrl), cookies);
    dio.interceptors.add(CookieManager(_cookieJar));
    //Make request
    Response<dynamic> response = await dio.post(
      this.privateUrl,
      queryParameters: {
        'api_version': '1.0',
        'api_token': this.token,
        'input': '3',
        'method': method,

        //Used for homepage
        if (gatewayInput != null)
          'gateway_input': gatewayInput
      },
      data: jsonEncode(params??{}),
      options: Options(responseType: ResponseType.json, sendTimeout: 10000, receiveTimeout: 10000)
    );
    return response.data;
  }

  Future<Map> callPublicApi(String path) async {
    Dio dio = Dio();
    Response response = await dio.get(
      'https://api.deezer.com/' + path,
      options: Options(responseType: ResponseType.json, sendTimeout: 10000, receiveTimeout: 10000)
    );
    return response.data;
  }

  //Wrapper so it can be globally awaited
  Future authorize() async {
    if (_authorizing == null) {
      this._authorizing = this._authorize();
    }
    return _authorizing;
  }

  //Authorize, bool = success
  Future<bool> _authorize() async {
    try {
      Map<dynamic, dynamic> data = await callApi('deezer.getUserData');
      if (data['results']['USER']['USER_ID'] == 0) {
        return false;
      } else {
        this.token = data['results']['checkForm'];
        this.userId = data['results']['USER']['USER_ID'].toString();
        this.favoritesPlaylistId = data['results']['USER']['LOVEDTRACKS_ID'];
        return true;
      }
    } catch (e) { return false; }
  }

  //Search
  Future<SearchResults> search(String query) async {
    Map<dynamic, dynamic> data = await callApi('deezer.pageSearch', params: {
      'nb': 50,
      'query': query,
      'start': 0
    });
    return SearchResults.fromPrivateJson(data['results']);
  }

  Future<Track> track(String id) async {
    Map<dynamic, dynamic> data = await callApi('song.getListData', params: {'sng_ids': [id]});
    return Track.fromPrivateJson(data['results']['data'][0]);
  }

  //Get album details, tracks
  Future<Album> album(String id) async {
      Map<dynamic, dynamic> data = await callApi('deezer.pageAlbum', params: {
        'alb_id': id,
        'header': true,
        'lang': 'us'
      });
      return Album.fromPrivateJson(data['results']['DATA'], songsJson: data['results']['SONGS']);
  }

  //Get artist details
  Future<Artist> artist(String id) async {
    Map<dynamic, dynamic> data = await callApi('deezer.pageArtist', params: {
      'art_id': id,
      'lang': 'us',
    });
    return Artist.fromPrivateJson(
      data['results']['DATA'],
      topJson: data['results']['TOP'],
      albumsJson: data['results']['ALBUMS']
    );
  }

  //Get playlist tracks at offset
  Future<List<Track>> playlistTracksPage(String id, int start, {int nb = 50}) async {
    Map data = await callApi('deezer.pagePlaylist', params: {
      'playlist_id': id,
      'lang': 'us',
      'nb': nb,
      'tags': true,
      'start': start
    });
    return data['results']['SONGS']['data'].map<Track>((json) => Track.fromPrivateJson(json)).toList();
  }

  //Get playlist details
  Future<Playlist> playlist(String id, {int nb = 100}) async {
    Map<dynamic, dynamic> data = await callApi('deezer.pagePlaylist', params: {
      'playlist_id': id,
      'lang': 'us',
      'nb': nb,
      'tags': true,
      'start': 0
    });
    return Playlist.fromPrivateJson(data['results']['DATA'], songsJson: data['results']['SONGS']);
  }

  //Get playlist with all tracks
  Future<Playlist> fullPlaylist(String id) async {
    Playlist p = await playlist(id, nb: 200);
    for (int i=200; i<p.trackCount; i++) {
      //Get another page of tracks
      List<Track> tracks = await playlistTracksPage(id, i, nb: 200);
      p.tracks.addAll(tracks);
      i += 200;
      continue;
    }
    return p;
  }

  //Add track to favorites
  Future addFavoriteTrack(String id) async {
    await callApi('favorite_song.add', params: {'SNG_ID': id});
  }

  //Add album to favorites/library
  Future addFavoriteAlbum(String id) async {
    await callApi('album.addFavorite', params: {'ALB_ID': id});
  }

  //Add artist to favorites/library
  Future addFavoriteArtist(String id) async {
    await callApi('artist.addFavorite', params: {'ART_ID': id});
  }

  //Remove artist from favorites/library
  Future removeArtist(String id) async {
    await callApi('artist.deleteFavorite', params: {'ART_ID': id});
  }

  //Add tracks to playlist
  Future addToPlaylist(String trackId, String playlistId, {int offset = -1}) async {
    await callApi('playlist.addSongs', params: {
      'offset': offset,
      'playlist_id': playlistId,
      'songs': [[trackId, 0]]
    });
  }

  //Remove track from playlist
  Future removeFromPlaylist(String trackId, String playlistId) async {
    await callApi('playlist.deleteSongs', params: {
      'playlist_id': playlistId,
      'songs': [[trackId, 0]]
    });
  }

  //Get users playlists
  Future<List<Playlist>> getPlaylists() async {
    Map data = await callApi('deezer.pageProfile', params: {
      'nb': 100,
      'tab': 'playlists',
      'user_id': this.userId
    });
    return data['results']['TAB']['playlists']['data'].map<Playlist>((json) => Playlist.fromPrivateJson(json, library: true)).toList();
  }

  //Get favorite albums
  Future<List<Album>> getAlbums() async {
    Map data = await callApi('deezer.pageProfile', params: {
      'nb': 50,
      'tab': 'albums',
      'user_id': this.userId
    });
    List albumList = data['results']['TAB']['albums']['data'];
    List<Album> albums = albumList.map<Album>((json) => Album.fromPrivateJson(json, library: true)).toList();
    return albums;
  }

  //Remove album from library
  Future removeAlbum(String id) async {
    await callApi('album.deleteFavorite', params: {
      'ALB_ID': id
    });
  }

  //Remove track from favorites
  Future removeFavorite(String id) async {
    await callApi('favorite_song.remove', params: {
      'SNG_ID': id
    });
  }

  //Get favorite artists
  Future<List<Artist>> getArtists() async {
    Map data = await callApi('deezer.pageProfile', params: {
      'nb': 40,
      'tab': 'artists',
      'user_id': this.userId
    });
    return data['results']['TAB']['artists']['data'].map<Artist>((json) => Artist.fromPrivateJson(json, library: true)).toList();
  }

  //Get lyrics by track id
  Future<Lyrics> lyrics(String trackId) async {
    Map data = await callApi('song.getLyrics', params: {
      'sng_id': trackId
    });
    if (data['error'] != null && data['error'].length > 0) return Lyrics().error;
    return Lyrics.fromPrivateJson(data['results']);
  }

  Future<SmartTrackList> smartTrackList(String id) async {
    Map data = await callApi('deezer.pageSmartTracklist', params: {
      'smarttracklist_id': id
    });
    return SmartTrackList.fromPrivateJson(data['results']['DATA'], songsJson: data['results']['SONGS']);
  }

  Future<List<Track>> flow() async {
    Map data = await callApi('radio.getUserRadio', params: {
      'user_id': userId
    });
    return data['results']['data'].map<Track>((json) => Track.fromPrivateJson(json)).toList();
  }

  //Get homepage/music library from deezer
  Future<HomePage> homePage() async {
    List grid = ['album', 'artist', 'channel', 'flow', 'playlist', 'radio', 'show', 'smarttracklist', 'track', 'user'];
    Map data = await callApi('page.get', gatewayInput: jsonEncode({
      "PAGE": "home",
      "VERSION": "2.3",
      "SUPPORT": {
        /*
        "deeplink-list": ["deeplink"],
        "list": ["episode"],
        "grid-preview-one": grid,
        "grid-preview-two": grid,
        "slideshow": grid,
        "message": ["call_onboarding"],
        */
        "grid": grid,
        "horizontal-grid": grid,
        "item-highlight": ["radio"],
        "large-card": ["album", "playlist", "show", "video-link"],
        "ads": [] //Nope
      },
      "LANG": "us",
      "OPTIONS": []
    }));
    return HomePage.fromPrivateJson(data['results']);
  }

  //Log song listen to deezer
  Future logListen(String trackId) async {
    await callApi('log.listen', params: {'next_media': {'media': {'id': trackId, 'type': 'song'}}});
  }

  Future<HomePage> getChannel(String target) async {
    List grid = ['album', 'artist', 'channel', 'flow', 'playlist', 'radio', 'show', 'smarttracklist', 'track', 'user'];
    Map data = await callApi('page.get', gatewayInput: jsonEncode({
      'PAGE': target,
      "VERSION": "2.3",
      "SUPPORT": {
        /*
        "deeplink-list": ["deeplink"],
        "list": ["episode"],
        "grid-preview-one": grid,
        "grid-preview-two": grid,
        "slideshow": grid,
        "message": ["call_onboarding"],
        */
        "grid": grid,
        "horizontal-grid": grid,
        "item-highlight": ["radio"],
        "large-card": ["album", "playlist", "show", "video-link"],
        "ads": [] //Nope
      },
      "LANG": "us",
      "OPTIONS": []
    }));
    return HomePage.fromPrivateJson(data['results']);
  }

  //Add playlist to library
  Future addPlaylist(String id) async {
    await callApi('playlist.addFavorite', params: {
      'parent_playlist_id': int.parse(id)
    });
  }
  //Remove playlist from library
  Future removePlaylist(String id) async {
    await callApi('playlist.deleteFavorite', params: {
      'playlist_id': int.parse(id)
    });
  }
  //Delete playlist
  Future deletePlaylist(String id) async {
    await callApi('playlist.delete', params: {
      'playlist_id': id
    });
  }

  //Create playlist
  //Status 1 - private, 2 - collaborative
  Future<String> createPlaylist(String title, {String description = "", int status = 1, List<String> trackIds = const []}) async {
    Map data = await callApi('playlist.create', params: {
      'title': title,
      'description': description,
      'songs': trackIds.map<List>((id) => [int.parse(id), trackIds.indexOf(id)]).toList(),
      'status': status
    });
    //Return playlistId
    return data['results'].toString();
  }

  //Get part of discography
  Future<List<Album>> discographyPage(String artistId, {int start = 0, int nb = 50}) async {
    Map data = await callApi('album.getDiscography', params: {
      'art_id': int.parse(artistId),
      'discography_mode': 'all',
      'nb': nb,
      'start': start,
      'nb_songs': 30
    });

    return data['results']['data'].map<Album>((a) => Album.fromPrivateJson(a)).toList();
  }
}

