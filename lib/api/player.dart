import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/cache.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/ui/android_auto.dart';
import 'package:just_audio/just_audio.dart';
import 'package:connectivity/connectivity.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:freezer/translations.i18n.dart';

import 'definitions.dart';
import '../settings.dart';

import 'dart:io';
import 'dart:async';
import 'dart:convert';

PlayerHelper playerHelper = PlayerHelper();

class PlayerHelper {

  StreamSubscription _customEventSubscription;
  StreamSubscription _mediaItemSubscription;
  StreamSubscription _playbackStateStreamSubscription;
  QueueSource queueSource;
  LoopMode repeatType = LoopMode.off;
  //Find queue index by id
  int get queueIndex => AudioService.queue == null ? 0 : AudioService.queue.indexWhere((mi) => mi.id == AudioService.currentMediaItem?.id??'Random string so it returns -1');

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
        onQueueEnd();
        return;
      }
      //Android auto get screen
      if (event['action'] == 'screenAndroidAuto') {
        AndroidAuto androidAuto = AndroidAuto();
        List<MediaItem> data = await androidAuto.getScreen(event['id']);
        await AudioService.customAction('screenAndroidAuto', jsonEncode(data));
      }
      //Android auto play list
      if (event['action'] == 'tracksAndroidAuto') {
        AndroidAuto androidAuto = AndroidAuto();
        await androidAuto.playItem(event['id']);
      }
    });
    _playbackStateStreamSubscription = AudioService.playbackStateStream.listen((event) {
      //Log song (if allowed)
      if (event == null) return;
      if (event.processingState == AudioProcessingState.ready && event.playing) {
        if (settings.logListen) {
          //Check if duplicate
          if (cache.loggedTrackId == AudioService.currentMediaItem.id) return;
          cache.loggedTrackId = AudioService.currentMediaItem.id;
          deezerAPI.logListen(AudioService.currentMediaItem.id);
        }
      }
    });
    _mediaItemSubscription = AudioService.currentMediaItemStream.listen((event) {
      if (event == null) return;
      //Save queue
      AudioService.customAction('saveQueue');
      //Add to history
      if (cache.history == null) cache.history = [];
      if (cache.history.length > 0 && cache.history.last.id == event.id) return;
      cache.history.add(Track.fromMediaItem(event));
      cache.save();
    });

    //Start audio_service
    await startService();
  }

  Future startService() async {
    if (AudioService.running && AudioService.connected) return;
    if (!AudioService.connected)
      await AudioService.connect();
    if (!AudioService.running)
      await AudioService.start(
        backgroundTaskEntrypoint: backgroundTaskEntrypoint,
        androidEnableQueue: true,
        androidStopForegroundOnPause: false,
        androidNotificationOngoing: false,
        androidNotificationClickStartsActivity: true,
        androidNotificationChannelDescription: 'Freezer',
        androidNotificationChannelName: 'Freezer',
        androidNotificationIcon: 'drawable/ic_logo',
        params: {'ignoreInterruptions': settings.ignoreInterruptions}
      );
  }

  Future toggleShuffle() async {
    await AudioService.customAction('shuffle');
  }
  
  //Repeat toggle
  Future changeRepeat() async {
    //Change to next repeat type
    switch (repeatType) {
      case LoopMode.one:
        repeatType = LoopMode.off; break;
      case LoopMode.all:
        repeatType = LoopMode.one; break;
      default:
        repeatType = LoopMode.all; break;
    }
    //Set repeat type
    await AudioService.customAction("repeatType", LoopMode.values.indexOf(repeatType));
  }

  //Executed before exit
  Future onExit() async {
    _customEventSubscription.cancel();
    _playbackStateStreamSubscription.cancel();
    _mediaItemSubscription.cancel();
  }

  //Replace queue, play specified track id
  Future _loadQueuePlay(List<MediaItem> queue, String trackId) async {
    await startService();
    await settings.updateAudioServiceQuality();
    await AudioService.updateQueue(queue);
    if (queue[0].id != trackId)
      await AudioService.skipToQueueItem(trackId);
    if (!AudioService.playbackState.playing)
      AudioService.play();
  }

  //Called when queue ends to load more tracks
  Future onQueueEnd() async {
    //Flow
    if (queueSource == null) return;

    if (queueSource.id == 'flow') {
      List<Track> tracks = await deezerAPI.flow();
      List<MediaItem> mi = tracks.map<MediaItem>((t) => t.toMediaItem()).toList();
      await AudioService.addQueueItems(mi);
      AudioService.skipToNext();
      return;
    }

    //SmartRadio/Artist radio
    if (queueSource.source == 'smartradio') {
      List<Track> tracks = await deezerAPI.smartRadio(queueSource.id);
      List<MediaItem> mi = tracks.map<MediaItem>((t) => t.toMediaItem()).toList();
      await AudioService.addQueueItems(mi);
      AudioService.skipToNext();
      return;
    }

    //Library shuffle
    if (queueSource.source == 'libraryshuffle') {
      List<Track> tracks = await deezerAPI.libraryShuffle(start: AudioService.queue.length);
      List<MediaItem> mi = tracks.map<MediaItem>((t) => t.toMediaItem()).toList();
      await AudioService.addQueueItems(mi);
      AudioService.skipToNext();
      return;
    }

    print(queueSource.toJson());
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
    await startService();

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
          msg: "Offline mode, can't play flow or smart track lists.".i18n,
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
      text: stl.title??((stl.id == 'flow') ? 'Flow'.i18n : 'Smart track list'.i18n)
    );
    await playFromTrackList(stl.tracks, stl.tracks[0].id, queueSource);
  }
  
  Future setQueueSource(QueueSource queueSource) async {
    await startService();

    this.queueSource = queueSource;
    await AudioService.customAction('queueSource', queueSource.toJson());
  }

  //Reorder tracks in queue
  Future reorder(int oldIndex, int newIndex) async {
    await AudioService.customAction('reorder', [oldIndex, newIndex]);
  }

}

void backgroundTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player;

  //Queue
  List<MediaItem> _queue = <MediaItem>[];
  int _queueIndex = 0;
  ConcatenatingAudioSource _audioSource;

  AudioProcessingState _skipState;
  Seeker _seeker;

  //Stream subscriptions
  StreamSubscription _eventSub;

  //Loaded from file/frontend
  int mobileQuality;
  int wifiQuality;
  QueueSource queueSource;
  Duration _lastPosition;

  Completer _androidAutoCallback;

  MediaItem get mediaItem => _queue[_queueIndex];

  @override
  Future onStart(Map<String, dynamic> params) async {

    final session = await AudioSession.instance;
    session.configure(AudioSessionConfiguration.music());

    if (params['ignoreInterruptions'] == true) {
      _player = AudioPlayer(handleInterruptions: false);
      session.interruptionEventStream.listen((_) {});
      session.becomingNoisyEventStream.listen((_) {});
    } else
      _player = AudioPlayer();

    //Update track index
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        _queueIndex = index;
        AudioServiceBackground.setMediaItem(mediaItem);
      }
    });
    //Update state on all clients on change
    _eventSub = _player.playbackEventStream.listen((event) {
      //Quality string
      if (_queueIndex != -1 && _queueIndex < _queue.length) {
        Map extras = mediaItem.extras;
        extras['qualityString'] = event.qualityString??'';
        _queue[_queueIndex] = mediaItem.copyWith(extras: extras);
      }
      //Update
      _broadcastState();
    });
    _player.processingStateStream.listen((state) {
        switch(state) {
          case ProcessingState.completed:
            //Player ended, get more songs
            if (_queueIndex == _queue.length - 1)
              AudioServiceBackground.sendCustomEvent({
                'action': 'queueEnd',
                'queueSource': (queueSource??QueueSource()).toJson()
              });
            break;
          case ProcessingState.ready:
            //Ready to play
            _skipState = null;
            break;
          default:
            break;
        }
    });

    //Load queue
    AudioServiceBackground.setQueue(_queue);
    AudioServiceBackground.sendCustomEvent({'action': 'onLoad'});
  }

  @override
  Future onSkipToQueueItem(String mediaId) async {
    _lastPosition = null;

    //Calculate new index
    final newIndex = _queue.indexWhere((i) => i.id == mediaId);
    if (newIndex == -1) return;
    //Update buffering state
    _skipState = newIndex > _queueIndex
      ? AudioProcessingState.skippingToNext
      : AudioProcessingState.skippingToPrevious;

    //Skip in player
    await _player.seek(Duration.zero, index: newIndex);
    _queueIndex = newIndex;
    _skipState = null;
    onPlay();
  }

  @override
  Future onPlay() {
    _player.play();
    //Restore position on play
    if (_lastPosition != null) {
      onSeekTo(_lastPosition);
      _lastPosition = null;
    }
  }

  @override
  Future onPause() => _player.pause();

  @override
  Future onSeekTo(Duration pos) => _player.seek(pos);

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onSeekForward(bool begin) async => _seekContinuously(begin, 1);

  @override
  Future<void> onSeekBackward(bool begin) async => _seekContinuously(begin, -1);

  @override
  Future<void> onSkipToNext() async {
    if (_queueIndex == _queue.length-1) return;
    //Update buffering state
    _skipState = AudioProcessingState.skippingToNext;
    _queueIndex++;
    await _player.seekToNext();
    _skipState = null;
    await _broadcastState();
  }

  @override
  Future<void> onSkipToPrevious() async {
    if (_queueIndex == 0) return;
    //Update buffering state
    _skipState = AudioProcessingState.skippingToPrevious;

    //Normal skip to previous
    _queueIndex--;
    await _player.seekToPrevious();
    _skipState = null;
  }

  @override
  Future<List<MediaItem>> onLoadChildren(String parentMediaId) async {
    AudioServiceBackground.sendCustomEvent({
      'action': 'screenAndroidAuto',
      'id': parentMediaId
    });

    //Wait for data from main thread
    _androidAutoCallback = Completer();
    List<MediaItem> data = (await _androidAutoCallback.future) as List<MediaItem>;
    _androidAutoCallback = null;
    return data;
  }

  //While seeking, jump 10s every 1s
  void _seekContinuously(bool begin, int direction) {
    _seeker?.stop();
    if (begin) {
      _seeker = Seeker(_player, Duration(seconds: 10 * direction), Duration(seconds: 1), mediaItem)..start();
    }
  }

  //Relative seek
  Future _seekRelative(Duration offset) async {
    Duration newPos = _player.position + offset;
    //Out of bounds check
    if (newPos < Duration.zero) newPos = Duration.zero;
    if (newPos > mediaItem.duration) newPos = mediaItem.duration;

    await _player.seek(newPos);
  }

  //Update state on all clients
  Future _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        //Stop
        MediaControl(
            androidIcon: 'drawable/ic_action_stop',
            label: 'stop',
            action: MediaAction.stop
        ),
      ],
      systemActions: [
        MediaAction.seekTo,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.stop
      ],
      processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed
    );
  }

  //just_audio state -> audio_service state. If skipping, use _skipState
  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState;
    //SRC: audio_service example
    switch (_player.processingState) {
      case ProcessingState.none:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception("Invalid state: ${_player.processingState}");
    }
  }

  //Replace current queue
  @override
  Future onUpdateQueue(List<MediaItem> q) async {
    //just_audio
    _player.stop();
    if (_audioSource != null) _audioSource.clear();
    //audio_service
    this._queue = q;
    AudioServiceBackground.setQueue(_queue);
    //Load
    _queueIndex = 0;
    await _loadQueue();
    //await _player.seek(Duration.zero, index: 0);
  }

  //Load queue to just_audio
  Future _loadQueue() async {
    //Don't reset queue index by starting player
    int qi = _queueIndex;

    List<AudioSource> sources = [];
    for(int i=0; i<_queue.length; i++) {
      AudioSource s = await _mediaItemToAudioSource(_queue[i]);
      if (s != null)
        sources.add(s);
    }

    _audioSource = ConcatenatingAudioSource(children: sources);
    //Load in just_audio
    try {
      await _player.load(_audioSource);
      await _player.seek(Duration.zero, index: qi);
    } catch (e) {
      //Error loading tracks
    }
    _queueIndex = qi;
    AudioServiceBackground.setMediaItem(mediaItem);
  }

  Future<AudioSource> _mediaItemToAudioSource(MediaItem mi) async {
    String url = await _getTrackUrl(mi);
    if (url == null) return null;
    if (url.startsWith('http')) return ProgressiveAudioSource(Uri.parse(url));
    return AudioSource.uri(Uri.parse(url));
  }

  Future _getTrackUrl(MediaItem mediaItem, {int quality}) async {
    //Check if offline
    String _offlinePath = p.join((await getExternalStorageDirectory()).path, 'offline/');
    File f = File(p.join(_offlinePath, mediaItem.id));
    if (await f.exists()) {
      return f.path;
    }

    //Due to current limitations of just_audio, quality fallback moved to DeezerDataSource in ExoPlayer
    //This just returns fake url that contains metadata
    List playbackDetails = jsonDecode(mediaItem.extras['playbackDetails']);
    //Quality
    ConnectivityResult conn = await Connectivity().checkConnectivity();
    quality = mobileQuality;
    if (conn == ConnectivityResult.wifi) quality = wifiQuality;

    if ((playbackDetails??[]).length < 2) return null;
    String url = 'https://dzcdn.net/?md5=${playbackDetails[0]}&mv=${playbackDetails[1]}&q=${quality.toString()}#${mediaItem.id}';
    return url;
  }

  //Custom actions
  @override
  Future onCustomAction(String name, dynamic args) async {
    if (name == 'updateQuality') {
      //Pass wifi & mobile quality by custom action
      //Isolate can't access globals
      this.wifiQuality = args['wifiQuality'];
      this.mobileQuality = args['mobileQuality'];
    }
    //Change queue source
    if (name == 'queueSource') {
      this.queueSource = QueueSource.fromJson(Map<String, dynamic>.from(args));
    }
    //Looping
    if (name == 'repeatType') {
      _player.setLoopMode(LoopMode.values[args]);
    }
    if (name == 'saveQueue')
      await this._saveQueue();
    //Load queue after some initialization in frontend
    if (name == 'load')
      await this._loadQueueFile();
    //Shuffle
    if (name == 'shuffle') {
      _queue.shuffle();
      AudioServiceBackground.setQueue(_queue);
      _queueIndex = 0;
      await _loadQueue();
    }
    //Android auto callback
    if (name == 'screenAndroidAuto' && _androidAutoCallback != null) {
      _androidAutoCallback.complete(jsonDecode(args).map<MediaItem>((m) => MediaItem.fromJson(m)).toList());
    }
    //Reorder tracks, args = [old, new]
    if (name == 'reorder') {
      await _audioSource.move(args[0], args[1]);
      //Switch in queue
      List<MediaItem> newQueue = List.from(_queue);
      newQueue.removeAt(args[0]);
      newQueue.insert(args[1], _queue[args[0]]);
      _queue = newQueue;
      //Update UI
      AudioServiceBackground.setQueue(_queue);
      _broadcastState();
    }

    return true;
  }

  @override
  Future onTaskRemoved() async {
    await onStop();
  }

  @override
  Future onClose() async {
    print('onClose');
    await onStop();
  }

  Future onStop() async {
    await _saveQueue();
    _player.stop();
    if (_eventSub != null) _eventSub.cancel();

    await super.onStop();
  }

  //Get queue save file path
  Future<String> _getQueuePath() async {
    Directory dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'playback.json');
  }

  //Export queue to JSON
  Future _saveQueue() async {
    if (_queueIndex == 0 && _queue.length == 0) return;

    String path = await _getQueuePath();
    File f = File(path);
    //Create if doesn't exist
    if (! await File(path).exists()) {
      f = await f.create();
    }
    Map data = {
      'index': _queueIndex,
      'queue': _queue.map<Map<String, dynamic>>((mi) => mi.toJson()).toList(),
      'position': _player.position.inMilliseconds,
      'queueSource': (queueSource??QueueSource()).toJson(),
    };
    await f.writeAsString(jsonEncode(data));
  }

  //Restore queue & playback info from path
  Future _loadQueueFile() async {
    File f = File(await _getQueuePath());
    if (await f.exists()) {
      Map<String, dynamic> json = jsonDecode(await f.readAsString());
      this._queue = (json['queue']??[]).map<MediaItem>((mi) => MediaItem.fromJson(mi)).toList();
      this._queueIndex = json['index'] ?? 0;
      this._lastPosition = Duration(milliseconds: json['position']??0);
      this.queueSource = QueueSource.fromJson(json['queueSource']??{});
      //Restore queue
      if (_queue != null) {
        await AudioServiceBackground.setQueue(_queue);
        await _loadQueue();
        await AudioServiceBackground.setMediaItem(mediaItem);
      }
    }
    //Send restored queue source to ui
    AudioServiceBackground.sendCustomEvent({
      'action': 'onRestore',
      'queueSource': (queueSource??QueueSource()).toJson()
    });
    return true;
  }

  @override
  Future onAddQueueItemAt(MediaItem mi, int index) async {
    //-1 == play next
    if (index == -1) index = _queueIndex + 1;

    _queue.insert(index, mi);
    await AudioServiceBackground.setQueue(_queue);
    AudioSource _newSource =  await _mediaItemToAudioSource(mi);
    if (_newSource != null)
      await _audioSource.insert(index,_newSource);

    _saveQueue();
  }

  //Add at end of queue
  @override
  Future onAddQueueItem(MediaItem mi) async {
    _queue.add(mi);
    await AudioServiceBackground.setQueue(_queue);
    AudioSource _newSource =  await _mediaItemToAudioSource(mi);
    if (_newSource != null)
      await _audioSource.add(_newSource);
    _saveQueue();
  }

  @override
  Future onPlayFromMediaId(String mediaId) async {

    //Android auto load tracks
    if (mediaId.startsWith(AndroidAuto.prefix)) {
      AudioServiceBackground.sendCustomEvent({
        'action': 'tracksAndroidAuto',
        'id': mediaId.replaceFirst(AndroidAuto.prefix, '')
      });
      return;
    }

    //Does the same thing
    await this.onSkipToQueueItem(mediaId);
  }

}

//Seeker from audio_service example (why reinvent the wheel?)
//While holding seek button, will continuously seek
class Seeker {
  final AudioPlayer player;
  final Duration positionInterval;
  final Duration stepInterval;
  final MediaItem mediaItem;
  bool _running = false;

  Seeker(this.player, this.positionInterval, this.stepInterval, this.mediaItem);

  Future start() async {
    _running = true;
    while (_running) {
      Duration newPosition = player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
      player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  void stop() {
    _running = false;
  }
}