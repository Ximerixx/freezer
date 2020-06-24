import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../api/definitions.dart';
import 'cached_image.dart';

class TrackTile extends StatefulWidget {

  final Track track;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  TrackTile(this.track, {this.onTap, this.onHold, this.trailing, Key key}): super(key: key);

  @override
  _TrackTileState createState() => _TrackTileState();
}

class _TrackTileState extends State<TrackTile> {

  StreamSubscription _subscription;

  bool get nowPlaying {
    if (AudioService.currentMediaItem == null) return false;
    return AudioService.currentMediaItem.id == widget.track.id;
  }

  @override
  void initState() {
    //Listen to media item changes, update text color if currently playing
    _subscription = AudioService.currentMediaItemStream.listen((event) {
      setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    if (_subscription != null) _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        widget.track.title,
        maxLines: 1,
        style: TextStyle(
          color: nowPlaying?Theme.of(context).primaryColor:null
        ),
      ),
      subtitle: Text(
        widget.track.artistString,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: widget.track.albumArt.thumb,
      ),
      onTap: widget.onTap,
      onLongPress: widget.onHold,
      trailing: widget.trailing,
    );
  }
}

class AlbumTile extends StatelessWidget {

  final Album album;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  AlbumTile(this.album, {this.onTap, this.onHold, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        album.title,
        maxLines: 1,
      ),
      subtitle: Text(
        album.artistString,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: album.art.thumb,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class ArtistTile extends StatelessWidget {

  final Artist artist;
  final Function onTap;
  final Function onHold;

  ArtistTile(this.artist, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: InkWell(
          onTap: onTap,
          onLongPress: onHold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(height: 4,),
              CachedImage(
                url: artist.picture.thumb,
                circular: true,
                width: 64,
              ),
              Container(height: 4,),
              Text(
                artist.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.0
                ),
              ),
              Container(height: 4,),
            ],
          ),
        ),
      )
    );
  }
}

class PlaylistTile extends StatelessWidget {

  final Playlist playlist;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  PlaylistTile(this.playlist, {this.onHold, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        playlist.title,
        maxLines: 1,
      ),
      subtitle: Text(
        playlist.user.name,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: playlist.image.thumb,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class ArtistHorizontalTile extends StatelessWidget {

  final Artist artist;
  final Function onTap;
  final Function onHold;
  final Widget trailing;

  ArtistHorizontalTile(this.artist, {this.onHold, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        artist.name,
        maxLines: 1,
      ),
      leading: CachedImage(
        url: artist.picture.thumb,
        circular: true,
      ),
      onTap: onTap,
      onLongPress: onHold,
      trailing: trailing,
    );
  }
}

class PlaylistCardTile extends StatelessWidget {

  final Playlist playlist;
  final Function onTap;
  final Function onHold;
  PlaylistCardTile(this.playlist, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8),
              child: CachedImage(
                url: playlist.image.thumb,
                width: 128,
                height: 128,
              ),
            ),
            Container(
              width: 144,
              child: Text(
                playlist.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16.0),
              ),
            ),
            Container(height: 8.0,)
          ],
        ),
      )
    );
  }
}

class SmartTrackListTile extends StatelessWidget {

  final SmartTrackList smartTrackList;
  final Function onTap;
  final Function onHold;
  SmartTrackListTile(this.smartTrackList, {this.onHold, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CachedImage(
                width: 128,
                height: 128,
                url: smartTrackList.cover.thumb,
              ),
            ),
            Container(
              width: 144.0,
              child: Text(
                smartTrackList.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.0
                ),
              ),
            ),
            Container(height: 8.0,)
          ],
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {

  final Album album;
  final Function onTap;
  final Function onHold;

  AlbumCard(this.album, {this.onTap, this.onHold});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onHold,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(8.0),
              child: CachedImage(
                width: 128.0,
                height: 128.0,
                url: album.art.thumb,
              ),
            ),
            Container(
              width: 144.0,
              child: Text(
                album.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16.0
                ),
              ),
            ),
            Container(height: 8.0,)
          ],
        ),
      )
    );
  }
}

class ChannelTile extends StatelessWidget {

  final DeezerChannel channel;
  final Function onTap;
  ChannelTile(this.channel, {this.onTap});

  Color _textColor() {
    double luminance = channel.backgroundColor.computeLuminance();
    return (luminance>0.5)?Colors.black:Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: channel.backgroundColor,
      child: InkWell(
        onTap: this.onTap,
        child: Container(
          width: 150,
          height: 75,
          child: Center(
            child: Text(
              channel.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: _textColor()
              ),
            ),
          ),
        ),
      )
    );
  }
}
