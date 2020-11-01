import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezer/settings.dart';

import '../api/player.dart';
import 'cached_image.dart';
import 'player_screen.dart';

class PlayerBar extends StatelessWidget {
  double get progress {
    if (AudioService.playbackState == null) return 0.0;
    if (AudioService.currentMediaItem == null) return 0.0;
    if (AudioService.currentMediaItem.duration.inSeconds == 0) return 0.0; //Division by 0
    return AudioService.playbackState.currentPosition.inSeconds / AudioService.currentMediaItem.duration.inSeconds;
  }

  double iconSize = 28;
  bool _gestureRegistered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) async {
        if (_gestureRegistered) return;
        final double sensitivity = 12.69;
        //Right swipe
        _gestureRegistered = true;
        if (details.delta.dx > sensitivity) {
          await AudioService.skipToPrevious();
        }
        //Left
        if (details.delta.dx < -sensitivity) {

          await AudioService.skipToNext();
        }
        _gestureRegistered = false;
        return;
      },
      child: StreamBuilder(
        stream: Stream.periodic(Duration(milliseconds: 250)),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (AudioService.currentMediaItem == null)
            return Container(width: 0, height: 0,);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                color: Theme.of(context).bottomAppBarColor,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (BuildContext context) => PlayerScreen()));
                    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                      systemNavigationBarColor: settings.themeData
                          .scaffoldBackgroundColor,
                    ));
                  },
                  leading: CachedImage(
                    width: 50,
                    height: 50,
                    url: AudioService.currentMediaItem.extras['thumb'] ??
                        AudioService.currentMediaItem.artUri,
                  ),
                  title: Text(
                    AudioService.currentMediaItem.displayTitle,
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    AudioService.currentMediaItem.displaySubtitle ?? '',
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PrevNextButton(iconSize, prev: true, hidePrev: true,),
                      PlayPauseButton(iconSize),
                      PrevNextButton(iconSize)
                    ],
                  )
                ),
              ),
              Container(
                height: 3.0,
                child: LinearProgressIndicator(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  value: progress,
                ),
              )
            ],
          );
        }
      ),
    );
  }
}


class PrevNextButton extends StatelessWidget {

  final double size;
  final bool prev;
  final bool hidePrev;
  int i;
  PrevNextButton(this.size, {this.prev = false, this.hidePrev = false});

  @override
  Widget build(BuildContext context) {
    if (!prev) {
      if (playerHelper.queueIndex == (AudioService.queue??[]).length - 1) {
        return IconButton(
          icon: Icon(Icons.skip_next),
          iconSize: size,
          onPressed: null,
        );
      }
      return IconButton(
        icon: Icon(Icons.skip_next),
        iconSize: size,
        onPressed: () => AudioService.skipToNext(),
      );
    }
    if (prev) {
      if (i == 0) {
        if (hidePrev) {
          return Container(height: 0, width: 0,);
        }
        return IconButton(
          icon: Icon(Icons.skip_previous),
          iconSize: size,
          onPressed: null,
        );
      }
      return IconButton(
        icon: Icon(Icons.skip_previous),
        iconSize: size,
        onPressed: () => AudioService.skipToPrevious(),
      );
    }
    return Container();
  }
}



class PlayPauseButton extends StatelessWidget {

  final double size;
  PlayPauseButton(this.size);

  @override
  Widget build(BuildContext context) {

    return StreamBuilder(
      stream: AudioService.playbackStateStream,
      builder: (context, snapshot) {
        //Playing
        if (AudioService.playbackState?.playing??false) {
          return IconButton(
              iconSize: this.size,
              icon: Icon(Icons.pause),
              onPressed: () => AudioService.pause()
          );
        }

        //Paused
        if ((!(AudioService.playbackState?.playing??false) &&
            AudioService.playbackState.processingState == AudioProcessingState.ready) ||
            //None state (stopped)
            AudioService.playbackState.processingState == AudioProcessingState.none) {
          return IconButton(
              iconSize: this.size,
              icon: Icon(Icons.play_arrow),
              onPressed: () => AudioService.play()
          );
        }

        switch (AudioService.playbackState.processingState) {
        //Stopped/Error
          case AudioProcessingState.error:
          case AudioProcessingState.none:
          case AudioProcessingState.stopped:
            return Container(width: this.size, height: this.size);
        //Loading, connecting, rewinding...
          default:
            return Container(
              width: this.size,
              height: this.size,
              child: CircularProgressIndicator(),
            );
        }
      },
    );
  }
}
