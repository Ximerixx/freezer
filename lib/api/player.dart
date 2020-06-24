import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/ui/cached_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity/connectivity.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'definitions.dart';
import '../settings.dart';

import 'dart:io';
import 'dart:async';
import 'dart:convert';

PlayerHelper playerHelper = PlayerHelper();

class PlayerHelper {

  StreamSubscription _customEventSubscription;
  StreamSubscription _playbackStateStreamSubscription;
  QueueSource queueSource;
  RepeatType repeatType = RepeatType.NONE;

  //Find queue index by id
  int get queueIndex => AudioService.queue.indexWhere((mi) => mi.id == AudioService.currentMediaItem?.id??'Random string so it returns -1');

  Future start() async {
    //Subscribe to custom events
    _customEventSubscription = AudioService.customEventStream.listen((event) async {
      if (!(event is Map)) return;
      if (event['action'] == 'onLoad') {
        //After audio_service is loaded, load queue, set quality
        await settings.updateAudioServiceQuality();
        await AudioService.customAction('load');
        return;
      }
      if (event['action'] == 'onRestore') {
        //Load queueSource from isolate
        this.queueSource = QueueSource.fromJson(event['queueSource']);
      }
      if (event['action'] == 'queueEnd') {
        //If last song is played, load more queue
        this.queueSource = QueueSource.fromJson(event['queueSource']);
        print(queueSource.toJson());
        return;
      }
    });
    _playbackStateStreamSubscription = AudioService.playbackStateStream.listen((event) {
      //Log song (if allowed)
      if (event == null) return;
      if (event.processingState == AudioProcessingState.ready && event.playing) {
        if (settings.logListen) deezerAPI.logListen(AudioService.currentMediaItem.id);
      }
    });
    //Start audio_service
    _startService();
  }

  Future _startService() async {
    if (AudioService.running) return;
    await AudioService.start(
      backgroundTaskEntrypoint: backgroundTaskEntrypoint,
      androidEnableQueue: true,
      androidStopForegroundOnPause: true,
      androidNotificationOngoing: false,
      androidNotificationClickStartsActivity: true,
      androidNotificationChannelDescription: 'Freezer',
      androidNotificationChannelName: 'Freezer',
      androidNotificationIcon: 'drawable/ic_logo'
    );
  }

  //Repeat toggle
  Future changeRepeat() async {
    //Change to next repeat type
    switch (repeatType) {
      case RepeatType.NONE:
        repeatType = RepeatType.LIST; break;
      case RepeatType.LIST:
        repeatType = RepeatType.TRACK; break;
      default:
        repeatType = RepeatType.NONE; break;
    }
    //Set repeat type
    await AudioService.customAction("repeatType", RepeatType.values.indexOf(repeatType));
  }

  //Executed before exit
  Future onExit() async {
    _customEventSubscription.cancel();
    _playbackStateStreamSubscription.cancel();
  }

  //Replace queue, play specified track id
  Future _loadQueuePlay(List<MediaItem> queue, String trackId) async {
    await _startService();
    await settings.updateAudioServiceQuality();
    await AudioService.updateQueue(queue);
    await AudioService.playFromMediaId(trackId);
  }

  //Play track from album
  Future playFromAlbum(Album album, String trackId) async {
    await playFromTrackList(album.tracks, trackId, QueueSource(
      id: album.id,
      text: album.title,
      source: 'album'
    ));
  }
  //Play from artist top tracks
  Future playFromTopTracks(List<Track> tracks, String trackId, Artist artist) async {
    await playFromTrackList(tracks, trackId, QueueSource(
      id: artist.id,
      text: 'Top ${artist.name}',
      source: 'topTracks'
    ));
  }
  Future playFromPlaylist(Playlist playlist, String trackId) async {
    await playFromTrackList(playlist.tracks, trackId, QueueSource(
      id: playlist.id,
      text: playlist.title,
      source: 'playlist'
    ));
  }
  //Load tracks as queue, play track id, set queue source
  Future playFromTrackList(List<Track> tracks, String trackId, QueueSource queueSource) async {
    await _startService();

    List<MediaItem> queue = tracks.map<MediaItem>((track) => track.toMediaItem()).toList();
    await setQueueSource(queueSource);
    await _loadQueuePlay(queue, trackId);
  }

  //Load smart track list as queue, start from beginning
  Future playFromSmartTrackList(SmartTrackList stl) async {
    //Load from API if no tracks
    if (stl.tracks == null || stl.tracks.length == 0) {
      if (settings.offlineMode) {
        Fluttertoast.showToast(
          msg: "Offline mode, can't play flow/smart track lists.",
          gravity: ToastGravity.BOTTOM,
          toastLength: Toast.LENGTH_SHORT
        );
        return;
      }

      //Flow songs cannot be accessed by smart track list call
      if (stl.id == 'flow') {
        stl.tracks = await deezerAPI.flow();
      } else {
        stl = await deezerAPI.smartTrackList(stl.id);
      }
    }
    QueueSource queueSource = QueueSource(
      id: stl.id,
      source: (stl.id == 'flow')?'flow':'smarttracklist',
      text: stl.title
    );
    await playFromTrackList(stl.tracks, stl.tracks[0].id, queueSource);
  }
  
  Future setQueueSource(QueueSource queueSource) async {
    await _startService();

    this.queueSource = queueSource;
    await AudioService.customAction('queueSource', queueSource.toJson());
  }

}

void backgroundTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {

  AudioPlayer _audioPlayer = AudioPlayer();

  List<MediaItem> _queue = <MediaItem>[];
  int _queueIndex = -1;

  bool _playing;
  bool _interrupted;
  AudioProcessingState _skipState;
  Duration _lastPosition;

  ImagesDatabase imagesDB;
  int mobileQuality;
  int wifiQuality;

  StreamSubscription _eventSub;
  StreamSubscription _playerStateSub;

  QueueSource queueSource;
  int repeatType = 0;

  MediaItem get mediaItem => _queue[_queueIndex];

  //Controls
  final playControl = MediaControl(
    androidIcon: 'drawable/ic_play_arrow',
    label: 'Play',
    action: MediaAction.play
  );
  final pauseControl = MediaControl(
    androidIcon: 'drawable/ic_pause',
    label: 'Pause',
    action: MediaAction.pause
  );
  final stopControl = MediaControl(
    androidIcon: 'drawable/ic_stop',
    label: 'Stop',
    action: MediaAction.stop
  );
  final nextControl = MediaControl(
    androidIcon: 'drawable/ic_skip_next',
    label: 'Next',
    action: MediaAction.skipToNext
  );
  final previousControl = MediaControl(
    androidIcon: 'drawable/ic_skip_previous',
    label: 'Previous',
    action: MediaAction.skipToPrevious
  );

  @override
  Future onStart(Map<String, dynamic> params) async {
    _playerStateSub = _audioPlayer.playbackStateStream
      .where((state) => state == AudioPlaybackState.completed)
      .listen((_event) {
        if (_queue.length > _queueIndex + 1) {
          onSkipToNext();
          return;
        } else {
          //Repeat whole list (if enabled)
          if (repeatType == 1) {
            _skip(-_queueIndex);
            return;
          }
          //Ask for more tracks in queue
          AudioServiceBackground.sendCustomEvent({
            'action': 'queueEnd',
            'queueSource': (queueSource??QueueSource()).toJson()
          });
          if (_playing) _playing = false;
          _setState(AudioProcessingState.none);
          return;
        }
    });

    //Read audio player events
    _eventSub = _audioPlayer.playbackEventStream.listen((event) {
      AudioProcessingState bufferingState = event.buffering ? AudioProcessingState.buffering : null;
      switch (event.state) {
        case AudioPlaybackState.paused:
        case AudioPlaybackState.playing:
          _setState(bufferingState ?? AudioProcessingState.ready, pos: event.position);
          break;
        case AudioPlaybackState.connecting:
          _setState(_skipState ?? AudioProcessingState.connecting, pos: event.position);
          break;
        default:
          break;
      }
    });

    //Initialize later
    //await imagesDB.init();

    AudioServiceBackground.setQueue(_queue);
    AudioServiceBackground.sendCustomEvent({'action': 'onLoad'});
  }

  @override
  Future onSkipToNext() {
    //If repeating allowed
    if (repeatType == 2) {
      _skip(0);
      return null;
    }
    _skip(1);
  }

  @override
  Future onSkipToPrevious() => _skip(-1);

  Future _skip(int offset) async {
    int newPos = _queueIndex + offset;
    //Out of bounds
    if (newPos >= _queue.length || newPos < 0) return;
    //First song
    if (_playing == null) {
      _playing = true;
    } else if (_playing) {
      await _audioPlayer.stop();
    }
    //Update position, album art source, queue source text
    _queueIndex = newPos;
    //Get uri
    String uri = await _getTrackUri(mediaItem);
    //Modify extras
    Map<String, dynamic> extras = mediaItem.extras;
    extras.addAll({"qualityString": await _getQualityString(uri, mediaItem.duration)});
    _queue[_queueIndex] = mediaItem.copyWith(
      artUri: await _getArtUri(mediaItem.artUri),
      extras: extras
    );
    //Play
    AudioServiceBackground.setMediaItem(mediaItem);
    _skipState = offset > 0 ? AudioProcessingState.skippingToNext:AudioProcessingState.skippingToPrevious;
    //Load
    await _audioPlayer.setUrl(uri);
    _skipState = null;
    await _saveQueue();
    (_playing??false) ? onPlay() : _setState(AudioProcessingState.ready);
  }

  @override
  void onPlay() async {
    //Start playing preloaded queue
    if (AudioServiceBackground.state.processingState == AudioProcessingState.none && _queue.length > 0) {
      if (_queueIndex < 0 || _queueIndex == null) {
        await this._skip(1);
      } else {
        await this._skip(0);
      }
      //Restore position from saved queue
      if (_lastPosition != null) {
        onSeekTo(_lastPosition);
        _lastPosition = null;
      }
      return;
    }
    if (_skipState == null) {
      _playing = true;
      _audioPlayer.play();
    }
  }

  @override
  void onPause() {
    if (_skipState == null && _playing) {
      _playing = false;
      _audioPlayer.pause();
    }
  }

  @override
  void onSeekTo(Duration pos) {
    _audioPlayer.seek(pos);
  }

  @override
  void onClick(MediaButton button) {
    if (_playing) onPause();
    onPlay();
  }

  @override
  Future onUpdateQueue(List<MediaItem> q) async {
    this._queue = q;
    AudioServiceBackground.setQueue(_queue);
    await _saveQueue();
  }

  @override
  void onPlayFromMediaId(String mediaId) async {
    int pos = this._queue.indexWhere((mi) => mi.id == mediaId);
    await _skip(pos - _queueIndex);
    if (_playing == null || !_playing) onPlay();
  }

  @override
  Future onFastForward() async {
    await _seekRelative(fastForwardInterval);
  }

  @override
  void onAddQueueItemAt(MediaItem mi, int index) {
    _queue.insert(index, mi);
    AudioServiceBackground.setQueue(_queue);
    _saveQueue();
  }

  @override
  void onAddQueueItem(MediaItem mi) {
    _queue.add(mi);
    AudioServiceBackground.setQueue(_queue);
    _saveQueue();
  }

  @override
  Future onRewind() async {
    await _seekRelative(rewindInterval);
  }

  Future _seekRelative(Duration offset) async {
    Duration newPos = _audioPlayer.playbackEvent.position + offset;
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > mediaItem.duration) newPos = mediaItem.duration;
    onSeekTo(_audioPlayer.playbackEvent.position + offset);
  }

  //Audio interruptions
  @override
  void onAudioFocusLost(AudioInterruption interruption) {
    if (_playing) _interrupted = true;
    switch (interruption) {
      case AudioInterruption.pause:
      case AudioInterruption.temporaryPause:
      case AudioInterruption.unknownPause:
        if (_playing) onPause();
        break;
      case AudioInterruption.temporaryDuck:
        _audioPlayer.setVolume(0.5);
        break;
    }
  }

  @override
  void onAudioFocusGained(AudioInterruption interruption) {
    switch (interruption) {
      case AudioInterruption.temporaryPause:
        if (!_playing && _interrupted) onPlay();
        break;
      case AudioInterruption.temporaryDuck:
        _audioPlayer.setVolume(1.0);
        break;
      default:
        break;
    }
    _interrupted = false;
  }
  
  @override
  void onAudioBecomingNoisy() {
    onPause();
  }


  @override
  Future onCustomAction(String name, dynamic args) async {
    if (name == 'updateQuality') {
      //Pass wifi & mobile quality by custom action
      //Isolate can't access globals
      this.wifiQuality = args['wifiQuality'];
      this.mobileQuality = args['mobileQuality'];
    }
    if (name == 'saveQueue') {
      await this._saveQueue();
    }
    //Load queue, called after start
    if (name == 'load') {
      await _loadQueue();
    }
    //Change queue source
    if (name == 'queueSource') {
      this.queueSource = QueueSource.fromJson(Map<String, dynamic>.from(args));
    }
    //Shuffle
    if (name == 'shuffleQueue') {
      MediaItem mi = mediaItem;
      shuffle(this._queue);
      _queueIndex = _queue.indexOf(mi);
      AudioServiceBackground.setQueue(this._queue);
    }
    //Repeating
    if (name == 'repeatType') {
      this.repeatType = args;
    }
    return true;
  }

  Future<String> _getArtUri(String url) async {
    //Load from cache
    if (url.startsWith('http')) {
      //Prepare db
      if (imagesDB == null) {
        imagesDB = ImagesDatabase();
        await imagesDB.init();
      }

      String path = await imagesDB.getImage(url);
      return 'file://$path';
    }
    //If file
    if (url.startsWith('/')) return 'file://' + url;
    return url;
  }

  Future<String> _getTrackUri(MediaItem mi) async {
    String prefix = 'DEEZER|${mi.id}|';

    //Check if song is available offline
    String _offlinePath = p.join((await getExternalStorageDirectory()).path, 'offline/');
    File f = File(p.join(_offlinePath, mi.id));
    if (await f.exists()) return f.path;

    //Get online url
    Track t = Track(
      id: mi.id,
      playbackDetails: jsonDecode(mi.extras['playbackDetails']) //JSON Because of audio_service bug
    );
    ConnectivityResult conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.wifi) {
      return prefix + t.getUrl(wifiQuality);
    }
    return prefix + t.getUrl(mobileQuality);
  }

  Future<String> _getQualityString(String uri, Duration duration) async {
    //Get url/path
    String url = uri;
    List<String> split = uri.split('|');
    if (split.length >= 3) url = split[2];

    int size;
    String format;
    String source;

    //Local file
    if (url.startsWith('/')) {
      //Read first 4 bytes of file, get format
      File f = File(url);
      Stream<List<int>> reader = f.openRead(0, 4);
      List<int> magic = await reader.first;
      format = _magicToFormat(magic);
      size = await f.length();
      source = 'Offline';
    }

    //URL
    if (url.startsWith('http')) {
      Dio dio = Dio();
      Response response = await dio.head(url);
      size = int.parse(response.headers['Content-Length'][0]);
      //Parse format
      format = response.headers['Content-Type'][0];
      if (format.trim() == 'audio/mpeg') format = 'MP3';
      if (format.trim() == 'audio/flac') format = 'FLAC';
      source = 'Stream';
    }
    //Calculate
    return '$format ${_bitrateString(size, duration.inSeconds)} ($source)';
  }

  String _bitrateString(int size, int duration) {
    int bitrate = ((size / 125) / duration).floor();
    //Prettify
    if (bitrate > 315 && bitrate < 325) return '320kbps';
    if (bitrate > 125 && bitrate < 135) return '128kbps';
    return '${bitrate}kbps';
  }

  //Magic number to string, source: https://en.wikipedia.org/wiki/List_of_file_signatures
  String _magicToFormat(List<int> magic) {
    Function eq = const ListEquality().equals;
    if (eq(magic.sublist(0, 4), [0x66, 0x4c, 0x61, 0x43])) return 'FLAC';
    //MP3 With ID3
    if (eq(magic.sublist(0, 3), [0x49, 0x44, 0x33])) return 'MP3';
    //MP3
    List<int> m = magic.sublist(0, 2);
    if (eq(m, [0xff, 0xfb]) ||eq(m, [0xff, 0xf3]) || eq(m, [0xff, 0xf2])) return 'MP3';
    //Unknown
    return 'UNK';
  }

  @override
  void onTaskRemoved() async {
    await onStop();
  }

  @override
  Future onStop() async {
    _audioPlayer.stop();
    if (_playerStateSub != null) _playerStateSub.cancel();
    if (_eventSub != null) _eventSub.cancel();
    await _saveQueue();

    await super.onStop();
  }

  @override
  void onClose() async {
    //await _saveQueue();
    //Gets saved in onStop()
    await onStop();
  }

  //Update state
  void _setState(AudioProcessingState state, {Duration pos}) {
    AudioServiceBackground.setState(
      controls: _getControls(),
      systemActions: (_playing == null) ? [] : [MediaAction.seekTo],
      processingState: state ?? AudioServiceBackground.state.processingState,
      playing: _playing ?? false,
      position: pos ?? _audioPlayer.playbackEvent.position,
      bufferedPosition: pos ?? _audioPlayer.playbackEvent.position,
      speed: _audioPlayer.speed
    );
  }

  List<MediaControl> _getControls() {
    if (_playing == null || !_playing) {
      //Paused / not-started
      return [
        previousControl,
        playControl,
        nextControl
      ];
    }
    //Playing
    return [
      previousControl,
      pauseControl,
      nextControl
    ];
  }

  //Get queue saved file path
  Future<String> _getQueuePath() async {
    Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'offline.json');
  }

  //Export queue to JSON
  Future _saveQueue() async {
    print('save');
    File f = File(await _getQueuePath());
    await f.writeAsString(jsonEncode({
      'index': _queueIndex,
      'queue': _queue.map<Map<String, dynamic>>((mi) => mi.toJson()).toList(),
      'position': _audioPlayer.playbackEvent.position.inMilliseconds,
      'queueSource': (queueSource??QueueSource()).toJson(),
    }));
  }

  Future _loadQueue() async {
    File f = File(await _getQueuePath());
    if (await f.exists()) {
      Map<String, dynamic> json = jsonDecode(await f.readAsString());
      this._queue = (json['queue']??[]).map<MediaItem>((mi) => MediaItem.fromJson(mi)).toList();
      this._queueIndex = json['index'] ?? -1;
      this._lastPosition = Duration(milliseconds: json['position']??0);
      this.queueSource = QueueSource.fromJson(json['queueSource']??{});
      if (_queue != null) {
        AudioServiceBackground.setQueue(_queue);
        AudioServiceBackground.setMediaItem(mediaItem);
        //Update state to allow play button in notification
        this._setState(AudioProcessingState.none, pos: _lastPosition);
      }
      //Send restored queue source to ui
      AudioServiceBackground.sendCustomEvent({'action': 'onRestore', 'queueSource': (queueSource??QueueSource()).toJson()});
      return true;
    }
  }

}