import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_screenutil/screenutil.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/translations.i18n.dart';
import 'package:freezer/ui/menu.dart';
import 'package:freezer/ui/settings_screen.dart';
import 'package:freezer/ui/tiles.dart';
import 'package:async/async.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';

import 'cached_image.dart';
import '../api/definitions.dart';
import 'player_bar.dart';

import 'dart:ui';
import 'dart:async';

class PlayerScreen extends StatefulWidget {
  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {


  @override
  Widget build(BuildContext context) {
    //Responsive
    ScreenUtil.init(context, allowFontScaling: true);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder(
          stream: StreamZip([AudioService.playbackStateStream, AudioService.currentMediaItemStream]),
          builder: (BuildContext context, AsyncSnapshot snapshot) {

            //When disconnected
            if (AudioService.currentMediaItem == null) {
              playerHelper.startService();
              return Center(child: CircularProgressIndicator(),);
            }

            return OrientationBuilder(
              builder: (context, orientation) {
                //Landscape
                if (orientation == Orientation.landscape) {
                  return PlayerScreenHorizontal();
                }
                //Portrait
                return PlayerScreenVertical();
              },
            );

          },
        ),
      )
    );
  }
}

//Landscape
class PlayerScreenHorizontal extends StatefulWidget {
  @override
  _PlayerScreenHorizontalState createState() => _PlayerScreenHorizontalState();
}

class _PlayerScreenHorizontalState extends State<PlayerScreenHorizontal> {

  double iconSize = ScreenUtil().setWidth(64);
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: ScreenUtil().setWidth(500),
              child: Stack(
                children: <Widget>[
                  CachedImage(
                    url: AudioService.currentMediaItem.artUri,
                    fullThumb: true,
                  ),
                  if (_lyrics) LyricsWidget(
                    artUri: AudioService.currentMediaItem.extras['thumb'],
                    trackId: AudioService.currentMediaItem.id,
                    lyrics: Track.fromMediaItem(AudioService.currentMediaItem).lyrics,
                    height: ScreenUtil().setWidth(500),
                  ),
                ],
              ),
            )
        ),
        //Right side
        SizedBox(
          width: ScreenUtil().setWidth(500),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Padding(
                  padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
                  child: Container(
                    child: PlayerScreenTopRow(
                      textSize: ScreenUtil().setSp(26),
                      iconSize: ScreenUtil().setSp(32),
                      textWidth: ScreenUtil().setWidth(256),
                      short: true
                    ),
                  )
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: ScreenUtil().setSp(40),
                    child: AudioService.currentMediaItem.displayTitle.length >= 22 ?
                    Marquee(
                      text: AudioService.currentMediaItem.displayTitle,
                      style: TextStyle(
                          fontSize: ScreenUtil().setSp(40),
                          fontWeight: FontWeight.bold
                      ),
                      blankSpace: 32.0,
                      startPadding: 10.0,
                      accelerationDuration: Duration(seconds: 1),
                      pauseAfterRound: Duration(seconds: 2),
                    ):
                    Text(
                      AudioService.currentMediaItem.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: ScreenUtil().setSp(40),
                          fontWeight: FontWeight.bold
                      ),
                    )
                  ),
                  Container(height: 4,),
                  Text(
                    AudioService.currentMediaItem.displaySubtitle,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: ScreenUtil().setSp(32),
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SeekBar(),
              ),
              Container(
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
                    padding: EdgeInsets.symmetric(horizontal: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(Icons.subtitles, size: ScreenUtil().setWidth(32)),
                          onPressed: () {
                            setState(() => _lyrics = !_lyrics);
                          },
                        ),
                        FlatButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => QualitySettings())
                          ),
                          child: Text(
                            AudioService.currentMediaItem.extras['qualityString'] ?? '',
                            style: TextStyle(fontSize: ScreenUtil().setSp(24)),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_vert, size: ScreenUtil().setWidth(32)),
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
}



//Portrait
class PlayerScreenVertical extends StatefulWidget {
  @override
  _PlayerScreenVerticalState createState() => _PlayerScreenVerticalState();
}

class _PlayerScreenVerticalState extends State<PlayerScreenVertical> {
  double iconSize = ScreenUtil().setWidth(100);
  bool _lyrics = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Padding(
            padding: EdgeInsets.fromLTRB(28, 10, 28, 0),
            child: PlayerScreenTopRow()
        ),
        Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              height: ScreenUtil().setHeight(1050),
              child: Stack(
                children: <Widget>[
                  CachedImage(
                    url: AudioService.currentMediaItem.artUri,
                    fullThumb: true,
                  ),
                  if (_lyrics) LyricsWidget(
                    artUri: AudioService.currentMediaItem.extras['thumb'],
                    trackId: AudioService.currentMediaItem.id,
                    lyrics: Track.fromMediaItem(AudioService.currentMediaItem).lyrics,
                    height: ScreenUtil().setHeight(1050),
                  ),
                ],
              ),
            )
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: ScreenUtil().setSp(64),
              child: AudioService.currentMediaItem.displayTitle.length >= 24 ?
              Marquee(
                text: AudioService.currentMediaItem.displayTitle,
                style: TextStyle(
                  fontSize: ScreenUtil().setSp(64),
                  fontWeight: FontWeight.bold
                ),
                blankSpace: 32.0,
                startPadding: 10.0,
                accelerationDuration: Duration(seconds: 1),
                pauseAfterRound: Duration(seconds: 2),
              ):
              Text(
                AudioService.currentMediaItem.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ScreenUtil().setSp(64),
                  fontWeight: FontWeight.bold
                ),
              )
            ),
            Container(height: 4,),
            Text(
              AudioService.currentMediaItem.displaySubtitle,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: ScreenUtil().setSp(52),
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
          padding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.subtitles, size: ScreenUtil().setWidth(46)),
                onPressed: () {
                  setState(() => _lyrics = !_lyrics);
                },
              ),
              FlatButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QualitySettings())
                ),
                child: Text(
                  AudioService.currentMediaItem.extras['qualityString'] ?? '',
                  style: TextStyle(
                    fontSize: ScreenUtil().setSp(32),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, size: ScreenUtil().setWidth(46)),
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
  double _lyricHeight = 128;
  String _trackId;

  Future _load() async {
    _trackId = widget.trackId;

    //Get text color by album art (black or white)
    if (widget.artUri != null) {
      bool bw = await imagesDatabase.isDark(widget.artUri);
      if (bw != null) setState(() => _textColor = bw?Colors.white:Colors.black);
    }

    if (widget.lyrics.lyrics == null || widget.lyrics.lyrics.length == 0) {
      //Load from api
      try {
        _l = await deezerAPI.lyrics(_trackId);
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
        (_lyricHeight * _currentIndex) + (_lyricHeight / 2) - (_boxHeight / 2),
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
  void didUpdateWidget(LyricsWidget oldWidget) {
    if (this._trackId != widget.trackId) {
      setState(() {
        _loading = true;
        this._trackId = widget.trackId;
      });
      _load();
    }
    super.didUpdateWidget(oldWidget);
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
                      height: _lyricHeight,
                      child: Center(
                        child: Stack(
                          children: <Widget>[
                            Text(
                              _l.lyrics[i].text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28.0,
                                fontWeight: (_currentIndex == i)?FontWeight.bold:FontWeight.normal,
                                foreground: Paint()
                                  ..strokeWidth = 6
                                  ..style = PaintingStyle.stroke
                                  ..color = (_textColor==Colors.black)?Colors.white:Colors.black,
                              ),
                            ),
                            Text(
                              _l.lyrics[i].text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _textColor,
                                  fontSize: 28.0,
                                  fontWeight: (_currentIndex == i)?FontWeight.bold:FontWeight.normal
                              ),
                            ),
                          ],
                        )
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

  double textSize;
  double iconSize;
  double textWidth;
  bool short;
  PlayerScreenTopRow({this.textSize, this.iconSize, this.textWidth, this.short});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 8, 0),
              child: InkWell(
                child: Container(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.keyboard_arrow_down, size: this.iconSize??ScreenUtil().setWidth(46)),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            Container(
              width: this.textWidth??ScreenUtil().setWidth(550),
              child: Text(
                (short??false)?playerHelper.queueSource.text:'Playing from:'.i18n + ' ' + playerHelper.queueSource.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: this.textSize??ScreenUtil().setSp(34)),
              ),
            )
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RepeatButton(size: this.iconSize),
            Container(width: 16.0,),
            InkWell(
              child: Container(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.menu, size: this.iconSize??ScreenUtil().setWidth(46)),
              ),
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

  double size;
  RepeatButton({this.size, Key key}): super(key: key);

  @override
  _RepeatButtonState createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {

  double _size = ScreenUtil().setWidth(46);

  Icon get icon {
    switch (playerHelper.repeatType) {
      case LoopMode.off:
        return Icon(Icons.repeat, size: widget.size??_size);
      case LoopMode.all:
        return Icon(
          Icons.repeat,
          color: Theme.of(context).primaryColor,
          size: widget.size??_size
        );
      case LoopMode.one:
        return Icon(
          Icons.repeat_one,
          color: Theme.of(context).primaryColor,
          size: widget.size??_size
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
      child: Container(
        padding: EdgeInsets.all(8.0),
        child: icon,
      ),
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
                        fontSize: ScreenUtil().setSp(35)
                    ),
                  ),
                  Text(
                    _timeString(duration),
                    style: TextStyle(
                        fontSize: ScreenUtil().setSp(35)
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

  //Get proper icon color by theme
  Color get shuffleIconColor {
    Color og = Theme.of(context).primaryColor;
    if (og.computeLuminance() > 0.5) {
     if (playerHelper.shuffle) return Theme.of(context).primaryColorLight;
      return Colors.black;
    }
    if (playerHelper.shuffle) return Theme.of(context).primaryColorDark;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Queue'.i18n),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.shuffle,
                color: shuffleIconColor
              ),
              onPressed: () async {
                await playerHelper.toggleShuffle();
                setState(() {});
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