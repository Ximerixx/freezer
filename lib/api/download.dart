import 'package:disk_space/disk_space.dart';
import 'package:ext_storage/ext_storage.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:random_string/random_string.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import 'package:filesize/filesize.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dart:io';

import 'dart:async';
import 'deezer.dart';
import '../settings.dart';
import 'definitions.dart';
import '../ui/cached_image.dart';

DownloadManager downloadManager = DownloadManager();
MethodChannel platformChannel = const MethodChannel('f.f.freezer/native');

class DownloadManager {

  Database db;
  List<Download> queue = [];
  String _offlinePath;
  Future _download;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _cancelNotifications = true;

  bool get stopped => queue.length > 0 && _download == null;

  Future init() async {
    //Prepare DB
    String dir = await getDatabasesPath();
    String path = p.join(dir, 'offline.db');
    db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        Batch b = db.batch();
        //Create tables
        b.execute(""" CREATE TABLE downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT, url TEXT, private INTEGER, state INTEGER, trackId TEXT)""");
        b.execute("""CREATE TABLE tracks (
        id TEXT PRIMARY KEY, title TEXT, album TEXT, artists TEXT, duration INTEGER, albumArt TEXT, trackNumber INTEGER, offline INTEGER, lyrics TEXT, favorite INTEGER)""");
        b.execute("""CREATE TABLE albums (
        id TEXT PRIMARY KEY, title TEXT, artists TEXT, tracks TEXT, art TEXT, fans INTEGER, offline INTEGER, library INTEGER)""");
        b.execute("""CREATE TABLE artists (
        id TEXT PRIMARY KEY, name TEXT, albums TEXT, topTracks TEXT, picture TEXT, fans INTEGER, albumCount INTEGER, offline INTEGER, library INTEGER)""");
        b.execute("""CREATE TABLE playlists (
        id TEXT PRIMARY KEY, title TEXT, tracks TEXT, image TEXT, duration INTEGER, userId TEXT, userName TEXT, fans INTEGER, library INTEGER, description TEXT)""");
        await b.commit();
      }
    );
    //Prepare folders (/sdcard/Android/data/freezer/data/)
    _offlinePath = p.join((await getExternalStorageDirectory()).path, 'offline/');
    await Directory(_offlinePath).create(recursive: true);

    //Notifications
    await _prepareNotifications();

    //Restore
    List<Map> downloads = await db.rawQuery("SELECT * FROM downloads INNER JOIN tracks ON tracks.id = downloads.trackId WHERE downloads.state = 0");
    downloads.forEach((download) => queue.add(Download.fromSQL(download, parseTrack: true)));
  }

  //Initialize flutter local notification plugin
  Future _prepareNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings('@drawable/ic_logo');
    InitializationSettings initializationSettings = InitializationSettings(androidInitializationSettings, null);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  //Show download progress notification, if now/total = null, show intermediate
  Future _startProgressNotification() async {
    _cancelNotifications = false;
    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      //Cancel notifications
      if (_cancelNotifications) {
        flutterLocalNotificationsPlugin.cancel(10);
        timer.cancel();
        return;
      }
      //Not downloading
      if (this.queue.length <= 0) return;
      Download d = queue[0];
      //Prepare and show notification
      AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'download', 'Download', 'Download',
        importance: Importance.Default,
        priority: Priority.Default,
        showProgress: true,
        maxProgress: d.total??1,
        progress: d.received??1,
        playSound: false,
        enableVibration: false,
        autoCancel: true,
        //ongoing: true, //Allow dismissing
        indeterminate: (d.total == null || d.total == d.received),
        onlyAlertOnce: true
      );
      NotificationDetails notificationDetails = NotificationDetails(androidNotificationDetails, null);
      await downloadManager.flutterLocalNotificationsPlugin.show(
        10,
        'Downloading: ${d.track.title}',
        (d.state == DownloadState.POST) ? 'Post processing...' : '${filesize(d.received)} / ${filesize(d.total)} (${queue.length} in queue)',
        notificationDetails
      );
    });
  }

  //Update queue, start new download
  void updateQueue() async {
    if (_download == null && queue.length > 0) {
      _download = queue[0].download(
        onDone: () async {
          //On download finished
          await db.rawUpdate('UPDATE downloads SET state = 1 WHERE trackId = ?', [queue[0].track.id]);
          /*
          if (queue[0].private) {
            await db.rawUpdate('UPDATE downloads SET state = 1 WHERE trackId = ?', [queue[0].track.id]);
          } else {
            //Remove on db if public
            await db.delete('downloads', where: 'trackId = ?', whereArgs: [queue[0].track.id]);
          }
          */
          queue.removeAt(0);
          _download = null;
          //Remove notification if no more downloads
          if (queue.length == 0) {
            _cancelNotifications = true;
          }
          updateQueue();
        }
      ).catchError((err) async {
        //Catch download errors
        _download = null;
        _cancelNotifications = true;
        await _showError();
      });
      //Show download progress notifications
      if (_cancelNotifications == null || _cancelNotifications) _startProgressNotification();
    }
  }

  //Show error notification
  Future _showError() async {
    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'downloadError', 'Download Error', 'Download Error'
    );
    NotificationDetails notificationDetails = NotificationDetails(androidNotificationDetails, null);
    flutterLocalNotificationsPlugin.show(
      11, 'Error while downloading!', 'Please restart downloads in the library', notificationDetails
    );
  }

  //Returns all offline tracks
  Future<List<Track>> allOfflineTracks() async {
    List data = await db.query('tracks', where: 'offline == 1');
    List<Track> tracks = [];
    //Load track data
    for (var t in data) {
      tracks.add(await getTrack(t['id']));
    }
    return tracks;
  }

  //Get all offline playlists
  Future<List<Playlist>> getOfflinePlaylists() async {
    List data = await db.query('playlists');
    List<Playlist> playlists = [];
    //Load playlists
    for (var p in data) {
      playlists.add(await getPlaylist(p['id']));
    }
    return playlists;
  }

  //Get playlist metadata with tracks
  Future<Playlist> getPlaylist(String id) async {
    if (id == null) return null;
    List data = await db.query('playlists', where: 'id == ?', whereArgs: [id]);
    if (data.length == 0) return null;
    //Load playlist tracks
    Playlist p = Playlist.fromSQL(data[0]);
    for (int i=0; i<p.tracks.length; i++) {
      p.tracks[i] = await getTrack(p.tracks[i].id);
    }
    return p;
  }

  //Gets favorites
  Future<Playlist> getFavorites() async {
    return await getPlaylist('FAVORITES');
  }

  Future<List<Album>> getOfflineAlbums({List albumsData}) async {
    //Load albums
    if (albumsData == null) {
      albumsData = await db.query('albums', where: 'offline == 1');
    }
    List<Album> albums = albumsData.map((alb) => Album.fromSQL(alb)).toList();
    for(int i=0; i<albums.length; i++) {
      albums[i].library = true;
      //Load tracks
      for(int j=0; j<albums[i].tracks.length; j++) {
        albums[i].tracks[j] = await getTrack(albums[i].tracks[j].id, album: albums[i]);
      }
      //Load artists
      List artistsData = await db.rawQuery('SELECT * FROM artists WHERE id IN (${albumsData[i]['artists']})');
      albums[i].artists = artistsData.map<Artist>((a) => Artist.fromSQL(a)).toList();
    }
    return albums;
  }

  //Get track with metadata from db
  Future<Track> getTrack(String id, {Album album, List<Artist> artists}) async {
    List tracks = await db.query('tracks', where: 'id == ?', whereArgs: [id]);
    if (tracks.length == 0) return null;
    Track t = Track.fromSQL(tracks[0]);
    //Load album from DB
    t.album = album ?? Album.fromSQL((await db.query('albums', where: 'id == ?', whereArgs: [t.album.id]))[0]);
    if (artists != null) {
      t.artists = artists;
      return t;
    }
    //Load artists from DB
    for (int i=0; i<t.artists.length; i++) {
      t.artists[i] = Artist.fromSQL(
          (await db.query('artists', where: 'id == ?', whereArgs: [t.artists[i].id]))[0]);
    }
    return t;
  }
  
  Future removeOfflineTrack(String id) async {
    //Check if track present in albums
    List counter = await db.rawQuery('SELECT COUNT(*) FROM albums WHERE tracks LIKE "%$id%"');
    if (counter[0]['COUNT(*)'] > 0) return;
    //and in playlists
    counter = await db.rawQuery('SELECT COUNT(*) FROM playlists WHERE tracks LIKE "%$id%"');
    if (counter[0]['COUNT(*)'] > 0) return;
    //Remove file
    List download = await db.query('downloads', where: 'trackId == ?', whereArgs: [id]);
    await File(download[0]['path']).delete();
    //Delete from db
    await db.delete('tracks', where: 'id == ?', whereArgs: [id]);
    await db.delete('downloads', where: 'trackId == ?', whereArgs: [id]);
  }

  //Delete offline album
  Future removeOfflineAlbum(String id) async {
    List data = await db.rawQuery('SELECT * FROM albums WHERE id == ? AND offline == 1', [id]);
    if (data.length == 0) return;
    Map<String, dynamic> album = Map.from(data[0]); //make writable
    //Remove DB
    album['offline'] = 0;
    await db.update('albums', album, where: 'id == ?', whereArgs: [id]);
    //Get track ids
    List<String> tracks = album['tracks'].split(',');
    for (String t in tracks) {
      //Remove tracks
      await removeOfflineTrack(t);
    }
  }

  Future removeOfflinePlaylist(String id) async {
    List data = await db.query('playlists', where: 'id == ?', whereArgs: [id]);
    if (data.length == 0) return;
    Playlist p = Playlist.fromSQL(data[0]);
    //Remove db
    await db.delete('playlists', where: 'id == ?', whereArgs: [id]);
    //Remove tracks
    for(Track t in p.tracks) {
      await removeOfflineTrack(t.id);
    }
  }

  //Get path to offline track
  Future<String> getOfflineTrackPath(String id) async {
    List<Map> tracks = await db.rawQuery('SELECT path FROM downloads WHERE state == 1 AND trackId == ?', [id]);
    if (tracks.length < 1) {
      return null;
    }
    Download d = Download.fromSQL(tracks[0]);
    return d.path;
  }

  Future addOfflineTrack(Track track, {private = true}) async {
    //Paths
    String path = p.join(_offlinePath, track.id);
    if (track.playbackDetails == null) {
      //Get track from API if download info missing
      track = await deezerAPI.track(track.id);
    }
    //Load lyrics
    try {
      Lyrics l = await deezerAPI.lyrics(track.id);
      track.lyrics = l;
    } catch (e) {}

    String url = track.getUrl(settings.getQualityInt(settings.offlineQuality));
    if (!private) {
      //Check permissions
      if (!(await Permission.storage.request().isGranted)) {
        return;
      }
      //If saving to external
      url = track.getUrl(settings.getQualityInt(settings.downloadQuality));
      //Save just extension to path, will be generated before download
      path = 'mp3';
      if (settings.downloadQuality == AudioQuality.FLAC) {
        path = 'flac';
      }
    }

    Download download = Download(track: track, path: path, url: url, private: private);
    //Database
    Batch b = db.batch();
    b.insert('downloads', download.toSQL());
    b.insert('tracks', track.toSQL(off: false), conflictAlgorithm: ConflictAlgorithm.ignore);

    if (private) {
      //Duplicate check
      List<Map> duplicate = await db.rawQuery('SELECT * FROM downloads WHERE trackId == ?', [track.id]);
      if (duplicate.length != 0) return;
      //Save art
      //await imagesDatabase.getImage(track.albumArt.full);
      imagesDatabase.saveImage(track.albumArt.full);
      //Save to db
      b.insert('tracks', track.toSQL(off: true), conflictAlgorithm: ConflictAlgorithm.replace);
      b.insert('albums', track.album.toSQL(), conflictAlgorithm: ConflictAlgorithm.ignore);
      track.artists.forEach((art) => b.insert('artists', art.toSQL(), conflictAlgorithm: ConflictAlgorithm.ignore));
    }
    await b.commit();

    queue.add(download);
    updateQueue();
  }

  Future addOfflineAlbum(Album album, {private = true}) async {
    //Get full album from API if tracks are missing
    if (album.tracks == null || album.tracks.length == 0) {
      album = await deezerAPI.album(album.id);
    }
    //Update album in database
    if (private) {
      await db.insert('albums', album.toSQL(off: true), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    //Save all tracks
    for (Track track in album.tracks) {
      await addOfflineTrack(track, private: private);
    }
  }

  //Add offline playlist, can be also used as update
  Future addOfflinePlaylist(Playlist playlist, {private = true}) async {
    //Load full playlist if missing tracks
    if (playlist.tracks == null || playlist.tracks.length != playlist.trackCount) {
      playlist = await deezerAPI.fullPlaylist(playlist.id);
    }
    playlist.library = true;
    //To DB
    if (private) {
      await db.insert('playlists', playlist.toSQL(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    //Download all tracks
    for (Track t in playlist.tracks) {
      await addOfflineTrack(t, private: private);
    }
  }


  Future checkOffline({Album album, Track track, Playlist playlist}) async {
    //Check if album/track (TODO: Artist, playlist) is offline
    if (track != null) {
      List res = await db.query('tracks', where: 'id == ? AND offline == 1', whereArgs: [track.id]);
      if (res.length == 0) return false;
      return true;
    }

    if (album != null) {
      List res = await db.query('albums', where: 'id == ? AND offline == 1', whereArgs: [album.id]);
      if (res.length == 0) return false;
      return true;
    }

    if (playlist != null && playlist.id != null) {
      List res = await db.query('playlists', where: 'id == ?', whereArgs: [playlist.id]);
      if (res.length == 0) return false;
      return true;
    }
    return false;
  }

  //Offline search
  Future<SearchResults> search(String query) async {
    SearchResults results = SearchResults(
      tracks: [],
      albums: [],
      artists: [],
      playlists: []
    );
    //Tracks
    List tracksData = await db.rawQuery('SELECT * FROM tracks WHERE offline == 1 AND title like "%$query%"');
    for (Map trackData in tracksData) {
      results.tracks.add(await getTrack(trackData['id']));
    }
    //Albums
    List albumsData = await db.rawQuery('SELECT * FROM albums WHERE offline == 1 AND title like "%$query%"');
    results.albums = await getOfflineAlbums(albumsData: albumsData);
    //Artists
    //TODO: offline artists
    //Playlists
    List playlists = await db.rawQuery('SELECT * FROM playlists WHERE title like "%$query%"');
    for (Map playlist in playlists) {
      results.playlists.add(await getPlaylist(playlist['id']));
    }
    return results;
  }

  Future<List<Download>> getFinishedDownloads() async {
    //Fetch from db
    List<Map> data = await db.rawQuery("SELECT * FROM downloads INNER JOIN tracks ON tracks.id = downloads.trackId WHERE downloads.state = 1");
    List<Download> downloads = data.map<Download>((d) => Download.fromSQL(d, parseTrack: true)).toList();
    return downloads;
  }

  //Get stats for library screen
  Future<List<String>> getStats() async {
    //Get offline counts
    int trackCount = (await db.rawQuery('SELECT COUNT(*) FROM tracks WHERE offline == 1'))[0]['COUNT(*)'];
    int albumCount = (await db.rawQuery('SELECT COUNT(*) FROM albums WHERE offline == 1'))[0]['COUNT(*)'];
    int playlistCount = (await db.rawQuery('SELECT COUNT(*) FROM albums WHERE offline == 1'))[0]['COUNT(*)'];
    //Free space
    double diskSpace = await DiskSpace.getFreeDiskSpace;

    //Used space
    List<FileSystemEntity> offlineStat = await Directory(_offlinePath).list().toList();
    int offlineSize = 0;
    for (var fs in offlineStat) {
      offlineSize += (await fs.stat()).size;
    }

    //Return as a list, maybe refactor in future if feature stays
    return ([
      trackCount.toString(),
      albumCount.toString(),
      playlistCount.toString(),
      filesize(offlineSize),
      filesize((diskSpace * 1000000).floor())
    ]);
  }


}

class Download {
  Track track;
  String path;
  String url;
  bool private;
  DownloadState state;
  String _cover;

  int received = 0;
  int total = 1;

  Download({this.track, this.path, this.url, this.private, this.state = DownloadState.NONE});

  Future download({onDone}) async {
    Dio dio = Dio();

    //TODO: Check for internet before downloading

    if (!this.private) {
      String ext = this.path;
      //Get track details
      this.track = await deezerAPI.track(track.id);
      //Get path if public
      RegExp sanitize = RegExp(r'[\/\\\?\%\*\:\|\"\<\>]');
      //Download path
      if (settings.downloadFolderStructure) {
        this.path = p.join(
          settings.downloadPath ?? (await ExtStorage.getExternalStoragePublicDirectory(ExtStorage.DIRECTORY_MUSIC)),
          track.artists[0].name.replaceAll(sanitize, ''),
          track.album.title.replaceAll(sanitize, ''),
        );
      } else {
        this.path = settings.downloadPath;
      }
      //Make dirs
      await Directory(this.path).create(recursive: true);

      //Grab cover
      _cover = p.join(this.path, 'cover.jpg');
      if (!settings.downloadFolderStructure) _cover = p.join(this.path, randomAlpha(12) + '_cover.jpg');

      if (!await File(_cover).exists()) {
        try {
          await dio.download(
            this.track.albumArt.full,
            _cover,
          );
        } catch (e) {print('Error downloading cover');}
      }

      //Add filename
      String _filename = '${track.trackNumber.toString().padLeft(2, '0')}. ${track.title.replaceAll(sanitize, "")}.$ext';
      //Different naming types
      if (settings.downloadNaming == DownloadNaming.STANDALONE)
        _filename = '${track.artistString.replaceAll(sanitize, "")} - ${track.title.replaceAll(sanitize, "")}.$ext';

      this.path = p.join(this.path, _filename);
    }
    //Download
    this.state = DownloadState.DOWNLOADING;

    await dio.download(
      this.url,
      this.path + '.ENC',
      deleteOnError: true,
      onReceiveProgress: (rec, total) {
        this.received = rec;
        this.total = total;
      }
    );

    this.state = DownloadState.POST;
    //Decrypt
    await platformChannel.invokeMethod('decryptTrack', {'id': track.id, 'path': path});
    //Tag
    if (!private) {
      //Tag track in native
      await platformChannel.invokeMethod('tagTrack', {
        'path': path,
        'title': track.title,
        'album': track.album.title,
        'artists': track.artistString,
        'artist': track.artists[0].name,
        'cover': _cover,
        'trackNumber': track.trackNumber
      });
      //Rescan android library
      await platformChannel.invokeMethod('rescanLibrary', {
        'path': path
      });
    }
    //Remove encrypted
    await File(path + '.ENC').delete();
    if (!settings.downloadFolderStructure) await File(_cover).delete();
    this.state = DownloadState.DONE;
    onDone();
    return;
  }

  //JSON
  Map<String, dynamic> toSQL() => {
    'trackId': track.id,
    'path': path,
    'url': url,
    'state': state == DownloadState.DONE ? 1:0,
    'private': private?1:0
  };
  factory Download.fromSQL(Map<String, dynamic> data, {parseTrack = false}) => Download(
    track: parseTrack?Track.fromSQL(data):Track(id: data['trackId']),
    path: data['path'],
    url: data['url'],
    state: data['state'] == 1 ? DownloadState.DONE:DownloadState.NONE,
    private: data['private'] == 1
  );
}

enum DownloadState {
  NONE,
  DOWNLOADING,
  POST,
  DONE
}