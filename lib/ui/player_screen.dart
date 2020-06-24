import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/ui/menu.dart';
import 'package:freezer/ui/tiles.dart';
import 'package:async/async.dart';

import 'cached_image.dart';
import '../api/definitions.dart';
import 'player_bar.dart';




class PlayerScreen extends StatefulWidget {
  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {

  double iconSize = 48;
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: StreamZip([AudioService.playbackStateStream, AudioService.currentMediaItemStream]),
          builder: (BuildContext context, AsyncSnapshot snapshot) {

            //Disable lyrics when skipping songs, loading
            if (snapshot.data is PlaybackState &&
              snapshot.data.processingState != AudioProcessingState.ready &&
              snapshot.data.processingState != AudioProcessingState.buffering) _lyrics = false;

            //When disconnected
            if (AudioService.currentMediaItem == null) {
              playerHelper.startService();
              return Center(child: CircularProgressIndicator(),);
            }

              return OrientationBuilder(
                builder: (context, orientation) {
                  //Landscape
                  if (orientation == Orientation.landscape) {
                    return Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Container(
                              width: 320,
                              child: Stack(
                                children: <Widget>[
                                  CachedImage(
                                    url: AudioService.currentMediaItem.artUri,
                                  ),
                                  if (_lyrics) LyricsWidget(
                                    artUri: AudioService.currentMediaItem.artUri,
                                    trackId: AudioService.currentMediaItem.id,
                                    lyrics: Track.fromMediaItem(AudioService.currentMediaItem).lyrics,
                                    height: 320.0,
                                  ),
                                ],
                              ),
                            )
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Padding(
                                  padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
                                  child: Container(
                                    width: 300,
                                    child: PlayerScreenTopRow(),
                                  )
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    AudioService.currentMediaItem.displayTitle,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                        fontSize: 24.0,
                                        fontWeight: FontWeight.bold
                                    ),
                                  ),
                                  Container(height: 4,),
                                  Text(
                                    AudioService.currentMediaItem.displaySubtitle,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 320,
                                child: SeekBar(),
                              ),
                              Container(
                                width: 320,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  mainAxisSize: MainAxisSize.max,
                                  children: <Widget>[
                                    PrevNextButton(iconSize, prev: true,),
                                    PlayPauseButton(iconSize),
                                    PrevNextButton(iconSize)
                                  ],
                                ),
                              ),
                              Padding(
                                  padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
                                  child: Container(
                                    width: 300,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        IconButton(
                                          icon: Icon(Icons.subtitles),
                                          onPressed: () {
                                            setState(() => _lyrics = !_lyrics);
                                          },
                                        ),
                                        Text(
                                            AudioService.currentMediaItem.extras['qualityString']
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.more_vert),
                                          onPressed: () {
                                            Track t = Track.fromMediaItem(AudioService.currentMediaItem);
                                            MenuSheet m = MenuSheet(context);
                                            m.defaultTrackMenu(t);
                                          },
                                        )
                                      ],
                                    ),
                                  )
                              )
                            ],
                          ),
                        )
                      ],
                    );
                  }

                  //Portrait
                  return Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Padding(
                          padding: EdgeInsets.fromLTRB(28, 16, 28, 0),
                          child: PlayerScreenTopRow()
                      ),
                      Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Container(
                            height: 360,
                            child: Stack(
                              children: <Widget>[
                                CachedImage(
                                  url: AudioService.currentMediaItem.artUri,
                                ),
                                if (_lyrics) LyricsWidget(
                                  artUri: AudioService.currentMediaItem.artUri,
                                  trackId: AudioService.currentMediaItem.id,
                                  lyrics: Track.fromMediaItem(AudioService.currentMediaItem).lyrics,
                                  height: 360.0,
                                ),
                              ],
                            ),
                          )
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            AudioService.currentMediaItem.displayTitle,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                          Container(height: 4,),
                          Text(
                            AudioService.currentMediaItem.displaySubtitle,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: 18.0,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SeekBar(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          PrevNextButton(iconSize, prev: true,),
                          PlayPauseButton(iconSize),
                          PrevNextButton(iconSize)
                        ],
                      ),
                      //Container(height: 8.0,),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            IconButton(
                              icon: Icon(Icons.subtitles),
                              onPressed: () {
                                setState(() => _lyrics = !_lyrics);
                              },
                            ),
                            Text(
                                AudioService.currentMediaItem.extras['qualityString']
                            ),
                            IconButton(
                              icon: Icon(Icons.more_vert),
                              onPressed: () {
                                Track t = Track.fromMediaItem(AudioService.currentMediaItem);
                                MenuSheet m = MenuSheet(context);
                                m.defaultTrackMenu(t);
                              },
                            )
                          ],
                        ),
                      )
                    ],
                  );

                },
              );
          },
        ),
      )
    );
  }
}

class LyricsWidget extends StatefulWidget {

  final Lyrics lyrics;
  final String trackId;
  final String artUri;
  final double height;
  LyricsWidget({this.artUri, this.lyrics, this.trackId, this.height, Key key}): super(key: key);

  @override
  _LyricsWidgetState createState() => _LyricsWidgetState();
}

class _LyricsWidgetState extends State<LyricsWidget> {

  bool _loading = true;
  Lyrics _l;
  Color _textColor = Colors.black;
  ScrollController _scrollController = ScrollController();
  Timer _timer;
  int _currentIndex;
  double _boxHeight;

  Future _load() async {
    //Get text color by album art (black or white)
    if (widget.artUri != null) {
      bool bw = await imagesDatabase.isDark(widget.artUri);
      if (bw != null) setState(() => _textColor = bw?Colors.white:Colors.black);
    }

    if (widget.lyrics.lyrics == null || widget.lyrics.lyrics.length == 0) {
      //Load from api
      try {
        _l = await deezerAPI.lyrics(widget.trackId);
        setState(() => _loading = false);
      } catch (e) {
        //Error Lyrics
        setState(() => _l = Lyrics().error);
      }
    } else {
      //Use provided lyrics
      _l = widget.lyrics;
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    this._boxHeight = widget.height??400.0;
    _load();
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      _timer = timer;
      if (_loading) return;
      //Update index of current lyric
      setState(() {
        _currentIndex = _l.lyrics.lastIndexWhere((l) => l.offset <= AudioService.playbackState.currentPosition);
      });
      //Scroll to current lyric
      if (_currentIndex <= 0) return;
      _scrollController.animateTo(
        (_boxHeight * _currentIndex),
        duration: Duration(milliseconds: 250),
        curve: Curves.ease
      );

    });
    super.initState();
  }

  @override
  void dispose() {
    if (_timer != null) _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _boxHeight,
      width: _boxHeight,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 7.0,
          sigmaY: 7.0
        ),
        child: Container(
            child: _loading?
            Center(child: CircularProgressIndicator(),) :
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: List.generate(_l.lyrics.length, (i) {
                  return Container(
                      height: _boxHeight,
                      child: Center(
                        child: Text(
                          _l.lyrics[i].text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _textColor,
                              fontSize: 40.0,
                              fontWeight: (_currentIndex == i)?FontWeight.bold:FontWeight.normal
                          ),
                        ),
                      )
                  );
                }),
              ),
            )
        ),
      ),
    );
  }
}

//Top row containing QueueSource, queue...
class PlayerScreenTopRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          'Playing from: ' + playerHelper.queueSource.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 16.0),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RepeatButton(),
            Container(width: 16.0,),
            InkWell(
              child: Icon(Icons.menu),
              onTap: (){
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => QueueScreen()
                ));
              },
            ),
          ],
        )
      ],
    );
  }
}



class RepeatButton extends StatefulWidget {
  @override
  _RepeatButtonState createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {

  Icon get icon {
    switch (playerHelper.repeatType) {
      case RepeatType.NONE:
        return Icon(Icons.repeat);
      case RepeatType.LIST:
        return Icon(
          Icons.repeat,
          color: Theme.of(context).primaryColor,
        );
      case RepeatType.TRACK:
        return Icon(
          Icons.repeat_one,
          color: Theme.of(context).primaryColor,
        );
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await playerHelper.changeRepeat();
        setState(() {});
      },
      child: icon,
    );
  }
}



class SeekBar extends StatefulWidget {
  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {

  bool _seeking = false;
  double _pos;

  double get position {
    if (_seeking) return _pos;
    if (AudioService.playbackState == null) return 0.0;
    double p = AudioService.playbackState.currentPosition.inMilliseconds.toDouble()??0.0;
    if (p > duration) return duration;
    return p;
  }

  //Duration to mm:ss
  String _timeString(double pos) {
    Duration d = Duration(milliseconds: pos.toInt());
    return "${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  double get duration {
    if (AudioService.currentMediaItem == null) return 1.0;
    return AudioService.currentMediaItem.duration.inMilliseconds.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(Duration(milliseconds: 250)),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _timeString(position),
                    style: TextStyle(
                        fontSize: 14.0
                    ),
                  ),
                  Text(
                    _timeString(duration),
                    style: TextStyle(
                        fontSize: 14.0
                    ),
                  )
                ],
              ),
            ),
            Container(
              height: 32.0,
              child: Slider(
                value: position,
                max: duration,
                onChangeStart: (double d) {
                  setState(() {
                    _seeking = true;
                    _pos = d;
                  });
                },
                onChanged: (double d) {
                  setState(() {
                    _pos = d;
                  });
                },
                onChangeEnd: (double d) async {
                  await AudioService.seekTo(Duration(milliseconds: d.round()));
                  setState(() {
                    _pos = d;
                    _seeking = false;
                  });
                },
              ),
            )
          ],
        );
      },
    );
  }
}

class QueueScreen extends StatefulWidget {
  @override
  _QueueScreenState createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Queue'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.shuffle),
              onPressed: () async {
                await AudioService.customAction('shuffleQueue');
                setState(() => {});
              },
            )
          ],
        ),
        body: ListView.builder(
          itemCount: AudioService.queue.length,
          itemBuilder: (context, i) {
            Track t = Track.fromMediaItem(AudioService.queue[i]);
            return TrackTile(
              t,
              onTap: () async {
                await AudioService.playFromMediaId(t.id);
                Navigator.of(context).pop();
              },
              onHold: () {
                MenuSheet m = MenuSheet(context);
                m.defaultTrackMenu(t);
              },
            );
          },
        )
    );
  }
}