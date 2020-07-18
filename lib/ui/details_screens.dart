import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/ui/error.dart';
import 'package:freezer/ui/search.dart';

import '../api/definitions.dart';
import 'player_bar.dart';
import 'cached_image.dart';
import 'tiles.dart';
import 'menu.dart';

class AlbumDetails extends StatelessWidget {

  Album album;

  AlbumDetails(this.album);

  Future _loadAlbum() async {
    //Get album from API, if doesn't have tracks
    if (this.album.tracks == null || this.album.tracks.length == 0) {
      this.album = await deezerAPI.album(album.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _loadAlbum(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {

          //Wait for data
          if (snapshot.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(),);
          //On error
          if (snapshot.hasError) return ErrorScreen();

          return ListView(
            children: <Widget>[
              //Album art, title, artists
              Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(height: 8.0,),
                    CachedImage(
                      url: album.art.full,
                      width: MediaQuery.of(context).size.width / 2
                    ),
                    Container(height: 8,),
                    Text(
                      album.title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    Text(
                      album.artistString,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).primaryColor
                      ),
                    ),
                    Container(height: 8.0,),
                  ],
                ),
              ),
              //Details
              Card(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.audiotrack, size: 32.0,),
                        Container(width: 8.0, height: 42.0,), //Height to adjust card height
                        Text(
                          album.tracks.length.toString(),
                          style: TextStyle(fontSize: 16.0),
                        )
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Icon(Icons.timelapse, size: 32.0,),
                        Container(width: 8.0,),
                        Text(
                          album.durationString,
                          style: TextStyle(fontSize: 16.0),
                        )
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Icon(Icons.people, size: 32.0,),
                        Container(width: 8.0,),
                        Text(
                          album.fansString,
                          style: TextStyle(fontSize: 16.0),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              //Options (offline, download...)
              Card(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    FlatButton(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.favorite, size: 32),
                          Container(width: 4,),
                          Text('Library')
                        ],
                      ),
                      onPressed: () async {
                        await deezerAPI.addFavoriteAlbum(album.id);
                        Fluttertoast.showToast(
                          msg: 'Added to library',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM
                        );
                      },
                    ),
                    MakeAlbumOffline(album: album),
                    FlatButton(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.file_download, size: 32.0,),
                          Container(width: 4,),
                          Text('Download')
                        ],
                      ),
                      onPressed: () {
                        downloadManager.addOfflineAlbum(album, private: false);
                      },
                    )
                  ],
                ),
              ),
              ...List.generate(album.tracks.length, (i) {
                Track t = album.tracks[i];
                return TrackTile(
                  t,
                  onTap: () {
                    playerHelper.playFromAlbum(album, t.id);
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultTrackMenu(t);
                  }
                );
              })
            ],
          );
        },
      )
    );
  }
}

class MakeAlbumOffline extends StatefulWidget {

  Album album;
  MakeAlbumOffline({Key key, this.album}): super(key: key);

  @override
  _MakeAlbumOfflineState createState() => _MakeAlbumOfflineState();
}

class _MakeAlbumOfflineState extends State<MakeAlbumOffline> {

  bool _offline = false;

  @override
  void initState() {
    downloadManager.checkOffline(album: widget.album).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Switch(
          value: _offline,
          onChanged: (v) async {
            if (v) {
              //Add to offline
              await deezerAPI.addFavoriteAlbum(widget.album.id);
              downloadManager.addOfflineAlbum(widget.album, private: true);
              setState(() {
                _offline = true;
              });
              return;
            }
            downloadManager.removeOfflineAlbum(widget.album.id);
            setState(() {
              _offline = false;
            });
          },
        ),
        Container(width: 4.0,),
        Text(
          'Offline',
          style: TextStyle(fontSize: 16),
        )
      ],
    );
  }
}


class ArtistDetails extends StatelessWidget {

  Artist artist;
  ArtistDetails(this.artist);

  Future _loadArtist() async {
    //Load artist from api if no albums
    if ((this.artist.albums??[]).length == 0) {
      this.artist = await deezerAPI.artist(artist.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _loadArtist(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          //Error / not done
          if (snapshot.hasError) return ErrorScreen();
          if (snapshot.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(),);

          return ListView(
            children: <Widget>[
              Card(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    CachedImage(
                      url: artist.picture.full,
                      width: MediaQuery.of(context).size.width / 2 - 8,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width / 2 - 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            artist.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 4,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 24.0, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            height: 8.0,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.people,
                                size: 32.0,
                              ),
                              Container(
                                width: 8,
                              ),
                              Text(
                                artist.fansString,
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Container(
                            height: 4.0,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.album, size: 32.0),
                              Container(
                                width: 8.0,
                              ),
                              Text(
                                artist.albumCount.toString(),
                                style: TextStyle(fontSize: 16),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 4.0,),
              Card(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    FlatButton(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.favorite, size: 32),
                          Container(width: 4,),
                          Text('Library')
                        ],
                      ),
                      onPressed: () async {
                        await deezerAPI.addFavoriteArtist(artist.id);
                        Fluttertoast.showToast(
                          msg: 'Added to library',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(height: 16.0,),
              //Top tracks
              Text(
                'Top Tracks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22.0
                ),
              ),
              Container(height: 4.0),
              ...List.generate(5, (i) {
                if (artist.topTracks.length <= i) return Container(height: 0, width: 0,);
                Track t = artist.topTracks[i];
                return TrackTile(
                  t,
                  onTap: () {
                    playerHelper.playFromTopTracks(
                      artist.topTracks,
                      t.id,
                      artist
                    );
                  },
                  onHold: () {
                    MenuSheet mi = MenuSheet(context);
                    mi.defaultTrackMenu(t);
                  },
                );
              }),
              ListTile(
                title: Text('Show more tracks'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => TrackListScreen(artist.topTracks, QueueSource(
                      id: artist.id,
                      text: 'Top ${artist.name}',
                      source: 'topTracks'
                    )))
                  );
                }
              ),
              Divider(),
              //Albums
              Text(
                'Top Albums',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22.0
                ),
              ),
              ...List.generate(artist.albums.length, (i) {
                Album a = artist.albums[i];
                return AlbumTile(
                  a,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AlbumDetails(a))
                    );
                  },
                  onHold: () {
                    MenuSheet m = MenuSheet(context);
                    m.defaultAlbumMenu(
                      a
                    );
                  },
                );
              })
            ],
          );
        },
      ),
    );
  }
}


class PlaylistDetails extends StatefulWidget {

  Playlist playlist;
  PlaylistDetails(this.playlist, {Key key}): super(key: key);

  @override
  _PlaylistDetailsState createState() => _PlaylistDetailsState();
}

class _PlaylistDetailsState extends State<PlaylistDetails> {

  Playlist playlist;
  bool _loading = false;
  bool _error = false;
  ScrollController _scrollController = ScrollController();

  //Load tracks from api
  void _load() async {
    if (playlist.tracks.length < playlist.trackCount && !_loading) {
      setState(() => _loading = true);
      int pos = playlist.tracks.length;
      //Get another page of tracks
      List<Track> tracks;
      try {
        tracks = await deezerAPI.playlistTracksPage(playlist.id, pos);
      } catch (e) {
        setState(() => _error = true);
        return;
      }

      setState(() {
        playlist.tracks.addAll(tracks);
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    playlist = widget.playlist;
    //If scrolled past 90% load next tracks
    _scrollController.addListener(() {
      double off = _scrollController.position.maxScrollExtent * 0.90;
      if (_scrollController.position.pixels > off) {
        _load();
      }
    });
    //Load if no tracks
    if (playlist.tracks.length == 0) {
      //Get correct metadata
      deezerAPI.playlist(playlist.id)
      .catchError((e) => setState(() => _error = true))
      .then((Playlist p) {
        if (p == null) return;
        setState(() {
          playlist = p;
        });
        //Load tracks
        _load();
      });
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        controller: _scrollController,
        children: <Widget>[
          Container(height: 4.0,),
          Card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                CachedImage(
                  url: playlist.image.full,
                  height: MediaQuery.of(context).size.width / 2 - 8,
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 2 - 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        playlist.title,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        playlist.user.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 18.0
                        ),
                      ),
                      Container(
                        height: 8.0,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.audiotrack,
                            size: 32.0,
                          ),
                          Container(width: 8.0,),
                          Text(playlist.trackCount.toString(), style: TextStyle(fontSize: 16),)
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.timelapse,
                            size: 32.0,
                          ),
                          Container(width: 8.0,),
                          Text(playlist.durationString, style: TextStyle(fontSize: 16),)
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Container(height: 4.0,),
          Card(
            child: Padding(
              padding: EdgeInsets.all(4.0),
              child: Text(
                playlist.description ?? '',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16.0
                ),
              ),
            )
          ),
          Card(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                FlatButton(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.favorite, size: 32),
                      Container(width: 4,),
                      Text('Library')
                    ],
                  ),
                  onPressed: () async {
                    await deezerAPI.addFavoriteAlbum(playlist.id);
                    Fluttertoast.showToast(
                        msg: 'Added to library',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM
                    );
                  },
                ),
                MakePlaylistOffline(playlist),
                FlatButton(
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.file_download, size: 32.0,),
                      Container(width: 4,),
                      Text('Download')
                    ],
                  ),
                  onPressed: () {
                    downloadManager.addOfflinePlaylist(playlist, private: false);
                  },
                )
              ],
            ),
          ),
          ...List.generate(playlist.tracks.length, (i) {
            Track t = playlist.tracks[i];
            return TrackTile(
              t,
              onTap: () {
                playerHelper.playFromPlaylist(playlist, t.id);
              },
              onHold: () {
                MenuSheet m = MenuSheet(context);
                m.defaultTrackMenu(t, options: [
                  (playlist.user.id == deezerAPI.userId) ? m.removeFromPlaylist(t, playlist) : Container(width: 0, height: 0,)
                ]);
              }
            );
          }),
          if (_loading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator()
              ],
            ),
          if (_error)
            ErrorScreen()
        ],
      )
    );
  }
}

class MakePlaylistOffline extends StatefulWidget {
  Playlist playlist;
  MakePlaylistOffline(this.playlist, {Key key}): super(key: key);

  @override
  _MakePlaylistOfflineState createState() => _MakePlaylistOfflineState();
}

class _MakePlaylistOfflineState extends State<MakePlaylistOffline> {
  bool _offline = false;

  @override
  void initState() {
    downloadManager.checkOffline(playlist: widget.playlist).then((v) {
      setState(() {
        _offline = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Switch(
          value: _offline,
          onChanged: (v) async {
            if (v) {
              //Add to offline
              if (widget.playlist.user != null && widget.playlist.user.id != deezerAPI.userId)
                await deezerAPI.addPlaylist(widget.playlist.id);
              downloadManager.addOfflinePlaylist(widget.playlist, private: true);
              setState(() {
                _offline = true;
              });
              return;
            }
            downloadManager.removeOfflinePlaylist(widget.playlist.id);
            setState(() {
              _offline = false;
            });
          },
        ),
        Container(width: 4.0,),
        Text(
          'Offline',
          style: TextStyle(fontSize: 16),
        )
      ],
    );
  }
}
