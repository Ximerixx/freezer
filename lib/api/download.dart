import 'dart:typed_data';

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

  bool stopped = true;

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
    if (_download == null && queue.length > 0 && !stopped) {
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
      ).catchError((e, st) async {
        if (stopped) return;
        print('Download error: $e\n$st');
        //Catch download errors
        _download = null;
        _cancelNotifications = true;
        //Cancellation error i guess
        await _showError();
      });
      //Show download progress notifications
      if (_cancelNotifications == null || _cancelNotifications) _startProgressNotification();
    }
  }

  //Stop downloading and end my life
  Future stop() async {
    stopped = true;
    if (_download != null) {
      await queue[0].stop();
    }
    _download = null;
  }

  //Start again downloads
  Future start() async {
    if (_download != null) return;
    stopped = false;
    updateQueue();
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

  Future addOfflineTrack(Track track, {private = true, forceStart = true}) async {
    //Paths
    String path = p.join(_offlinePath, track.id);
    if (track.playbackDetails == null) {
      //Get track from API if download info missing
      track = await deezerAPI.track(track.id);
    }

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
    } else {
      //Load lyrics for private
      try {
        Lyrics l = await deezerAPI.lyrics(track.id);
        track.lyrics = l;
      } catch (e) {}
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
    if (forceStart) start();
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
      await addOfflineTrack(track, private: private, forceStart: false);
    }
    start();
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
      await addOfflineTrack(t, private: private, forceStart: false);
    }
    start();
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

  //Delete download from db
  Future removeDownload(Download download) async {
    await db.delete('downloads', where: 'trackId == ?', whereArgs: [download.track.id]);
    queue.removeWhere((d) => d.track.id == download.track.id);
    //TODO: remove files for downloaded
  }

  //Delete queue
  Future clearQueue() async {
    while (queue.length > 0) {
      if (queue.length == 1) {
        if (_download != null) break;
        await removeDownload(queue[0]);
        return;
      }
      await removeDownload(queue[1]);
    }
  }

  //Remove non-private downloads
  Future cleanDownloadHistory() async {
    await db.delete('downloads', where: 'private == 0');
  }

}

class Download {
  Track track;
  String path;
  String url;
  bool private;
  DownloadState state;
  String _cover;

  //For canceling
  IOSink _outSink;
  CancelToken _cancel;
  StreamSubscription _progressSub;

  int received = 0;
  int total = 1;

  Download({this.track, this.path, this.url, this.private, this.state = DownloadState.NONE});

  //Stop download
  Future stop() async {
    if (_cancel != null) _cancel.cancel();
    //if (_outSink != null) _outSink.close();
    if (_progressSub != null) _progressSub.cancel();

    received = 0;
    total = 1;
    state = DownloadState.NONE;
  }

  Future download({onDone}) async {
    Dio dio = Dio();

    //TODO: Check for internet before downloading

    if (!this.private && !(this.path.endsWith('.mp3') || this.path.endsWith('.flac'))) {
      String ext = this.path;
      //Get track details
      Map _rawTrackData = await deezerAPI.callApi('song.getListData', params: {'sng_ids': [track.id]});
      Map rawTrack = _rawTrackData['results']['data'][0];
      this.track = Track.fromPrivateJson(rawTrack);

      //Get path if public
      RegExp sanitize = RegExp(r'[\/\\\?\%\*\:\|\"\<\>]');
      //Download path
      this.path = settings.downloadPath ??  (await ExtStorage.getExternalStoragePublicDirectory(ExtStorage.DIRECTORY_MUSIC));
      if (settings.artistFolder)
        this.path = p.join(this.path, track.artists[0].name.replaceAll(sanitize, ''));
      if (settings.albumFolder) {
        String folderName = track.album.title.replaceAll(sanitize, '');
        //Add disk number
        if (settings.albumDiscFolder) folderName += ' - Disk ${track.diskNumber}';

        this.path = p.join(this.path, folderName);
      }
      //Make dirs
      await Directory(this.path).create(recursive: true);

      //Grab cover
      _cover = p.join(this.path, 'cover.jpg');
      if (!settings.albumFolder) _cover = p.join(this.path, randomAlpha(12) + '_cover.jpg');

      if (!await File(_cover).exists()) {
        try {
          await dio.download(
            this.track.albumArt.full,
            _cover,
          );
        } catch (e) {print('Error downloading cover');}
      }

      //Create filename
      String _filename = settings.downloadFilename;
      //Feats filter
      String feats = '';
      if (track.artists.length > 1) feats = "feat. ${track.artists.sublist(1).map((a) => a.name).join(', ')}";
      //Filters
      Map<String, String> vars = {
        '%artists%': track.artistString.replaceAll(sanitize, ''),
        '%artist%': track.artists[0].name.replaceAll(sanitize, ''),
        '%title%': track.title.replaceAll(sanitize, ''),
        '%album%': track.album.title.replaceAll(sanitize, ''),
        '%trackNumber%': track.trackNumber.toString(),
        '%0trackNumber%': track.trackNumber.toString().padLeft(2, '0'),
        '%feats%': feats
      };
      //Replace
      vars.forEach((key, value) {
        _filename = _filename.replaceAll(key, value);
      });
      _filename += '.$ext';

      this.path = p.join(this.path, _filename);
    }
    //Download
    this.state = DownloadState.DOWNLOADING;

    //Create download file
    File downloadFile = File(this.path + '.ENC');
    //Get start position
    int start = 0;
    if (await downloadFile.exists()) {
      FileStat stat = await downloadFile.stat();
      start = stat.size;
    } else {
      //Create file if doesnt exist
      await downloadFile.create(recursive: true);
    }
    //Download
    _cancel = CancelToken();
    Response response = await dio.get(
      this.url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Range': 'bytes=$start-'
        },
      ),
      cancelToken: _cancel
    );
    //Size
    this.total = int.parse(response.headers['Content-Length'][0]) + start;
    this.received = start;
    //Save
    _outSink = downloadFile.openWrite(mode: FileMode.append);
    Stream<Uint8List> _data = response.data.stream.asBroadcastStream();
    _progressSub = _data.listen((Uint8List c) {
      this.received += c.length;
    });
    //Pipe to file
    try {
      await _outSink.addStream(_data);
    } catch (e) {
      await _outSink.close();
      throw Exception('Download error');
    }
      await _outSink.close();
    _cancel = null;


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
    if (!settings.albumFolder) await File(_cover).delete();

    //Get lyrics
    Lyrics lyrics;
    try {
      lyrics = await deezerAPI.lyrics(track.id);
    } catch (e) {}
    if (lyrics != null && lyrics.lyrics != null) {
      //Create .LRC file
      String lrcPath = p.join(p.dirname(path), p.basenameWithoutExtension(path)) + '.lrc';
      File lrcFile = File(lrcPath);
      String lrcData = '';
      //Generate file
      lrcData += '[ar:${track.artistString}]\r\n';
      lrcData += '[al:${track.album.title}]\r\n';
      lrcData += '[ti:${track.title}]\r\n';
      for (Lyric l in lyrics.lyrics) {
        if (l.lrcTimestamp != null && l.lrcTimestamp != '' && l.text != null)
          lrcData += '${l.lrcTimestamp}${l.text}\r\n';
      }
      lrcFile.writeAsString(lrcData);
    }

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