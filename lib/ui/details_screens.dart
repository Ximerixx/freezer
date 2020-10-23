import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:freezer/api/cache.dart';
import 'package:freezer/api/deezer.dart';
import 'package:freezer/api/download.dart';
import 'package:freezer/api/player.dart';
import 'package:freezer/ui/elements.dart';
import 'package:freezer/ui/error.dart';
import 'package:freezer/ui/search.dart';
import 'package:freezer/translations.i18n.dart';

import '../api/definitions.dart';
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

  //Get count of CDs in album
  int get cdCount {
    int c = 1;
    for (Track t in album.tracks) {
      if ((t.diskNumber??1) > c) c = t.diskNumber;
    }
    return c;
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
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(height: 8.0,),
                    CachedImage(
                      url: album.art.full,
                      width: MediaQuery.of(context).size.width / 2,
                      fullThumb: true,
                      rounded: true,
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
                    Container(height: 4.0),
                    if (album.releaseDate != null && album.releaseDate.length >= 4)
                      Text(
                        album.releaseDate,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Theme.of(context).disabledColor
                        ),
                      ),
                    Container(height: 8.0,),
                  ],
                ),
              ),
              FreezerDivider(),
              //Details
              Container(
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
              FreezerDivider(),
              //Options (offline, download...)
              Container(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    FlatButton(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.favorite, size: 32),
                          Container(width: 4,),
                          Text('Library'.i18n)
                        ],
                      ),
                      onPressed: () async {
                        await deezerAPI.addFavoriteAlbum(album.id);
                        Fluttertoast.showToast(
                          msg: 'Added to library'.i18n,
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
                          Text('Download'.i18n)
                        ],
                      ),
                      onPressed: () async {
                        if (await downloadManager.addOfflineAlbum(album, private: false, context: context) != false)
                          MenuSheet(context).showDownloadStartedToast();
                      },
                    )
                  ],
                ),
              ),
              FreezerDivider(),
              ...List.generate(cdCount, (cdi) {
                List<Track> tracks = album.tracks.where((t) => (t.diskNumber??1) == cdi + 1).toList();
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Disk'.i18n.toUpperCase() + ' ${cdi + 1}',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w300
                        ),
                      ),
                    ),
                    ...List.generate(tracks.length, (i) => TrackTile(
                      tracks[i],
                      onTap: () {
                        playerHelper.playFromAlbum(album, tracks[i].id);
                      },
                      onHold: () {
                        MenuSheet m = MenuSheet(context);
                        m.defaultTrackMenu(tracks[i]);
                      }
                    ))
                  ],
                );
              }),
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
              MenuSheet(context).showDownloadStartedToast();
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
          'Offline'.i18n,
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
              Container(height: 4.0),
              Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    CachedImage(
                      url: artist.picture.full,
                      width: MediaQuery.of(context).size.width / 2 - 8,
                      rounded: true,
                      fullThumb: true,
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
              Container(height: 4.0),
              FreezerDivider(),
              Container(
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    FlatButton(
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.favorite, size: 32),
                          Container(width: 4,),
                          Text('Library'.i18n)
                        ],
                      ),
                      onPressed: () async {
                        await deezerAPI.addFavoriteArtist(artist.id);
                        Fluttertoast.showToast(
                          msg: 'Added to library'.i18n,
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM
                        );
                      },
                    ),
                    if ((artist.radio??false))
                      FlatButton(
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.radio, size: 32),
                            Container(width: 4,),
                            Text('Radio'.i18n)
                          ],
                        ),
                        onPressed: () async {
                          List<Track> tracks = await deezerAPI.smartRadio(artist.id);
                          playerHelper.playFromTrackList(tracks, tracks[0].id, QueueSource(
                            id: artist.id,
                            text: 'Radio'.i18n + ' ${artist.name}',
                            source: 'smartradio'
                          ));
                        },
                      )
                  ],
                ),
              ),
              FreezerDivider(),
              Container(height: 12.0,),
              //Top tracks
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                child: Text(
                  'Top Tracks'.i18n,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0
                  ),
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
                title: Text('Show more tracks'.i18n),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => TrackListScreen(artist.topTracks, QueueSource(
                      id: artist.id,
                      text: 'Top'.i18n + '${artist.name}',
                      source: 'topTracks'
                    )))
                  );
                }
              ),
              FreezerDivider(),
              //Albums
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Top Albums'.i18n,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0
                  ),
                ),
              ),
              ...List.generate(artist.albums.length > 10 ? 11 : artist.albums.length + 1, (i) {
                //Show discography
                if (i == 10 || i == artist.albums.length) {
                  return ListTile(
                    title: Text('Show all albums'.i18n),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => DiscographyScreen(artist: artist,))
                      );
                    }
                  );
                }
                //Top albums
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

class DiscographyScreen extends StatefulWidget {

  final Artist artist;
  DiscographyScreen({@required this.artist, Key key}): super(key: key);

  @override
  _DiscographyScreenState createState() => _DiscographyScreenState();
}

class _DiscographyScreenState extends State<DiscographyScreen> {

  Artist artist;
  bool _loading = false;
  bool _error = false;
  List<ScrollController> _controllers = [
    ScrollController(),
    ScrollController(),
    ScrollController()
  ];

  Future _load() async {
    if (artist.albums.length >= artist.albumCount || _loading) return;
    setState(() => _loading = true);

    //Fetch data
    List<Album> data;
    try {
      data = await deezerAPI.discographyPage(artist.id, start: artist.albums.length);
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
      return;
    }

    //Save
    setState(() {
      artist.albums.addAll(data);
      _loading = false;
    });

  }

  //Get album tile
  Widget _tile(Album a) => AlbumTile(
    a,
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => AlbumDetails(a))),
    onHold: () {
      MenuSheet m = MenuSheet(context);
      m.defaultAlbumMenu(a);
    },
  );

  Widget get _loadingWidget {
    if (_loading)
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator()],
        ),
      );
    //Error
    if (_error)
      return ErrorScreen();
    //Success
    return Container(width: 0, height: 0,);
  }

  @override
  void initState() {
    artist = widget.artist;

    //Lazy loading scroll
    _controllers.forEach((_c) {
      _c.addListener(() {
        double off = _c.position.maxScrollExtent * 0.85;
        if (_c.position.pixels > off) _load();
      });
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
      length: 3,
      child: Builder(builder: (BuildContext context) {

        final TabController tabController = DefaultTabController.of(context);
        tabController.addListener(() {
          if (!tabController.indexIsChanging) {
            //Load data if empty tabs
            int nSingles = artist.albums.where((a) => a.type == AlbumType.SINGLE).length;
            int nFeatures = artist.albums.where((a) => a.type == AlbumType.FEATURED).length;
            if ((nSingles == 0 || nFeatures == 0) && !_loading) _load();
          }
        });

        return Scaffold(
          appBar: FreezerAppBar(
            'Discography'.i18n,
            bottom: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.album)),
                Tab(icon: Icon(Icons.audiotrack)),
                Tab(icon: Icon(Icons.recent_actors))
              ],
            ),
            height: 100.0,
          ),
          body: TabBarView(
            children: [
              //Albums
              ListView.builder(
                controller: _controllers[0],
                itemCount: artist.albums.length + 1,
                itemBuilder: (context, i) {
                  if (i == artist.albums.length) return _loadingWidget;
                  if (artist.albums[i].type == AlbumType.ALBUM) return _tile(artist.albums[i]);
                  return Container(width: 0, height: 0,);
                },
              ),
              //Singles
              ListView.builder(
                controller: _controllers[1],
                itemCount: artist.albums.length + 1,
                itemBuilder: (context, i) {
                  if (i == artist.albums.length) return _loadingWidget;
                  if (artist.albums[i].type == AlbumType.SINGLE) return _tile(artist.albums[i]);
                  return Container(width: 0, height: 0,);
                },
              ),
              //Featured
              ListView.builder(
                controller: _controllers[2],
                itemCount: artist.albums.length + 1,
                itemBuilder: (context, i) {
                  if (i == artist.albums.length) return _loadingWidget;
                  if (artist.albums[i].type == AlbumType.FEATURED) return _tile(artist.albums[i]);
                  return Container(width: 0, height: 0,);
                },
              ),
            ],
          ),
        );
      })
    );
  }
}

enum SortType {
  DEFAULT,
  REVERSE,
  ALPHABETIC,
  ARTIST
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
  SortType _sort = SortType.DEFAULT;
  ScrollController _scrollController = ScrollController();

  //Get sorted playlist
  List<Track> get sorted {
    List<Track> tracks = new List.from(playlist.tracks??[]);
    switch (_sort) {
      case SortType.ALPHABETIC:
        tracks.sort((a, b) => a.title.compareTo(b.title));
        return tracks;
      case SortType.ARTIST:
        tracks.sort((a, b) => a.artists[0].name.toLowerCase().compareTo(b.artists[0].name.toLowerCase()));
        return tracks;
      case SortType.REVERSE:
        return tracks.reversed.toList();
      case SortType.DEFAULT:
      default:
        return tracks;
    }
  }

  //Load tracks from api
  void _load() async {
    if (playlist.tracks.length < (playlist.trackCount??playlist.tracks.length) && !_loading) {
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

  //Load cached playlist sorting
  void _restoreSort() async {
    if (cache.playlistSort == null) {
      cache.playlistSort = {};
      await cache.save();
      return;
    }
    if (cache.playlistSort[playlist.id] != null) {
      //Preload tracks
      if (playlist.tracks.length < playlist.trackCount) {
        playlist = await deezerAPI.fullPlaylist(playlist.id);
      }
      setState(() => _sort = cache.playlistSort[playlist.id]);
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
      .then((Playlist p) {
        setState(() {
          playlist = p;
        });
        //Load tracks
        _load();
      })
      .catchError((e) {
        setState(() => _error = true);
      });
    }

    _restoreSort();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        controller: _scrollController,
        children: <Widget>[
          Container(height: 4.0,),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                CachedImage(
                  url: playlist.image.full,
                  height: MediaQuery.of(context).size.width / 2 - 8,
                  rounded: true,
                  fullThumb: true,
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
                        maxLines: 3,
                        style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      Container(height: 4.0),
                      Text(
                        playlist.user.name??'',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 17.0
                        ),
                      ),
                      Container(height: 10.0),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.audiotrack,
                            size: 32.0,
                          ),
                          Container(width: 8.0,),
                          Text((playlist.trackCount??playlist.tracks.length).toString(), style: TextStyle(fontSize: 16),)
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
          if (playlist.description != null && playlist.description.length > 0)
            FreezerDivider(),
          if (playlist.description != null && playlist.description.length > 0)
            Container(
              child: Padding(
                padding: EdgeInsets.all(6.0),
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
          FreezerDivider(),
          Container(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                MakePlaylistOffline(playlist),
                IconButton(
                  icon: Icon(Icons.favorite, size: 32),
                  onPressed: () async {
                    await deezerAPI.addPlaylist(playlist.id);
                    Fluttertoast.showToast(
                        msg: 'Added to library'.i18n,
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.file_download, size: 32.0,),
                  onPressed: () async {
                    if (await downloadManager.addOfflinePlaylist(playlist, private: false, context: context) != false)
                      MenuSheet(context).showDownloadStartedToast();
                  },
                ),
                PopupMenuButton(
                  child: Icon(Icons.sort, size: 32.0),
                  color: Theme.of(context).scaffoldBackgroundColor,
                  onSelected: (SortType s) async {
                    if (playlist.tracks.length < playlist.trackCount) {
                      //Preload whole playlist
                      playlist = await deezerAPI.fullPlaylist(playlist.id);
                    }
                    setState(() => _sort = s);

                    //Save sort type to cache
                    cache.playlistSort[playlist.id] = s;
                    cache.save();
                  },
                  itemBuilder: (context) => <PopupMenuEntry<SortType>>[
                    PopupMenuItem(
                      value: SortType.DEFAULT,
                      child: Text('Default'.i18n, style: popupMenuTextStyle()),
                    ),
                    PopupMenuItem(
                      value: SortType.REVERSE,
                      child: Text('Reverse'.i18n, style: popupMenuTextStyle()),
                    ),
                    PopupMenuItem(
                      value: SortType.ALPHABETIC,
                      child: Text('Alphabetic'.i18n, style: popupMenuTextStyle()),
                    ),
                    PopupMenuItem(
                      value: SortType.ARTIST,
                      child: Text('Artist'.i18n, style: popupMenuTextStyle()),
                    ),
                  ],
                ),
                Container(width: 4.0)
              ],
            ),
          ),
          FreezerDivider(),
          ...List.generate(playlist.tracks.length, (i) {
            Track t = sorted[i];
            return TrackTile(
              t,
              onTap: () {
                Playlist p = Playlist(
                  title: playlist.title,
                  id: playlist.id,
                  tracks: sorted
                );
                playerHelper.playFromPlaylist(p, t.id);
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
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator()
                ],
              ),
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
              MenuSheet(context).showDownloadStartedToast();
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
          'Offline'.i18n,
          style: TextStyle(fontSize: 16),
        )
      ],
    );
  }
}
